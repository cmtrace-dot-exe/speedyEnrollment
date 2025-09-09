Add a "Run Powershell Script" step to your task sequence, select your uploaded package and reference copyAndScheduleTask.ps1.
Insert this step as close to the end of your task sequence as is practical.

All parameters are optional

### -speedy [switch]
Default: _disabled_   
>[!IMPORTANT] 
>PLEASE NOTE: this feature is experimental and tuned to my particular environment. Enabling this feature may very well *slow down* your enrollments if they're already pretty swift. Your mileage may very much vary.

    Enables speedy enrollment mode, which cyclically...  
	
    - triggers scheduled tasks (Automatic-Device-Join)  
    - restarts services (CCMEXEC)  
    - clears caches (ConfigMgr client)
    
    ...in an effort to prod the enrollment process along.  
      
### -lockScreenPath [string]
Default: _$env:windir\web\screen\img100.jpg_
    
	Not necessary unless you've moved your lockscreen image to an alternate location via theme or the registry.
  
### -log [switch]  
Default: _disabled_  
    
	Enables optional logging.  
  
### -logpath [string]  
Default: _$env:public\enrollmentStatus\$env:computername.log_  
    
	Path and name of optional log.  
  
### -repetitionInterval [int]
Default: _5_
    
	Number of minutes to wait between each run of the scheduled task.  
  
### -stagingDirectory [string]  
Default: _"$env:public\enrollmentStatus"_  
    
	Local staging directory for enrollmentStatus.ps1 and lock screen wallpaper.  
   
### -topText1 [string]  
Default: _"DO NOT USE"_
    
	The first line of the top text area  
 
### -topText2 [string]  
Default: _"ENROLLMENT PENDING"_  
    
	The second line of the top text area  
 
### -bottomText [string]  
Default: ""
    
	Bottom text area. If empty, defaults to _"Task sequence $($xmlData.taskSequenceID) completed at $($xmlData.taskSequenceCompletionTime)"_  

# Examples:  
```
.\copyAndScheduleTask.ps1 -repetitionInterval 5 -stagingDirectory $env:public\speedyEnrollment -speedy -log -logpath \\fileFarm.contoso.com\enrollmentLogs\$env:computername.log

.\copyAndScheduleTask.ps1 -repetitionInterval 5 -stagingDirectory $env:public\speedyEnrollment -toptext1 'HERE IS SOME' -TOPTEXT2 'CUSTOM TEXT' -BOTTOMTEXT 'YOU CAN DISPLAY ON THE LOCK SCREEN' -log -logpath \\fileFarm.fabrikam.com\enrollmentLogs\$env:computername.log
```
