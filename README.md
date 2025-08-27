Add a "Run Powershell Script" step to your task sequence, select your uploaded package and reference copyAndScheduleTask.ps1.

Insert this step as close to the end of your task sequence as is practical.

All parameters are optional:
```
-speedy switch
	[Default: disabled]
	Enables speedy enrollment mode, which cyclically...
		triggers scheduled tasks (Automatic-Device-Join)
		restarts services (CCMEXEC)
		clears caches (ConfigMgr client)
	...in an effort to prod the enrollment process along.

	PLEASE NOTE: this feature is experimental and tuned to my particular environment.
	Enabling this feature may very well *slow down* your enrollments if they're already pretty swift.
	Your mileage may very much vary.

-log switch  
		[Default: disabled]  
	Enables optional logging.  

-logpath string  
	[Default: $env:public\enrollmentStatus\$env:computername.log] 
	Path and name of optional log. 

-repetitionInterval int 
	[Default: 5]
	Number of minutes to wait between each run of the scheduled task.

-stagingDirectory string
	[Default: "$env:public\enrollmentStatus"]
	Local staging directory for speedyEnrollment.ps1 and lock screen wallpaper.

-topText1 string
	[Default: "DO NOT USE"]
	The first line of the top text area

-topText2 string
	[Default: "ENROLLMENT PENDING"]
	The second line of the top text area

-bottomText string
	[Default: ""]
	Bottom text area. If empty, defaults to "Task sequence $($xmlData.taskSequenceID) completed at $($xmlData.taskSequenceCompletionTime)"

Example:
	.\copyAndScheduleTask.ps1 -repetitionInterval 5 -stagingDirectory $env:public\speedyEnrollment -speedy -log -logpath \\fileFarm.contoso.com\enrollmentLogs\$env:computername.log
```
