#Requires -RunAsAdministrator
<#
.SYNOPSIS
    ImmyBot reboot script with optional day/time scheduling and suppression hours using Windows Scheduled Tasks.
    Or can be used blank for parameters and the Schedule on Immybot.
.DESCRIPTION
    Allows ImmyBot to schedule and trigger reboots with suppression hours support.
    - If DayOfWeek and Time parameters are provided AND valid, schedules reboot for that next occurrence.
    - If invalid day/time, no reboot occurs.
    - If no parameters supplied, a reboot occurs immediately (unless in suppression window).
    - Suppression hours prevent reboots during specified time ranges.
    - Always outputs reboot and pending reboot info.
    - Get method shows last reboot time and checks for scheduled reboots, returns true if reboot is pending or scheduled.
    - Set method schedules reboot and returns true if successful.
    - Test method checks if a scheduled reboot exists at the correct time and returns true/false.

    # You'll need to creat these parameters with text as data type and you'll need to run this as system!
    # If you want this to work with schedules just fill in the supression hours in a deployments then use the immybot schedule to run this at the time of your choosing
    # Make sure to test it on a test machines first!
.PARAMETER DayOfWeek
    Optional day of the week (e.g., Monday, Tue, Friday). If invalid, no reboot is scheduled.

.PARAMETER Time
    Optional time in HH:mm format or just HH. If invalid, no reboot is scheduled.

.PARAMETER SuppressionHoursStart
    Optional start time for suppression window in HH:mm or HH format (e.g., 08:00 or 8)

.PARAMETER SuppressionHoursEnd
    Optional end time for suppression window in HH:mm or HH format (e.g., 17:00 or 17)

.PARAMETER Method
    Operation mode: "get", "set", or "test"

.EXAMPLE
    .\RebootScript.ps1 -Method set -DayOfWeek Friday -Time 21:00 -SuppressionHoursStart 8 -SuppressionHoursEnd 17
    Schedules a reboot for next Friday at 9 PM, avoiding reboots between 8 AM and 5 PM

.EXAMPLE
    .\RebootScript.ps1 -Method set -Time 21 -SuppressionHoursStart 08:00 -SuppressionHoursEnd 17:00
    Schedules a reboot for today at 9 PM (or tomorrow if time has passed), with suppression from 8 AM to 5 PM

.EXAMPLE
    .\RebootScript.ps1 -Method set -SuppressionHoursStart 22:00 -SuppressionHoursEnd 06:00
    Immediate reboot unless current time is between 10 PM and 6 AM (next day)
#>

param(
    [string]$DayOfWeek = "",
    [string]$Time = "",
    [string]$SuppressionHoursStart = "",
    [string]$SuppressionHoursEnd = "",
    [string]$Method = "get"
)

$TaskName = "ImmyBot_ScheduledReboot"

Function Parse-TimeString {
    param(
        [string]$TimeStr
    )
    
    if (-not $TimeStr) {
        return $null
    }
    
    try {
        # Try parsing as H:mm or HH:mm
        if ($TimeStr -match '^\d{1,2}:\d{2}$') {
            return [DateTime]::ParseExact($TimeStr, "H:mm", $null)
        }
        # If just a number (hour only), create time with :00
        elseif ($TimeStr -match '^\d{1,2}$') {
            $hour = [int]$TimeStr
            if ($hour -ge 0 -and $hour -le 23) {
                return Get-Date -Hour $hour -Minute 0 -Second 0
            } else {
                throw "Hour must be between 0 and 23"
            }
        }
        else {
            throw "Invalid time format"
        }
    } catch {
        Write-Warning "Invalid time format: '$TimeStr'. Expected 'HH:mm' or 'HH'"
        return $null
    }
}

