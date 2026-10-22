Set-ItemProperty -Path "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\CapabilityAccessManager\\ConsentStore\\location"
-Name Value `
-Value Allow
& "C:\Windows\system32\SystemSettingsAdminFlows.exe" SetCamSystemGlobal location 1
Get-Service lfsvc | Select Name, Status, StartType
Start-Service lfsvc
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" 2>$null
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsAccessLocation 2>$null
reg query "HKCU\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" 2>$null
gpresult /scope computer /v | findstr /i "location"
#Reboot and try enabling with Admin account if this doesn't work