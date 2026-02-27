<#
.SYNOPSIS
Internet and network troubleshooting commands for diagnosing and fixing connectivity issues.

.DESCRIPTION
A collection of PowerShell commands to diagnose and resolve network and internet problems. 
Includes commands for checking network adapters, managing wireless services, disabling/enabling network adapters, 
resetting network configurations, and obtaining new IP addresses. 
Use with caution when executing remotely, and note that some commands require system reboot.
#>

#Helps diagnose hardware problems
Get-NetAdapter -Name *Wi-Fi*
netsh interface show interface
Get-Service WlanSvc | Start-Service
#Careful running ALL commands below if exectuing these remotely. It will cause it to go down for a sec. Run them together or give to user.
Disable-NetAdapter -Name "Wi-Fi" -Confirm:$false
Enable-NetAdapter -Name "Wi-Fi" -Confirm:$false
#This one will reinstall drives and requires a reboot
netcfg -d
#These require a reboot
netsh winsock reset
netsh int ip reset
#These just help you get a new ip
pconfig /release
ipconfig /renew