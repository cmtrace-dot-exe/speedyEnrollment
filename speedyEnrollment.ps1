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

if ($xmlData.taskSequenceComplete -eq "false") {
    # Get the completion time of the task sequence stored in xmlData.taskSequenceID
    try {
        $lastCompletedTS = Get-CimInstance -Namespace "root\ccm\SoftMgmtAgent" -ClassName "CCM_TaskExecutionStatus" -ErrorAction Stop | 
                        Where-Object { $_.PackageID -eq $xmlData.taskSequenceID } | 
                        Sort-Object -Property LastStatusTime -Descending | 
                        Select-Object -First 1
        
        if ($lastCompletedTS -and $lastCompletedTS.LastStatusTime) {
            # Update the completion time in xmlData and mark as complete
            $xmlData.taskSequenceCompletionTime = $lastCompletedTS.LastStatusTime.ToString("yyyy-MM-dd HH:mm:ss")
            $xmlData.taskSequenceComplete = "true"
            
            # Save the updated data back to XML file
            $xmlData | Export-Clixml -Path "$stagingDirectory\data.xml" -Force
            
            # add task sequence information to lock screen image and write to default wallpaper location
            Add-TextToImage -InputImagePath "$stagingDirectory\doNotUseEnrollmentPending_01.jpg" `
                 -OutputImagePath "$env:windir\web\screen\img100.jpg" `
                 -Text "Task sequence $($xmlData.taskSequenceID) completed at $($xmlData.taskSequenceCompletionTime)"

            logwrite "$(get-date), Task sequence completion time retrieved: $($xmlData.taskSequenceCompletionTime)"
            Restart-Computer -force
            exit
        } else {
            logwrite "$(get-date), Task sequence $($xmlData.taskSequenceID) completion time not found in WMI"
        }
    } catch {
        logwrite "$(get-date), Error retrieving task sequence completion time: $($_.Exception.Message)"
    }
}

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

function Add-TextToImage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$InputImagePath,
        [Parameter(Mandatory=$true)]
        [string]$OutputImagePath,
        [Parameter(Mandatory=$true)]
        [string]$Text,
        [string]$FontName = "Segoe UI",
        [int]$FontSize = 33,
        [string]$FontStyle = "Bold",
        [string]$TextColor = "White",
        [ValidateSet("Left","Center","Right")]
        [string]$HorizontalAlign = "Center",
        [int]$YOffset = 30
    )

    Add-Type -AssemblyName System.Drawing

    $graphics = $null
    $bitmap = $null
    $originalImage = $null
    $brush = $null
    $font = $null
    try {
        $originalImage = [System.Drawing.Image]::FromFile($InputImagePath)
        $bitmap = New-Object System.Drawing.Bitmap($originalImage.Width, $originalImage.Height, $originalImage.PixelFormat)
        $bitmap.SetResolution($originalImage.HorizontalResolution, $originalImage.VerticalResolution)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
        $graphics.DrawImage($originalImage, 0, 0, $originalImage.Width, $originalImage.Height)

        $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::$TextColor)
        $fontStyleEnum = [System.Drawing.FontStyle]::$FontStyle
        $font = New-Object System.Drawing.Font($FontName, $FontSize, $fontStyleEnum)
        $textSize = $graphics.MeasureString($Text, $font)

        switch ($HorizontalAlign) {
            "Left"   { $x = 0 }
            "Center" { $x = ($bitmap.Width - $textSize.Width) / 2 }
            "Right"  { $x = $bitmap.Width - $textSize.Width }
        }
        $y = $bitmap.Height - $textSize.Height - $YOffset

        $graphics.DrawString($Text, $font, $brush, $x, $y)

        $jpegEncoder = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
        $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
        $encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 100L)
        $bitmap.Save($OutputImagePath, $jpegEncoder, $encoderParams)
        Write-Host "Text successfully added to image!" -ForegroundColor Green
        Write-Host "Output saved as: $OutputImagePath" -ForegroundColor Green
    }
    catch {
        Write-Error "An error occurred while processing the image: $($_.Exception.Message)"
    }
    finally {
        if ($graphics) { $graphics.Dispose() }
        if ($bitmap) { $bitmap.Dispose() }
        if ($originalImage) { $originalImage.Dispose() }
        if ($brush) { $brush.Dispose() }
        if ($font) { $font.Dispose() }
    }
}
