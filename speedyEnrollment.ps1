############################################################################################################
### Entra/Intune lock screen speedyEnrollment Script
### Mike O'Leary | mikeoleary.net | @cmtrace-dot-exe 
############################################################################################################

param (
[switch] $log,
[string] $logPath = "$env:public\speedyEnrollment\$env:computername.log",
[string] $stagingDirectory = "$env:public\speedyEnrollment"
)

# trim any trailing backslashes from $stagingDirectory so things don't go kablooie
    $stagingDirectory = $stagingDirectory.trimend("\")

# Import textOverlay Module
    . "$PSScriptRoot\textOverlay.ps1"

# configure logging if $log is TRUE, log nothing if not
    if ($log) {
        Function LogWrite ([string]$logstring) {Add-Content -Path $logPath -Value $logstring}
    } 
    else {
        Function LogWrite ([string]$logstring) {
            # Logging disabled, do nothing
        }
    }

# ingest data.xml
    $xmlData = Import-Clixml -Path "$stagingDirectory\data.xml"

# change power management settings to prevent interruption of onboarding workflow
    
        # Switch to High Performance Plan
        powercfg /S 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

        # Never turn off display or sleep
        powercfg /X monitor-timeout-ac 0
        powercfg /X monitor-timeout-dc 0
        powercfg /X standby-timeout-ac 0
        powercfg /X standby-timeout-dc 0
        powercfg /X hibernate-timeout-ac 0
        powercfg /X hibernate-timeout-dc 0

        # Processor: full performance
        powercfg /SETACVALUEINDEX SCHEME_MIN SUB_PROCESSOR PROCTHROTTLEMIN 100
        powercfg /SETACVALUEINDEX SCHEME_MIN SUB_PROCESSOR PROCTHROTTLEMAX 100
        powercfg /SETACVALUEINDEX SCHEME_MIN SUB_PROCESSOR IDLEDISABLE 1

        # Disable hard disk sleep
        powercfg /X disk-timeout-ac 0
        powercfg /X disk-timeout-dc 0

        # Disable USB selective suspend
        powercfg /SETACVALUEINDEX SCHEME_MIN SUB_USB USBSELECTIVE 0

        # Disable PCI Express Link State Power Management
        powercfg /SETACVALUEINDEX SCHEME_MIN SUB_PCIEXPRESS ASPM 0

        # Wireless: Max Performance
        powercfg /SETACVALUEINDEX SCHEME_MIN SUB_WIFI POWER_SAVING_MODE 0
        
        # Disable Hibernation
        powercfg /hibernate off

        # Apply all changes
        powercfg /S 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c


        

logwrite $(get-date), "-------------------------------"

##################################################################
# evaluate and act upon entra join & intune enrollment condition #
##################################################################

# parse and ingest dsregcmd output into an object
    $dsregcmd = New-Object PSObject ; Dsregcmd /status | Where {$_ -match ' : '}|ForEach {$Item = $_.Trim() -split '\s:\s'; $Dsregcmd|Add-Member -MemberType NoteProperty -Name $($Item[0] -replace '[:\s]','') -Value $Item[1] -EA SilentlyContinue}

# check if device is Entra joined
    if ($dsregcmd.AzureAdJoined -eq 'YES') {
        logwrite $(get-date), "Entra Joined: YES"
        
    # check intune $EnrollmentKey in registry and take action if entra joined + intune enrolled
        $EnrollmentKey = Get-Item -Path HKLM:\SOFTWARE\Microsoft\Enrollments\* | Get-ItemProperty | Where-Object -FilterScript {$null -ne $_.UPN}	
        if($($EnrollmentKey) -and $($EnrollmentKey.EnrollmentState -eq 1)){
            logwrite $(get-date), "Intune Enrolled: YES"
            logwrite $(get-date), "Deleting Speedy Enrollment Tasks..."
            
            # remove speedyEnrollment scheduled task
            Unregister-ScheduledTask -TaskName "Speedy Enrollment" -Confirm:$false
            Unregister-ScheduledTask -TaskName "Speedy Enrollment SCCM Policy Reset" -Confirm:$false

            # return lockscreen image to normal
            copy-item "$stagingDirectory\originalLockScreen.jpg" -destination "$env:windir\web\screen\img100.jpg" -force
            Restart-Computer -force
        }
        else {
            # if entra joined but not intune enrolled, check value stored in data.xml and change lock screen wallpaper if value is NOT "02"
            if($xmlData.currentStep -NE "02"){ 
                logwrite $(get-date), "Intune Enrolled: NO"
                logwrite $(get-date), "Creating SCCM policy reset scheduled task and restarting computer..."
                
                # Create SCCM policy reset scheduled task to run in 5 minutes

                    # Create a new task action
                    $argumentString = "-NoProfile -ExecutionPolicy Bypass -File $stagingDirectory\policyReset.ps1"
                    if ($log) {
                        $argumentString += " -log -logPath $logPath"
                    }	
                    $taskAction = New-ScheduledTaskAction `
                            -WorkingDirectory "$env:windir\system32\windowspowershell\v1.0" `
                            -Execute "Powershell.exe" `
                            -Argument $argumentString
                
                    # create task trigger/schedule
                        $taskTrigger = New-ScheduledTaskTrigger -Once -At ([datetime]::Now.AddMinutes(05))

                    # The name of the scheduled task.
                        $taskName = "Speedy Enrollment SCCM Policy Reset"

                    # Describe the scheduled task.
                        $description = "Scheduled SCCM policy reset to kickstart speedy enrollment process of SCCM clients into AAD and Intune. Deployed by olearym."

                    # create settings set
                        $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Compatibility Win8
                        
                    # specifiy task principal	
                        $principal = New-ScheduledTaskPrincipal -UserID "NT Authority\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
                            #-RunLevel Highest `

                    # Register the scheduled task
                        Register-ScheduledTask `
                            -TaskName $taskName `
                            -Action $taskAction `
                            -Trigger $taskTrigger `
                            -Description $description `
                            -Settings $settings `
                            -Principal $principal
                    
                # change "Speedy Enrollment" scheduled task tempo to once every 15 minutes
                    $taskNameMod = "Speedy Enrollment"
                    $taskTriggerMod = New-ScheduledTaskTrigger -Once -At ([datetime]::Now.AddMinutes(15)) -RepetitionInterval (New-TimeSpan -Minutes 15)
                    set-scheduledTask  `
                        -TaskName $taskNameMod `
                        -Trigger $taskTriggerMod
                    
                # add task sequence information to step 02 wallpaper and write to default wallpaper location, update step in data.xml and restart 
                    # copy-item "$stagingDirectory\doNotUseEnrollmentPending_02.jpg" -destination "$env:windir\web\screen\img100.jpg" -force
                Add-TextToImage -InputImagePath "$stagingDirectory\doNotUseEnrollmentPending_02.jpg" `
                 -OutputImagePath "$env:windir\web\screen\img100.jpg" `
                 -Text "Task sequence $($xmlData.taskSequenceID) completed at $($xmlData.taskSequenceCompletionTime)"
                # update step in data.xml file
                    $xmlData.currentStep = "02"
					$xmlData | Export-Clixml -Path "$stagingDirectory\data.xml" -Force	            
                Restart-Computer -force
                exit
    }
    logwrite $(get-date), "Intune Enrolled: NO"
    logwrite $(get-date), "Restarting CCMEXEC Service..."
    restart-service ccmexec
    }
}
else {
    logwrite $(get-date), "Entra Joined: NO"
    logwrite $(get-date), "Triggering Automatic-Device-Join Task..."
    Start-ScheduledTask -TaskName "Automatic-Device-Join"

}
