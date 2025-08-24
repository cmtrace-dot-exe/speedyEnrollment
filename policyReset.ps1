param (
[switch] $log,
[string] $logPath = "$env:public\speedyEnrollment\$env:computername.log"
)


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
logwrite $(get-date), "Triggering 'Speedy Enrollment SCCM Policy Reset' task and restarting CCMEXEC service..."

Invoke-CimMethod -Namespace root\ccm -ClassName sms_client -Name ResetPolicy -Arguments @{ uFlags = ([UInt32]1) }
start-sleep -seconds 10
Restart-Service CcmExec

$taskNameMod = "Speedy Enrollment SCCM Policy Reset"
$taskTriggerMod = New-ScheduledTaskTrigger -Once -At ([datetime]::Now.AddMinutes(30)) -RepetitionInterval (New-TimeSpan -Minutes 30)
set-scheduledTask  `
	-TaskName $taskNameMod `
	-Trigger $taskTriggerMod