Function Test-InSuppressionWindow {
    param(
        [string]$StartTime,
        [string]$EndTime,
        [DateTime]$CheckTime = (Get-Date)
    )
    
    if (-not $StartTime -or -not $EndTime) {
        return $false
    }
    
    $start = Parse-TimeString -TimeStr $StartTime
    $end = Parse-TimeString -TimeStr $EndTime
    
    if (-not $start -or -not $end) {
        Write-Warning "Invalid suppression hours specified. Suppression disabled."
        return $false
    }
    
    # Get current time (hour and minute only for comparison)
    $currentTime = Get-Date -Hour $CheckTime.Hour -Minute $CheckTime.Minute -Second 0
    $startOfDay = Get-Date -Hour 0 -Minute 0 -Second 0
    
    $suppressStart = Get-Date -Hour $start.Hour -Minute $start.Minute -Second 0
    $suppressEnd = Get-Date -Hour $end.Hour -Minute $end.Minute -Second 0
    
    # Handle overnight suppression windows (e.g., 22:00 to 06:00)
    if ($suppressEnd -le $suppressStart) {
        # Window spans midnight
        return ($currentTime -ge $suppressStart -or $currentTime -lt $suppressEnd)
    } else {
        # Normal same-day window
        return ($currentTime -ge $suppressStart -and $currentTime -lt $suppressEnd)
    }
}

Function Get-NextTimeOutsideSuppressionWindow {
    param(
        [DateTime]$TargetTime,
        [string]$StartTime,
        [string]$EndTime
    )
    
    if (-not $StartTime -or -not $EndTime) {
        return $TargetTime
    }
    
    $start = Parse-TimeString -TimeStr $StartTime
    $end = Parse-TimeString -TimeStr $EndTime
    
    if (-not $start -or -not $end) {
        return $TargetTime
    }
    
    # Check if target time falls within suppression window
    $checkTime = Get-Date -Date $TargetTime -Hour $TargetTime.Hour -Minute $TargetTime.Minute -Second 0
    $suppressStart = Get-Date -Date $TargetTime -Hour $start.Hour -Minute $start.Minute -Second 0
    $suppressEnd = Get-Date -Date $TargetTime -Hour $end.Hour -Minute $end.Minute -Second 0
    
    # Handle overnight suppression windows
    if ($suppressEnd -le $suppressStart) {
        # Window spans midnight
        if ($checkTime -ge $suppressStart -or $checkTime -lt $suppressEnd) {
            # Move to end of suppression window
            if ($checkTime -ge $suppressStart) {
                # Currently after start time, end is tomorrow
                return Get-Date -Date $TargetTime.AddDays(1) -Hour $end.Hour -Minute $end.Minute -Second 0
            } else {
                # Currently before end time (early morning)
                return Get-Date -Date $TargetTime -Hour $end.Hour -Minute $end.Minute -Second 0
            }
        }
    } else {
        # Normal same-day window
        if ($checkTime -ge $suppressStart -and $checkTime -lt $suppressEnd) {
            # Move to end of suppression window (same day)
            return Get-Date -Date $TargetTime -Hour $end.Hour -Minute $end.Minute -Second 0
        }
    }
    
    return $TargetTime
}

Function Get-RebootInfo {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $lastBoot = $os.LastBootUpTime
    $uptime = (Get-Date) - $lastBoot
    
    [PSCustomObject]@{
        LastBootTime = $lastBoot
        UptimeFormatted = "{0} days, {1} hours, {2} minutes" -f $uptime.Days, $uptime.Hours, $uptime.Minutes
    }
}

