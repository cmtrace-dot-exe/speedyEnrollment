############################################################################################################
### Entra/Intune lock screen enrollmentStatus Script
### Mike O'Leary | mikeoleary.net | @cmtrace-dot-exe 
############################################################################################################

param (
[switch] $log,
[string] $logPath = "$env:public\enrollmentStatus\$env:computername.log",
[string] $stagingDirectory = "$env:public\enrollmentStatus"
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
				logwrite $(get-date), "Deleting enrollmentStatus Task..."
				
				# remove enrollmentStatus scheduled task
				Unregister-ScheduledTask -TaskName "enrollmentStatus" -Confirm:$false

				# return lockscreen image to normal
				copy-item "$stagingDirectory\originalLockScreen.jpg" -destination "$env:windir\web\screen\img100.jpg" -force
				Restart-Computer -force
			}
			else {
				# if entra joined but not intune enrolled, check value stored in 'step.txt' and change lock screen wallpaper if value is NOT "02"
				if($(get-Content "$stagingDirectory\step.txt") -NE "02"){ 
					logwrite $(get-date), "Intune Enrolled: NO"
					logwrite $(get-date), "Changing lock screen wallpaper to reflect Entra Join and restarting computer..."
				
					# copy DO NOT USE step 02 wallpaper to lockscreen, iterate 'step.txt' and restart
					copy-item "$stagingDirectory\doNotUseEnrollmentPending_02.jpg" -destination "$env:windir\web\screen\img100.jpg" -force
					# iterate step.txt file
					"02" | Set-Content "$stagingDirectory\step.txt"
					
					Restart-Computer -force
					exit
		}
		logwrite $(get-date), "Intune Enrolled: NO"
	}
}
else {
	logwrite $(get-date), "Entra Joined: NO"
}