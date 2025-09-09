############################################################################################################
### File copy and scheduled task creation for Entra/Intune lock screen speedyEnrollment Script
### Mike O'Leary | mikeoleary.net | @cmtrace-dot-exe 
############################################################################################################

param (
        [int] $repetitionInterval = 5,
        [switch] $log,
        [switch] $speedy,
        [string] $logPath = "$env:public\speedyEnrollment\$env:computername.log",
        [string] $stagingDirectory = "$env:public\speedyEnrollment",
        [string] $lockScreenPath = "$env:windir\web\screen\img100.jpg",
        [string] $topText1 = "DO NOT USE",
        [string] $topText2 = "ENROLLMENT PENDING",
        [string] $bottomText = ""
    )

# Import textOverlay Module
. "$PSScriptRoot\speedyEnrollment\textOverlay.ps1"

# configure logging if $log is TRUE, log nothing if not
    if ($log) {
        Function LogWrite ([string]$logstring) {
            $streamWriter = New-Object System.IO.StreamWriter($logPath, $true, [System.Text.Encoding]::UTF8)
            $streamWriter.WriteLine($logstring)
            $streamWriter.Close()
            $streamWriter.Dispose()
        }
    } 
    else {
        Function LogWrite ([string]$logstring) {
            # Logging disabled, do nothing
        }
    }

# trim any trailing backslashes from $stagingDirectory so things don't go kablooie
    $stagingDirectory = $stagingDirectory.trimend("\")

# copy speedyEnrollment files to staging directory 
    xcopy "$PSScriptRoot\speedyEnrollment" $stagingDirectory /e /s /y /h /i

# Get currently running task sequence information and store to XML
# Create XML object with task sequence data and initial step
    $tsEnv = New-Object -ComObject Microsoft.SMS.TSEnvironment -ErrorAction SilentlyContinue

    $xmlData = [PSCustomObject]@{
        taskSequenceID = $tsEnv.Value("_SMSTSPackageID")
        taskSequenceName = $tsEnv.Value("_SMSTSPackageName")
        taskSequenceCompletionTime = $(Get-Date -Format 'HH:mm:ss yyyy-MM-dd')
        currentStep = "01"
        powerGUID = ""
    }

# Convert to XML and save to file
    $xmlPath = Join-Path $stagingDirectory "data.xml"
    $xmlData | Export-Clixml -Path $xmlPath -Force

# change default lock screen image permissions
    takeown /f $env:windir\web\Screen\img100.jpg
    icacls $env:windir\web\Screen\img100.jpg /Grant 'System:(F)'
# preserve original lockscreen for later restoration
    copy-item $lockScreenPath -destination "$stagingDirectory\originalLockScreen.jpg" -force

# replace default logon screen wallpaper with first enrollment status jpg
    # Set default bottomText if not provided
    if ([string]::IsNullOrEmpty($bottomText)) {$bottomText = "Task sequence $($xmlData.taskSequenceID) completed at $($xmlData.taskSequenceCompletionTime)"}

    Add-TextToImage -InputImagePath "$stagingDirectory\step_01.jpg" `
        -OutputImagePath $lockScreenPath `
        -TopText1 $topText1 `
        -TopText2 $topText2 `
        -BottomText $bottomText

# check for presence of registry paths, create if not present
    if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization")) { New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" -Force}
    if (-not (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP")) { New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" -Force}
# create lockscreen registry entries
    New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" -Name "LockScreenImage" -Value $lockScreenPath -PropertyType String -Force
    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" -Name "LockScreenImagePath" -Value $lockScreenPath -PropertyType String -Force
    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" -Name "LockScreenImageUrl" -Value $lockScreenPath -PropertyType String -Force
    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" -Name "LockScreenImageStatus" -Value "1" -PropertyType DWord -force

# Create speedyEnrollment scheduled task, firing at interval defined in $repetitionInterval
    $argumentString = "-NoProfile -ExecutionPolicy Bypass -File $stagingDirectory\speedyEnrollment.ps1 -lockScreenPath `"$lockScreenPath`" -stagingDirectory `"$stagingDirectory`" -topText1 `"$topText1`" -topText2 `"$topText2`" -bottomText `"$bottomText`""
    if ($speedy) {
        $argumentString += " -speedy"
    }
    if ($log) {
        $argumentString += " -log -logPath `"$logPath`""
    }

    $taskAction = New-ScheduledTaskAction `
        -WorkingDirectory "$env:windir\system32\windowspowershell\v1.0" `
        -Execute "Powershell.exe" `
        -Argument $argumentString
    
    # create task trigger/schedule
        $taskTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes $repetitionInterval)

    # The name of the scheduled task.
        $taskName = "Speedy Enrollment"

    # Describe the scheduled task.
        $description = "Scheduled Task to display current Entra and Intune enrollment status on the lock screen."

    # create settings set
        $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Compatibility Win8
        
    # specifiy task principal	
        $principal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest

    # Register the scheduled task
        Register-ScheduledTask `
            -TaskName $taskName `
            -Action $taskAction `
            -Trigger $taskTrigger `
            -Description $description `
            -Settings $settings `
            -Principal $principal


