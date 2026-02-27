<#
.SYNOPSIS
Schedules a one-time system reboot at 10 PM.

.DESCRIPTION
Creates a scheduled task that will reboot the computer at 10 PM today. 
If 10 PM has already passed, the reboot is scheduled for 10 PM tomorrow. 
The task runs with system privileges and executes immediately upon triggering.
#>

$time = (Get-Date).Date.AddHours(22)  # Today at 10 PM
if ($time -lt (Get-Date)) {
    $time = $time.AddDays(1)          # If 10 PM already passed, schedule for tomorrow
}
$action = New-ScheduledTaskAction -Execute "shutdown.exe" -Argument "-r -t 0"
$trigger = New-ScheduledTaskTrigger -Once -At $time
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
$task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal
Register-ScheduledTask -TaskName "OneTimeRebootAt10PM" -InputObject $task -Force