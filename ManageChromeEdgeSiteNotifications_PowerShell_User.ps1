<#
.SYNOPSIS
    Reviews and removes Chrome and Edge site notification permissions.
.DESCRIPTION
    Scans browser preference files for notification permissions across local
    user profiles, displays the discovered sites, and interactively removes
    selected entries after creating a backup of each modified preferences file.
    Run in a context with access to the target user profiles.
#>

Add-Type -AssemblyName System.Web.Extensions
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$ser.MaxJsonLength = 2147483647
$ser.RecursionLimit = 1000
$utf8 = New-Object System.Text.UTF8Encoding $false

$browsers = @(
    @{ Name = "Chrome"; Proc = "chrome"; Rel = "AppData\Local\Google\Chrome\User Data" },
    @{ Name = "Edge";   Proc = "msedge"; Rel = "AppData\Local\Microsoft\Edge\User Data" }
)

function Get-NotifDict($json) {
    try { return $json.Item('profile').Item('content_settings').Item('exceptions').Item('notifications') } catch { return $null }
}

$found = @()
$i = 0

Write-Host "`n--- Scanning ---" -ForegroundColor Cyan
foreach ($u in Get-ChildItem C:\Users -Directory -ErrorAction SilentlyContinue) {
    foreach ($b in $browsers) {
        $root = Join-Path $u.FullName $b.Rel
        if (-not (Test-Path -LiteralPath $root)) { continue }
        foreach ($p in Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue) {
            $pref = Join-Path $p.FullName "Preferences"
            if (-not (Test-Path -LiteralPath $pref)) { continue }
            try {
                $json  = $ser.DeserializeObject((Get-Content -LiteralPath $pref -Raw -Encoding UTF8))
                $notif = Get-NotifDict $json
                $count = 0; if ($notif) { $count = $notif.Count }
                Write-Host ("[{0}] {1} \ {2} -> {3} entries" -f $b.Name, $u.Name, $p.Name, $count) -ForegroundColor DarkGray
                if ($notif) {
                    foreach ($k in @($notif.Keys)) {
                        $i++
                        $s = $notif.Item($k).Item('setting')
                        $setting = switch ($s) { 1 {"Allow"} 2 {"Block"} default {"$s"} }
                        $found += New-Object PSObject -Property @{
                            Num = $i; User = $u.Name; Browser = $b.Name; Profile = $p.Name
                            Site = $k; Setting = $setting; File = $pref; Proc = $b.Proc
                        }
                    }
                }
            } catch {
                Write-Host ("[{0}] {1} \ {2} -> READ FAILED: {3}" -f $b.Name, $u.Name, $p.Name, $_.Exception.Message) -ForegroundColor Red
            }
        }
    }
}

if ($found.Count -eq 0) { Write-Host "`nNo notification permissions found." -ForegroundColor Yellow; return }

$found | Sort-Object Num | Format-Table Num, User, Browser, Profile, Site, Setting -AutoSize -Wrap

$pick = Read-Host "Enter Num(s) (e.g. 1,3,5), part of a domain, or Q to quit"
if ($pick -match '^\s*[Qq]\s*$') { return }

if ($pick -match '^[\d,\s]+$') {
    $nums   = $pick -split '[,\s]+' | Where-Object { $_ }
    $remove = @($found | Where-Object { $nums -contains "$($_.Num)" })
} else {
    $remove = @($found | Where-Object { $_.Site -like "*$pick*" })
}

if ($remove.Count -eq 0) { Write-Host "Nothing matched." -ForegroundColor Yellow; return }

$remove | Sort-Object Num | Format-Table Num, User, Browser, Profile, Site, Setting -AutoSize -Wrap
if ((Read-Host "Type YES to remove these") -ne "YES") { Write-Host "Cancelled."; return }

$remove | Select-Object -ExpandProperty Proc -Unique | ForEach-Object { Get-Process $_ -ErrorAction SilentlyContinue | Stop-Process -Force }
Start-Sleep -Seconds 2

foreach ($grp in ($remove | Group-Object File)) {
    $file = $grp.Name
    try {
        Copy-Item -LiteralPath $file "$file.bak-$(Get-Date -f yyyyMMdd-HHmmss)" -Force
        $json  = $ser.DeserializeObject((Get-Content -LiteralPath $file -Raw -Encoding UTF8))
        $notif = Get-NotifDict $json
        foreach ($r in $grp.Group) {
            if ($notif.ContainsKey($r.Site)) {
                $null = $notif.Remove($r.Site)
                Write-Host "Removed [$($r.Browser)] $($r.User): $($r.Site)" -ForegroundColor Green
            }
        }
        Set-Content -LiteralPath $file -Value $utf8.GetBytes($ser.Serialize($json)) -Encoding Byte
    } catch {
        Write-Host "Failed on $file : $($_.Exception.Message)" -ForegroundColor Red
    }
}
Write-Host "`nDone. Have the user reopen the browser." -ForegroundColor Cyan