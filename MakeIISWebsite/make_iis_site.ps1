#Import the powershell WebAdministration Snapin

Add-PSSnapin WebAdministration -ErrorAction SilentlyContinue
sleep 1
Import-Module WebAdministration -ErrorAction SilentlyContinue
<#
	Create an application pool for the site example.domain.com
#>
New-Item IIS:\AppPools\example.domain.com

<#
	Create the website, bindings, physical path, and app pool previously created for example.domain.com. 
#>


New-Item IIS:\Sites\example.domain.com -bindings @{protocol="http";bindingInformation=":80:example.domain.com"} -physicalPath D:\MAIN\Entourage\edo -Force
Set-ItemProperty IIS:\Sites\example.domain.com -name applicationPool -value example.domain.com

<#
	Set up some configuration options, in this case at the ASP level, using appcmd.exe
#>

c:\Windows\System32\inetsrv\appcmd.exe set config /section:asp /enableParentPaths:True
c:\Windows\System32\inetsrv\appcmd.exe set config /section:asp /limits.maxRequestEntityAllowed:2000000
c:\Windows\System32\inetsrv\appcmd.exe set config /section:asp /limits.scriptTimeout:01:00:00
c:\Windows\System32\inetsrv\appcmd.exe set config /section:asp /scriptErrorSentToBrowser:True
c:\Windows\System32\inetsrv\appcmd.exe set config /section:asp /appAllowDebugging:True

<#
	Configuration options can, of course, also be set using the powershell snapin. Here we'll set some options for the app pool
#>

Add-WebConfiguration /system.webServer/defaultDocument/files  "IIS:\sites\example.domain.com" -AtIndex 0 -value @{value="index.aspx"}
Set-ItemProperty IIS:\AppPools\example.domain.com -name processModel.maxProcesses -value 5
Set-ItemProperty IIS:\AppPools\example.domain.com -name processModel.idleTimeout -value 00:05:00
Set-ItemProperty IIS:\apppools\example.domain.com -name processModel -value @{userName="entourage_web";password="photoJo410";identitytype=3}
Set-ItemProperty IIS:\AppPools\example.domain.com -name processModel.loadUserProfile -value True
c:\Windows\System32\inetsrv\appcmd.exe set apppool "example.domain.com" /processModel.loadUserProfile:True

<#
	Setting physical path credentials for example.domain.com
#>

$website = Get-Item IIS:\Sites\example.domain.com
$website.virtualDirectoryDefaults.userName="entourage_web"
$website.virtualDirectoryDefaults.password="photoJo410"
$website | set-item

#RESTART IIS AFTER CHANGING SETTINGS (Before code is deployed)
Restart-Service IISADMIN

