# speedyEnrollment.ps1

Add a "Run Powershell Script" step to your task sequence, select your uploaded package and reference copyAndScheduleTask.ps1.  

Insert this step as close to the end of your task sequence as is practical.

<ins> All parameters are optional</ins> 

### -speedy _switch_
>[!IMPORTANT] 
>PLEASE NOTE: this feature is experimental and tuned to my particular environment. Enabling this feature may very well *slow down* your enrollments if they're already pretty swift. Your mileage may and probably will vary.
  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;[Default: _disabled_]  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Enables speedy enrollment mode, which cyclically...   
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;- triggers scheduled tasks (Automatic-Device-Join)  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;- restarts services (CCMEXEC)  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;- clears caches (ConfigMgr client)     
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;...in an effort to prod the enrollment process along.  
      
### -lockScreenPath _string_
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;[Default: _$env:windir\web\screen\img100.jpg_]  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Not necessary unless you've moved your lockscreen image to an alternate location via theme or the registry.
  
### -log _switch_  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;[Default: _disabled_]       
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Enables optional logging.  
  
### -logpath _string_  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;[Default: _"$env:public\enrollmentStatus\$env:computername.log"_]      
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Path and name of optional log.  
  
### -repetitionInterval _int_
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;[Default: _5_]    
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Number of minutes to wait between each run of the scheduled task.  
  
### -stagingDirectory _string_  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;[Default: _"$env:public\enrollmentStatus"_]      
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Local staging directory for enrollmentStatus.ps1 and lock screen wallpaper.  
   
### -topText1 _string_  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;[Default: _"DO NOT USE"_]    
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;The first line of the top text area  
 
### -topText2 _string_  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;[Default: _"ENROLLMENT PENDING"_]    
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;The second line of the top text area  
 
### -bottomText _string_  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;[Default: ""]      
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Bottom text area. If empty, defaults to _"Task sequence $($xmlData.taskSequenceID) completed at $($xmlData.taskSequenceCompletionTime)"_  

# Examples:  
```
.\copyAndScheduleTask.ps1 -repetitionInterval 5 -stagingDirectory $env:public\speedyEnrollment -speedy -log -logpath \\fileFarm.contoso.com\enrollmentLogs\$env:computername.log

.\copyAndScheduleTask.ps1 -repetitionInterval 5 -stagingDirectory $env:public\speedyEnrollment -toptext1 'HERE IS SOME' -TOPTEXT2 'CUSTOM TEXT' -BOTTOMTEXT 'YOU CAN DISPLAY ON THE LOCK SCREEN' -log -logpath \\fileFarm.fabrikam.com\enrollmentLogs\$env:computername.log
```