Function Get-ScheduledRebootStatus {
    param(
        [DateTime]$ExpectedTime = $null
    )
    
    # Check Task Scheduler for ImmyBot reboot tasks
    try {
        $tasks = Get-ScheduledTask | Where-Object { 
            $_.TaskName -like "*Reboot*" -or 
            $_.TaskName -like "*ImmyBot*" -or
            ($_.Actions.Execute -like "*shutdown*" -and $_.Actions.Arguments -like "*-r*")
        }
        
        $scheduledReboots = @()
        $matchesExpectedTime = $false
        
        foreach ($task in $tasks) {
            $taskInfo = Get-ScheduledTaskInfo -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction SilentlyContinue
            if ($taskInfo) {
                $taskData = [PSCustomObject]@{
                    TaskName = $task.TaskName
                    NextRunTime = $taskInfo.NextRunTime
                    State = $task.State
                    LastRunTime = $taskInfo.LastRunTime
                    MatchesExpected = $false
                }
                
                # Check if this task matches the expected time (if provided)
                if ($ExpectedTime -and $taskInfo.NextRunTime) {
                    # Allow a 2-minute tolerance window
                    $timeDiff = [Math]::Abs(($taskInfo.NextRunTime - $ExpectedTime).TotalMinutes)
                    if ($timeDiff -le 2) {
                        $taskData.MatchesExpected = $true
                        $matchesExpectedTime = $true
                    }
                }
                
                $scheduledReboots += $taskData
            }
        }
        
        return [PSCustomObject]@{
            HasScheduledReboot = ($scheduledReboots.Count -gt 0)
            MatchesExpectedTime = $matchesExpectedTime
            ExpectedTime = $ExpectedTime
            ScheduledTasks = $scheduledReboots
        }
    } catch {
        Write-Warning "Could not query scheduled tasks: $_"
        return [PSCustomObject]@{
            HasScheduledReboot = $false
            MatchesExpectedTime = $false
            ExpectedTime = $ExpectedTime
            ScheduledTasks = @()
            Error = $_.Exception.Message
        }
    }
}

Function Get-PendingRebootStatus {
    $pending = $false
    
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") {
        $pending = $true
    }
    
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") {
        $pending = $true
    }
    
    if (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -ErrorAction SilentlyContinue) {
        $pending = $true
    }
    
    return $pending
}

Function Resolve-NextScheduledReboot {
    param(
        [string]$Day,
        [string]$Time
    )
    
    # Validate day
    if ($Day -and ($Day -notin [System.DayOfWeek]::GetNames([System.DayOfWeek]))) {
        Write-Host "Invalid day: '$Day'. No reboot scheduled." -ForegroundColor Yellow
        return $null
    }
    
    # Validate time
    $parsedTime = Parse-TimeString -TimeStr $Time
    if ($Time -and -not $parsedTime) {
        Write-Host "Invalid time: '$Time'. Expected format: 'HH:mm' or 'HH' (e.g., '21:00' or '21'). No reboot scheduled." -ForegroundColor Yellow
        return $null
    }
    
    # If neither provided → no schedule needed (immediate reboot logic elsewhere)
    if (-not $Day -and -not $Time) {
        return "IMMEDIATE"
    }
    
    # Create baseline date
    $now = Get-Date
    $target = $now
    
    # Apply time if provided
    if ($parsedTime) {
        $target = Get-Date -Hour $parsedTime.Hour -Minute $parsedTime.Minute -Second 0
    }
    
    # Apply day if provided
    if ($Day) {
        $targetDay = [System.DayOfWeek]::$Day
        while ($target.DayOfWeek -ne $targetDay) {
            $target = $target.AddDays(1)
        }
    }
    
    # Ensure future time
    if ($target -le $now) {
        if ($Day) {
            # If a specific day was requested, move to next week
            $target = $target.AddDays(7)
        } else {
            # If just a time, move to next day
            $target = $target.AddDays(1)
        }
    }
    
    return $target
}

