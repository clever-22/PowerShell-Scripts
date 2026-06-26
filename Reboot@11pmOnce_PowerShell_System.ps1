<#
.SYNOPSIS
Schedules a one-time system reboot at 11 PM.

.DESCRIPTION
Creates a scheduled task that will reboot the computer at 11 PM today. 
If 11 PM has already passed, the reboot is scheduled for 11 PM tomorrow. 
The task runs with system privileges and executes immediately upon triggering.
#>

$time = (Get-Date).Date.AddHours(23)  # Today at 11 PM
if ($time -lt (Get-Date)) {
    $time = $time.AddDays(1)          # If 11 PM already passed, schedule for tomorrow
}
$action = New-ScheduledTaskAction -Execute "shutdown.exe" -Argument "-r -t 0"
$trigger = New-ScheduledTaskTrigger -Once -At $time
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
$task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal
Register-ScheduledTask -TaskName "OneTimeRebootAt11PM" -InputObject $task -Force
