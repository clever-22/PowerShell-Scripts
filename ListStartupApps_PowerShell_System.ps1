<#
.SYNOPSIS
    Enumerates autostart ("startup") items from every common Windows launch point.

.DESCRIPTION
    Checks:
      - Run / RunOnce / RunOnceEx / RunServices / RunServicesOnce  (HKLM, HKCU, WOW6432Node, all loaded HKU hives)
      - Policies\Explorer\Run (HKLM + HKCU)  <- the gpedit "Logon" policy location
      - Winlogon Shell / Userinit / AppInit_DLLs / BootExecute / Terminal Server keys
      - Active Setup Installed Components (StubPath)
      - Startup folders (shell:startup, shell:common startup, and every user profile on disk)
      - StartupApproved keys (Task Manager / msconfig Enabled-Disabled state)
      - Scheduled tasks with logon/boot/startup triggers
      - Group Policy Startup / Shutdown / Logon / Logoff scripts (registry + local GPO files)
      - Legacy HKCU Load / Run values
      - Services set to Automatic (with -IncludeServices)
      - Win32_StartupCommand (WMI's own view, as a cross-check)

.NOTES
    Run elevated for full coverage. Read-only - makes no changes.
    Optional: -CsvPath to export, -ThirdPartyOnly to hide Microsoft/Windows paths, -IncludeServices.
#>

[CmdletBinding()]
param(
    [string]$CsvPath,
    [switch]$IncludeServices,
    [switch]$ThirdPartyOnly
)

$ErrorActionPreference = 'SilentlyContinue'
$results = New-Object System.Collections.Generic.List[object]

function Add-Item {
    param($Name, $Command, $Location, $Source, $User = $env:USERNAME, $State = 'Unknown')
    if ([string]::IsNullOrWhiteSpace($Name)) { return }
    $results.Add([PSCustomObject]@{
        Name     = $Name
        Command  = ([string]$Command).Trim()
        Location = $Location
        Source   = $Source
        User     = $User
        State    = $State
    })
}

# ---------- 0. Map loaded user hives (HKU) to account names ----------
if (-not (Get-PSDrive -Name HKU)) {
    New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS -Scope Script | Out-Null
}

$sidMap = @{}
Get-ChildItem 'HKU:\' | Where-Object { $_.PSChildName -match '^S-1-5-21-[\d\-]+$' } | ForEach-Object {
    $sid = $_.PSChildName
    $acct = try { (New-Object System.Security.Principal.SecurityIdentifier($sid)).Translate([System.Security.Principal.NTAccount]).Value } catch { $sid }
    $sidMap[$sid] = $acct
}

# ---------- 1. Registry autostart keys ----------
$subKeys = @(
    'Software\Microsoft\Windows\CurrentVersion\Run',
    'Software\Microsoft\Windows\CurrentVersion\RunOnce',
    'Software\Microsoft\Windows\CurrentVersion\RunOnceEx',
    'Software\Microsoft\Windows\CurrentVersion\RunServices',
    'Software\Microsoft\Windows\CurrentVersion\RunServicesOnce',
    'Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run',
    'Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run',
    'Software\Wow6432Node\Microsoft\Windows\CurrentVersion\RunOnce',
    'Software\Wow6432Node\Microsoft\Windows\CurrentVersion\RunServices',
    'Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run'
)

$hives = @(
    @{ Prefix = 'HKLM:'; User = 'Machine' },
    @{ Prefix = 'HKCU:'; User = $env:USERNAME }
)
foreach ($sid in $sidMap.Keys) {
    $hives += @{ Prefix = "HKU:\$sid"; User = $sidMap[$sid] }
}

$skipProps = @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider')

foreach ($hive in $hives) {
    foreach ($sub in $subKeys) {
        $path = Join-Path $hive.Prefix $sub
        if (-not (Test-Path $path)) { continue }

        Get-ItemProperty -Path $path | ForEach-Object {
            foreach ($p in $_.PSObject.Properties) {
                if ($p.Name -in $skipProps) { continue }
                Add-Item -Name $p.Name -Command $p.Value -Location $path -Source 'Registry Run key' -User $hive.User
            }
        }

        # RunOnceEx stores commands in numbered subkeys
        if ($sub -like '*RunOnceEx*') {
            Get-ChildItem -Path $path | ForEach-Object {
                $childPath = $_.PSPath
                Get-ItemProperty -Path $childPath | ForEach-Object {
                    foreach ($p in $_.PSObject.Properties) {
                        if ($p.Name -in $skipProps) { continue }
                        Add-Item -Name $p.Name -Command $p.Value -Location $childPath.Replace('Microsoft.PowerShell.Core\Registry::','') -Source 'Registry RunOnceEx' -User $hive.User
                    }
                }
            }
        }
    }
}