Function Create-ScheduledRebootTask {
    param(
        [DateTime]$ScheduledTime
    )
    
    # Format date and time for schtasks
    $schedDate = $ScheduledTime.ToString("MM/dd/yyyy")
    $schedTime = $ScheduledTime.ToString("HH:mm")
    
    Write-Host "Creating scheduled task '$TaskName' for $schedDate at $schedTime" -ForegroundColor Cyan
    
    # Delete existing task if it exists to ensure clean slate
    schtasks /Delete /TN $TaskName /F 2>$null | Out-Null
    
    # Create the scheduled task with /F flag to force creation
    $result = schtasks /Create /SC ONCE /TN $TaskName /TR "shutdown.exe /r /f /t 0" /ST $schedTime /SD $schedDate /RU "SYSTEM" /F 2>&1
    
    # Check if creation was successful
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Task created successfully" -ForegroundColor Green
        
        # Pause briefly to ensure the task is registered
        Start-Sleep -Seconds 2
        
        # Verify the task exists
        $taskInfo = schtasks /Query /TN $TaskName /V /FO LIST 2>$null
        
        if ($taskInfo) {
            # Extract the next run time and state
            $nextRun = ($taskInfo | Where-Object {$_ -match "Next Run Time"}) -replace "Next Run Time:\s+", ""
            $status = ($taskInfo | Where-Object {$_ -match "Status"}) -replace "Status:\s+", ""
            
            Write-Host "Next Run Time: $nextRun" -ForegroundColor White
            Write-Host "Status: $status" -ForegroundColor White
            
            return $true
        } else {
            Write-Host "✗ Task was created but could not be verified" -ForegroundColor Yellow
            return $false
        }
    } else {
        Write-Host "✗ Failed to create task: $result" -ForegroundColor Red
        return $false
    }
}