# ---------- 2. Winlogon / AppInit / BootExecute / Terminal Server ----------
$winlogonChecks = @(
    @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'; Values = @('Shell','Userinit','TaskMan','VMApplet','AppSetup') },
    @{ Path = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\Winlogon'; Values = @('Shell','Userinit') },
    @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'; Values = @('Shell','Userinit') },
    @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows'; Values = @('AppInit_DLLs','LoadAppInit_DLLs','Run','IconServiceLib') },
    @{ Path = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\Windows'; Values = @('AppInit_DLLs','LoadAppInit_DLLs') },
    @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'; Values = @('BootExecute','SetupExecute','Execute','S0InitialCommand') },
    @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Terminal Server\Install\Software\Microsoft\Windows\CurrentVersion\Run'; Values = $null },
    @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Terminal Server\Install\Software\Microsoft\Windows\CurrentVersion\Runonce'; Values = $null }
)

foreach ($check in $winlogonChecks) {
    if (-not (Test-Path $check.Path)) { continue }
    $props = Get-ItemProperty -Path $check.Path
    foreach ($p in $props.PSObject.Properties) {
        if ($p.Name -in $skipProps) { continue }
        if ($check.Values -and ($p.Name -notin $check.Values)) { continue }
        if ([string]::IsNullOrWhiteSpace([string]$p.Value)) { continue }
        Add-Item -Name $p.Name -Command ($p.Value -join ', ') -Location $check.Path -Source 'Winlogon/System' -User 'Machine'
    }
}

# ---------- 3. Active Setup (runs once per user at first logon) ----------
foreach ($asPath in @('HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components',
                      'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Active Setup\Installed Components')) {
    if (-not (Test-Path $asPath)) { continue }
    Get-ChildItem -Path $asPath | ForEach-Object {
        $props = Get-ItemProperty -Path $_.PSPath
        if ($props.StubPath) {
            $label = if ($props.'(default)') { $props.'(default)' } else { $_.PSChildName }
            Add-Item -Name $label -Command $props.StubPath -Location $asPath -Source 'Active Setup' -User 'Machine'
        }
    }
}

# ---------- 4. Startup folders (shell:startup, shell:common startup, every profile) ----------
$folders = New-Object System.Collections.Generic.List[object]
$folders.Add([PSCustomObject]@{ Path = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\StartUp'; User = 'All Users' })

$profileRoot = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList').ProfilesDirectory
if (-not $profileRoot) { $profileRoot = 'C:\Users' }
$profileRoot = [Environment]::ExpandEnvironmentVariables($profileRoot)

Get-ChildItem -Path $profileRoot -Directory | ForEach-Object {
    $folders.Add([PSCustomObject]@{
        Path = Join-Path $_.FullName 'AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup'
        User = $_.Name
    })
}

foreach ($f in $folders) {
    if (-not (Test-Path $f.Path)) { continue }
    Get-ChildItem -Path $f.Path -Force -File | Where-Object { $_.Name -ne 'desktop.ini' } | ForEach-Object {
        $target = $_.FullName
        if ($_.Extension -eq '.lnk') {
            try {
                $sh = New-Object -ComObject WScript.Shell
                $lnk = $sh.CreateShortcut($_.FullName)
                if ($lnk.TargetPath) { $target = "$($lnk.TargetPath) $($lnk.Arguments)" }
            } catch {}
        }
        Add-Item -Name $_.BaseName -Command $target -Location $f.Path -Source 'Startup folder' -User $f.User
    }
}

# ---------- 5. StartupApproved (Task Manager / msconfig Enabled-Disabled state) ----------
$approvedPaths = @(
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'
)

$approved = @{}
foreach ($ap in $approvedPaths) {
    if (-not (Test-Path $ap)) { continue }
    $props = Get-ItemProperty -Path $ap
    foreach ($p in $props.PSObject.Properties) {
        if ($p.Name -in $skipProps) { continue }
        $bytes = $p.Value
        # First byte: even value = enabled, odd = disabled by user
        $state = if ($bytes -is [byte[]] -and $bytes.Length -gt 0 -and ($bytes[0] -band 1) -eq 0) { 'Enabled' } else { 'Disabled' }
        $key = ($p.Name -replace '\.lnk$','')
        $approved[$key.ToLower()] = $state
    }
}

foreach ($item in $results) {
    $lookup = ($item.Name -replace '\.lnk$','').ToLower()
    if ($approved.ContainsKey($lookup)) { $item.State = $approved[$lookup] }
    elseif ($item.Source -in @('Registry Run key','Startup folder')) { $item.State = 'Enabled' }
}

# ---------- 6. Scheduled tasks with logon/boot triggers ----------
Get-ScheduledTask | Where-Object {
    $_.State -ne 'Disabled' -and
    ($_.Triggers | Where-Object { $_.CimClass.CimClassName -match 'LogonTrigger|BootTrigger|RegistrationTrigger|SessionStateChangeTrigger' })
} | ForEach-Object {
    $task = $_
    $trigger = ($task.Triggers | ForEach-Object { $_.CimClass.CimClassName -replace 'MSFT_Task','' }) -join ','
    $action = ($task.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join ' | '
    Add-Item -Name $task.TaskName -Command $action.Trim() -Location "$($task.TaskPath)  [$trigger]" -Source 'Scheduled task' -User $task.Principal.UserId -State $task.State
}

# ---------- 6b. Group Policy Startup / Shutdown / Logon / Logoff scripts ----------
$gpScriptKeys = @(
    @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup';  Label = 'GPO Machine Startup Script';  User = 'Machine' },
    @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup';                Label = 'GPO Machine Startup Script';  User = 'Machine' },
    @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Shutdown'; Label = 'GPO Machine Shutdown Script'; User = 'Machine' },
    @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Scripts\Logon';            Label = 'GPO User Logon Script';       User = $env:USERNAME },
    @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Logon';                  Label = 'GPO User Logon Script';       User = $env:USERNAME }
)

foreach ($gp in $gpScriptKeys) {
    if (-not (Test-Path $gp.Path)) { continue }
    Get-ChildItem -Path $gp.Path -Recurse | ForEach-Object {
        $props = Get-ItemProperty -Path $_.PSPath
        if ($props.Script) {
            Add-Item -Name $props.Script -Command "$($props.Script) $($props.Parameters)" `
                     -Location "$($gp.Path)  [GPO: $($props.GPOName)]" -Source $gp.Label -User $gp.User -State 'Enabled'
        }
    }
}

# Local GPO script files on disk (gpedit -> Scripts (Startup/Shutdown))
$gpoScriptDirs = @(
    @{ Path = "$env:SystemRoot\System32\GroupPolicy\Machine\Scripts\Startup";  Label = 'Local GPO Startup Script (file)';  User = 'Machine' },
    @{ Path = "$env:SystemRoot\System32\GroupPolicy\Machine\Scripts\Shutdown"; Label = 'Local GPO Shutdown Script (file)'; User = 'Machine' },
    @{ Path = "$env:SystemRoot\System32\GroupPolicy\User\Scripts\Logon";       Label = 'Local GPO Logon Script (file)';    User = 'All Users' },
    @{ Path = "$env:SystemRoot\System32\GroupPolicy\User\Scripts\Logoff";      Label = 'Local GPO Logoff Script (file)';   User = 'All Users' }
)

foreach ($d in $gpoScriptDirs) {
    if (-not (Test-Path $d.Path)) { continue }
    Get-ChildItem -Path $d.Path -Force -File | Where-Object { $_.Name -notmatch '^(scripts|psscripts)\.ini$' } | ForEach-Object {
        Add-Item -Name $_.Name -Command $_.FullName -Location $d.Path -Source $d.Label -User $d.User -State 'Enabled'
    }
}

# ---------- 6c. Legacy HKCU Load / Run values ----------
$legacyWin = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows'
foreach ($v in @('Load','Run')) {
    if ($legacyWin.$v) {
        Add-Item -Name $v -Command $legacyWin.$v -Location 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows' -Source 'Legacy Load/Run' -User $env:USERNAME -State 'Enabled'
    }
}

# ---------- 7. Auto-start services (optional - noisy) ----------
# if ($IncludeServices) {
#     Get-CimInstance Win32_Service -Filter "StartMode='Auto'" | ForEach-Object {
#         $delayed = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\$($_.Name)").DelayedAutostart
#         $label = if ($delayed -eq 1) { 'Service (Auto - Delayed)' } else { 'Service (Auto)' }
#         Add-Item -Name $_.Name -Command $_.PathName -Location "Service: $($_.DisplayName)" -Source $label -User $_.StartName -State $_.State
#     }
# }

# ---------- 8. WMI's own startup view (catch-all cross-check) ----------
Get-CimInstance Win32_StartupCommand | ForEach-Object {
    Add-Item -Name $_.Name -Command $_.Command -Location $_.Location -Source 'Win32_StartupCommand' -User $_.User
}

# ---------- 9. De-dupe, filter, output ----------
$final = $results |
    Sort-Object Source, Location, Name |
    Group-Object { "$($_.Name)|$($_.Command)|$($_.User)" } |
    ForEach-Object { $_.Group[0] }

if ($ThirdPartyOnly) {
    $final = $final | Where-Object {
        $_.Command -notmatch '(?i)\\Windows\\(System32|SysWOW64|SystemApps|ImmersiveControlPanel)\\' -and
        $_.Command -notmatch '(?i)OneDrive|Microsoft\.Windows\.'
    }
}

if (-not $final) {
    Write-Host 'No startup items found.' -ForegroundColor Yellow
    return
}

Write-Host "`n=== Startup items found: $($final.Count) ===`n" -ForegroundColor Cyan
$final | Format-Table Source, User, State, Name, Command -AutoSize -Wrap

Write-Host "`n--- Count by source ---" -ForegroundColor Cyan
$final | Group-Object Source | Sort-Object Count -Descending | Format-Table Name, Count -AutoSize

if ($CsvPath) {
    $final | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
    Write-Host "Exported to $CsvPath" -ForegroundColor Green
}