switch ($Method) {
    "get" {
        # If day/time parameters provided, calculate expected time for validation
        $expectedTime = $null
        if ($DayOfWeek -or $Time) {
            $expectedTime = Resolve-NextScheduledReboot -Day $DayOfWeek -Time $Time
            if ($expectedTime -eq "IMMEDIATE" -or $expectedTime -eq $null) {
                $expectedTime = $null
            }
        }
        
        $info = Get-RebootInfo
        Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "            SYSTEM REBOOT STATUS            " -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Last Boot Time: " -NoNewline -ForegroundColor White
        Write-Host "$($info.LastBootTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Green
        Write-Host "Current Uptime: " -NoNewline -ForegroundColor White
        Write-Host "$($info.UptimeFormatted)" -ForegroundColor Green
        Write-Host ""
        
        # Display suppression hours if configured
        if ($SuppressionHoursStart -and $SuppressionHoursEnd) {
            Write-Host "─────────────────────────────────────────" -ForegroundColor Gray
            Write-Host "Suppression Hours Configuration:" -ForegroundColor Cyan
            Write-Host "  Start: $SuppressionHoursStart" -ForegroundColor White
            Write-Host "  End:   $SuppressionHoursEnd" -ForegroundColor White
            
            $inSuppression = Test-InSuppressionWindow -StartTime $SuppressionHoursStart -EndTime $SuppressionHoursEnd
            if ($inSuppression) {
                Write-Host "  Status: Currently in suppression window" -ForegroundColor Yellow
            } else {
                Write-Host "  Status: Outside suppression window" -ForegroundColor Green
            }
            Write-Host ""
        }
        
        # Check for pending reboots
        Write-Host "─────────────────────────────────────────" -ForegroundColor Gray
        Write-Host "Pending Reboot Indicators:" -ForegroundColor Yellow
        $pending = Get-PendingRebootStatus
        
        if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") {
            Write-Host "  ✓ Windows Update" -ForegroundColor Yellow
        }
        
        if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") {
            Write-Host "  ✓ Component Based Servicing" -ForegroundColor Yellow
        }
        
        if (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -ErrorAction SilentlyContinue) {
            Write-Host "  ✓ Pending File Rename Operations" -ForegroundColor Yellow
        }
        
        if (-not $pending) {
            Write-Host "  No pending reboot flags detected." -ForegroundColor Green
        }
        Write-Host ""
        
        # Check for scheduled reboots
        Write-Host "─────────────────────────────────────────" -ForegroundColor Gray
        Write-Host "Scheduled Reboot Status:" -ForegroundColor Cyan
        
        if ($expectedTime) {
            Write-Host "  Expected Time: $($expectedTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
        }
        
        $scheduleStatus = Get-ScheduledRebootStatus -ExpectedTime $expectedTime
        
        if ($scheduleStatus.ScheduledTasks.Count -gt 0) {
            Write-Host "  ✓ Found $($scheduleStatus.ScheduledTasks.Count) scheduled task(s):" -ForegroundColor Yellow
            foreach ($task in $scheduleStatus.ScheduledTasks) {
                $matchIndicator = if ($task.MatchesExpected) { " ✓ MATCH" } else { "" }
                Write-Host "    - $($task.TaskName)$matchIndicator" -ForegroundColor White
                if ($task.NextRunTime) {
                    $color = if ($task.MatchesExpected) { "Green" } else { "Gray" }
                    Write-Host "      Next Run: $($task.NextRunTime.ToString('yyyy-MM-dd HH:mm:ss')) [$($task.State)]" -ForegroundColor $color
                } else {
                    Write-Host "      Next Run: Not scheduled [$($task.State)]" -ForegroundColor Gray
                }
            }
        }
        
        if (-not $scheduleStatus.HasScheduledReboot) {
            Write-Host "  No scheduled reboots detected." -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        
        # Determine return value
        # If expected time was provided, check if it matches
        if ($expectedTime) {
            $result = $scheduleStatus.MatchesExpectedTime
            if ($result) {
                Write-Host "Result: TRUE - Reboot scheduled at expected time" -ForegroundColor Green
            } else {
                Write-Host "Result: FALSE - No reboot scheduled at expected time ($($expectedTime.ToString('yyyy-MM-dd HH:mm:ss')))" -ForegroundColor Yellow
            }
        } else {
            # If no expected time, just check if any reboot is pending or scheduled
            $result = $pending -or $scheduleStatus.HasScheduledReboot
            if ($result) {
                Write-Host "Result: TRUE - Reboot is pending or scheduled" -ForegroundColor Green
            } else {
                Write-Host "Result: FALSE - No reboot pending or scheduled" -ForegroundColor Yellow
            }
        }
        
        return $result
    }
    
    "set" {
        $schedule = Resolve-NextScheduledReboot -Day $DayOfWeek -Time $Time
        
        if ($schedule -eq "IMMEDIATE") {
            # Check if we're in suppression window
            if (Test-InSuppressionWindow -StartTime $SuppressionHoursStart -EndTime $SuppressionHoursEnd) {
                Write-Host "⚠ Current time is within suppression window ($SuppressionHoursStart - $SuppressionHoursEnd)" -ForegroundColor Yellow
                Write-Host "Reboot blocked by suppression hours. No reboot will occur." -ForegroundColor Red
                return $false
            }
            
            Write-Host "Rebooting immediately — triggered by ImmyBot." -ForegroundColor Cyan
            shutdown.exe /r /f /t 30 /c "Reboot initiated by ImmyBot (immediate)"
            return $true
        }
        
        if ($schedule -eq $null) {
            Write-Host "No valid schedule provided. Reboot aborted." -ForegroundColor Yellow
            return $false
        }
        
        # Adjust schedule if it falls within suppression window
        $adjustedSchedule = Get-NextTimeOutsideSuppressionWindow -TargetTime $schedule -StartTime $SuppressionHoursStart -EndTime $SuppressionHoursEnd
        
        if ($adjustedSchedule -ne $schedule) {
            Write-Host "⚠ Originally scheduled time ($($schedule.ToString('yyyy-MM-dd HH:mm:ss'))) falls within suppression window" -ForegroundColor Yellow
            Write-Host "Adjusting to: $($adjustedSchedule.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan
            $schedule = $adjustedSchedule
        }
        
        # Create scheduled task for the reboot
        $success = Create-ScheduledRebootTask -ScheduledTime $schedule
        
        if ($success) {
            Write-Host ""
            Write-Host "✓ Reboot successfully scheduled for: $($schedule.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Green
            
            if ($SuppressionHoursStart -and $SuppressionHoursEnd) {
                Write-Host "  Suppression hours: $SuppressionHoursStart - $SuppressionHoursEnd" -ForegroundColor Gray
            }
            
            # Verify it matches the expected time
            Start-Sleep -Seconds 1
            $verification = Get-ScheduledRebootStatus -ExpectedTime $schedule
            
            if ($verification.MatchesExpectedTime) {
                Write-Host "✓ Verified: Task scheduled at correct time" -ForegroundColor Green
                return $true
            } else {
                Write-Host "⚠ Warning: Task exists but may not match expected time" -ForegroundColor Yellow
                return $false
            }
        } else {
            Write-Host ""
            Write-Host "✗ Failed to schedule reboot" -ForegroundColor Red
            return $false
        }
    }
    
    "test" {
        # Calculate expected time if parameters provided
        $expectedTime = $null
        if ($DayOfWeek -or $Time) {
            $expectedTime = Resolve-NextScheduledReboot -Day $DayOfWeek -Time $Time
            if ($expectedTime -eq "IMMEDIATE" -or $expectedTime -eq $null) {
                $expectedTime = $null
            }
        }
        
        Write-Host "Testing for scheduled reboots..." -ForegroundColor Cyan
        
        if ($expectedTime) {
            Write-Host "Expected Time: $($expectedTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
        }
        
        if ($SuppressionHoursStart -and $SuppressionHoursEnd) {
            Write-Host "Suppression Hours: $SuppressionHoursStart - $SuppressionHoursEnd" -ForegroundColor White
            $inSuppression = Test-InSuppressionWindow -StartTime $SuppressionHoursStart -EndTime $SuppressionHoursEnd
            if ($inSuppression) {
                Write-Host "Status: Currently in suppression window" -ForegroundColor Yellow
            } else {
                Write-Host "Status: Outside suppression window" -ForegroundColor Green
            }
        }
        
        $scheduleStatus = Get-ScheduledRebootStatus -ExpectedTime $expectedTime
        $info = Get-RebootInfo
        
        Write-Host ""
        Write-Host "Last Boot Time: $($info.LastBootTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
        Write-Host ""
        
        if ($scheduleStatus.ScheduledTasks.Count -gt 0) {
            Write-Host "✓ Found $($scheduleStatus.ScheduledTasks.Count) scheduled reboot task(s):" -ForegroundColor Green
            foreach ($task in $scheduleStatus.ScheduledTasks) {
                $matchIndicator = if ($task.MatchesExpected) { " ✓ MATCHES EXPECTED" } else { "" }
                if ($task.NextRunTime) {
                    $color = if ($task.MatchesExpected) { "Green" } else { "White" }
                    Write-Host "  - $($task.TaskName): $($task.NextRunTime.ToString('yyyy-MM-dd HH:mm:ss'))$matchIndicator" -ForegroundColor $color
                } else {
                    Write-Host "  - $($task.TaskName): No next run time" -ForegroundColor Gray
                }
            }
        } else {
            Write-Host "✗ No scheduled reboot tasks found" -ForegroundColor Gray
        }
        
        Write-Host ""
        
        # If expected time was provided, check if it matches
        if ($expectedTime) {
            if ($scheduleStatus.MatchesExpectedTime) {
                Write-Host "Result: TRUE - Scheduled reboot matches expected time" -ForegroundColor Green
                return $true
            } else {
                Write-Host "Result: FALSE - No reboot scheduled at expected time" -ForegroundColor Yellow
                return $false
            }
        } else {
            # If no expected time, just check if any reboot exists
            if ($scheduleStatus.HasScheduledReboot) {
                Write-Host "Result: TRUE - Scheduled reboot detected" -ForegroundColor Green
                return $true
            } else {
                Write-Host "Result: FALSE - No scheduled reboot" -ForegroundColor Yellow
                return $false
            }
        }
    }
}