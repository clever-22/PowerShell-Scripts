<#
.SYNOPSIS
    Lists and removes browser extensions for all users. Safe to run as SYSTEM.
.DESCRIPTION
    Enumerates every profile under C:\Users and scans Chrome, Edge, and Firefox
    extension directories using absolute paths rather than environment variables.
    Provides an interactive menu to remove selected extensions.
    Exports results to C:\Temp\browser-extensions.json.
.NOTES
    Run as SYSTEM (e.g. via Intune, SCCM, or PSExec -s).
    Close target browsers on the machine before removing extensions.
#>

# ── Configuration ──────────────────────────────────────────────────────────────
$outputDir  = "C:\Temp"
$outputFile = "$outputDir\browser-extensions.json"

if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$allExtensions = New-Object System.Collections.ArrayList

# ── Resolve user profiles from registry ───────────────────────────────────────
# Using the registry rather than dir-guessing gives us the real ProfileImagePath
# and naturally excludes system pseudo-accounts.
function Get-UserProfiles {
    $profiles = @()
    $regBase  = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"

    foreach ($key in (Get-ChildItem $regBase -ErrorAction SilentlyContinue)) {
        $profilePath = (Get-ItemProperty $key.PSPath -ErrorAction SilentlyContinue).ProfileImagePath
        if (-not $profilePath) { continue }

        # Skip system pseudo-profiles
        if ($profilePath -match '\\(systemprofile|LocalService|NetworkService|Default User|Default|Public|All Users)$') {
            continue
        }
        if (Test-Path $profilePath) {
            $profiles += $profilePath
        }
    }
    return $profiles
}

# ── Helper: Resolve __MSG_ localisation strings ────────────────────────────────
function Resolve-ManifestString {
    param ([string]$Value, [string]$ExtensionFolder)

    if ($Value -match '^__MSG_(.+)__$') {
        $msgKey           = $Matches[1]
        $localeCandidates = @("en_US", "en") + (
            Get-ChildItem "$ExtensionFolder\_locales" -Directory -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty Name
        ) | Select-Object -Unique

        foreach ($locale in $localeCandidates) {
            $msgFile = "$ExtensionFolder\_locales\$locale\messages.json"
            if (Test-Path $msgFile) {
                try {
                    $msgs  = Get-Content $msgFile -Raw | ConvertFrom-Json
                    $entry = $msgs.$msgKey
                    if ($entry -and $entry.message) { return $entry.message }
                } catch {}
            }
        }
        return $Value
    }
    return $Value
}

# ── Scan: Chrome / Edge ────────────────────────────────────────────────────────
function Get-ChromiumExtensions {
    param (
        [string]$BrowserName,
        [string]$BrowserPath,
        [string]$UserName
    )

    if (-not (Test-Path $BrowserPath)) { return }

    Write-Host "  [$UserName] Scanning $BrowserName..." -ForegroundColor Cyan

    foreach ($extension in (Get-ChildItem -Path $BrowserPath -Directory -ErrorAction SilentlyContinue)) {
        $ExtID          = $extension.Name
        $versionFolders = Get-ChildItem -Path $extension.FullName -Directory -ErrorAction SilentlyContinue
        if (-not $versionFolders) { continue }

        $latestVersion = $versionFolders | Sort-Object Name -Descending | Select-Object -First 1
        $manifestPath  = Join-Path $latestVersion.FullName "manifest.json"
        if (-not (Test-Path $manifestPath)) { continue }

        try {
            $manifest     = Get-Content $manifestPath -Raw | ConvertFrom-Json
            $resolvedName = Resolve-ManifestString -Value $manifest.name        -ExtensionFolder $latestVersion.FullName
            $resolvedDesc = Resolve-ManifestString -Value $manifest.description -ExtensionFolder $latestVersion.FullName

            $extObj = [PSCustomObject]@{
                User        = $UserName
                Browser     = $BrowserName
                Name        = $resolvedName
                ID          = $ExtID
                Version     = $manifest.version
                Description = $resolvedDesc
                Path        = $extension.FullName   # root folder containing all version subfolders
            }

            [void]$allExtensions.Add($extObj)
            Write-Host "    Found: $resolvedName [$ExtID]" -ForegroundColor Green
        } catch {
            Write-Host "    Error reading $ExtID : $_" -ForegroundColor Red
        }
    }
}

# ── Scan: Firefox ──────────────────────────────────────────────────────────────
function Get-FirefoxExtensions {
    param (
        [string]$ProfilePath,   # e.g. C:\Users\jsmith
        [string]$UserName
    )

    $firefoxProfilesPath = Join-Path $ProfilePath "AppData\Roaming\Mozilla\Firefox\Profiles"
    if (-not (Test-Path $firefoxProfilesPath)) { return }

    Write-Host "  [$UserName] Scanning Firefox..." -ForegroundColor Cyan

    foreach ($profile in (Get-ChildItem $firefoxProfilesPath -Directory -ErrorAction SilentlyContinue)) {
        $extensionsJsonPath = Join-Path $profile.FullName "extensions.json"
        if (-not (Test-Path $extensionsJsonPath)) { continue }

        try {
            $data = Get-Content $extensionsJsonPath -Raw | ConvertFrom-Json
            foreach ($addon in $data.addons) {
                if ($addon.location -eq "app-builtin") { continue }

                $xpiPath = $null
                $extDir  = $null
                if ($addon.path -and (Test-Path $addon.path)) {
                    if ($addon.path -match '\.xpi$') { $xpiPath = $addon.path }
                    else                             { $extDir  = $addon.path }
                }

                $extObj = [PSCustomObject]@{
                    User        = $UserName
                    Browser     = "Firefox"
                    Name        = $addon.defaultLocale.name
                    ID          = $addon.id
                    Version     = $addon.version
                    Description = $addon.defaultLocale.description
                    ProfilePath = $profile.FullName
                    XpiPath     = $xpiPath
                    ExtDir      = $extDir
                    Path        = $null   # unified field placeholder
                }

                [void]$allExtensions.Add($extObj)
                Write-Host "    Found: $($addon.defaultLocale.name) [$($addon.id)]" -ForegroundColor Green
            }
        } catch {
            Write-Host "    Error reading extensions.json in $($profile.Name): $_" -ForegroundColor Red
        }
    }
}

# ── Remove: Chrome / Edge ──────────────────────────────────────────────────────
function Remove-ChromiumExtension {
    param ([PSCustomObject]$ext)

    if (-not $ext.Path) {
        Write-Host "  No path recorded for '$($ext.Name)'. Skipping." -ForegroundColor Yellow
        return $false
    }
    try {
        Remove-Item -Path $ext.Path -Recurse -Force -ErrorAction Stop
        Write-Host "  Removed [$($ext.User)] $($ext.Name)" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "  Failed to remove '$($ext.Name)': $_" -ForegroundColor Red
        return $false
    }
}

# ── Remove: Firefox ────────────────────────────────────────────────────────────
function Remove-FirefoxExtension {
    param ([PSCustomObject]$ext)

    $removed = $false

    # Remove the physical file / directory
    if ($ext.XpiPath -and (Test-Path $ext.XpiPath)) {
        try {
            Remove-Item $ext.XpiPath -Force -ErrorAction Stop
            Write-Host "  Removed XPI: $($ext.XpiPath)" -ForegroundColor Green
            $removed = $true
        } catch {
            Write-Host "  Failed to remove XPI: $_" -ForegroundColor Red
        }
    } elseif ($ext.ExtDir -and (Test-Path $ext.ExtDir)) {
        try {
            Remove-Item $ext.ExtDir -Recurse -Force -ErrorAction Stop
            Write-Host "  Removed dir: $($ext.ExtDir)" -ForegroundColor Green
            $removed = $true
        } catch {
            Write-Host "  Failed to remove dir: $_" -ForegroundColor Red
        }
    }

    # Scrub the entry from extensions.json so Firefox doesn't ghost-list it
    if ($ext.ProfilePath) {
        $jsonPath = Join-Path $ext.ProfilePath "extensions.json"
        if (Test-Path $jsonPath) {
            try {
                $jsonObj        = Get-Content $jsonPath -Raw | ConvertFrom-Json
                $jsonObj.addons = @($jsonObj.addons | Where-Object { $_.id -ne $ext.ID })
                $jsonObj | ConvertTo-Json -Depth 10 | Set-Content $jsonPath -Encoding UTF8
                Write-Host "  Updated extensions.json in $($ext.ProfilePath)" -ForegroundColor Green
                $removed = $true
            } catch {
                Write-Host "  Could not update extensions.json: $_" -ForegroundColor Red
            }
        }
    }

    if (-not $removed) {
        Write-Host "  Nothing removed for '$($ext.Name)' — may be managed or built-in." -ForegroundColor Yellow
    }
    return $removed
}

# ── Dispatch removal by browser ────────────────────────────────────────────────
function Remove-Extension {
    param ([PSCustomObject]$ext)
    if ($ext.Browser -eq "Firefox") { return Remove-FirefoxExtension  -ext $ext }
    else                            { return Remove-ChromiumExtension -ext $ext }
}

# ── Interactive removal menu ───────────────────────────────────────────────────
function Invoke-RemovalMenu {
    if ($allExtensions.Count -eq 0) {
        Write-Host "No extensions to remove." -ForegroundColor Yellow
        return
    }

    while ($true) {
        Write-Host "`n══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host " Installed Extensions" -ForegroundColor Cyan
        Write-Host "══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host (" {0,-4} {1,-35} {2,-8} {3,-14} {4}" -f "#", "Name", "Browser", "User", "ID")
        Write-Host ("─" * 95)

        for ($i = 0; $i -lt $allExtensions.Count; $i++) {
            $e = $allExtensions[$i]
            Write-Host (" [{0,2}] {1,-35} {2,-8} {3,-14} {4}" -f ($i + 1), $e.Name, $e.Browser, $e.User, $e.ID)
        }

        Write-Host "`n  [A]  Remove ALL extensions (all users)"
        Write-Host "  [U]  Remove all extensions for a specific user"
        Write-Host "  [Q]  Quit"
        Write-Host "──────────────────────────────────────────────────────────────────"
        $choice = Read-Host "Enter number(s) to remove (comma-separated), A, U, or Q"

        # Quit
        if ($choice -eq 'Q') { break }

        # Remove all
        if ($choice -eq 'A') {
            $confirm = Read-Host "Remove ALL $($allExtensions.Count) extension(s) across ALL users? (yes/no)"
            if ($confirm -ne 'yes') { Write-Host "Aborted." -ForegroundColor Yellow; continue }

            $snapshot = @($allExtensions)
            $count    = 0
            foreach ($e in $snapshot) {
                if (Remove-Extension -ext $e) {
                    [void]$allExtensions.Remove($e)
                    $count++
                }
            }
            Write-Host "`nRemoved $count extension(s)." -ForegroundColor Cyan
            continue
        }

        # Remove by user
        if ($choice -eq 'U') {
            $users = $allExtensions | Select-Object -ExpandProperty User -Unique | Sort-Object
            Write-Host "`nAvailable users:"
            for ($u = 0; $u -lt $users.Count; $u++) {
                Write-Host ("  [{0}] {1}" -f ($u + 1), $users[$u])
            }
            $uInput = Read-Host "Select user number"
            if ($uInput -match '^\d+$' -and ([int]$uInput - 1) -ge 0 -and ([int]$uInput - 1) -lt $users.Count) {
                $selectedUser = $users[[int]$uInput - 1]
                $userExts     = @($allExtensions | Where-Object { $_.User -eq $selectedUser })
                Write-Host "`nExtensions for $selectedUser ($($userExts.Count)):"
                $userExts | ForEach-Object { Write-Host "  - $($_.Name) [$($_.Browser)]" -ForegroundColor Yellow }
                $confirm = Read-Host "Remove all of these? (yes/no)"
                if ($confirm -ne 'yes') { Write-Host "Aborted." -ForegroundColor Yellow; continue }

                $count = 0
                foreach ($e in $userExts) {
                    if (Remove-Extension -ext $e) {
                        [void]$allExtensions.Remove($e)
                        $count++
                    }
                }
                Write-Host "`nRemoved $count extension(s) for $selectedUser." -ForegroundColor Cyan
            } else {
                Write-Host "Invalid selection." -ForegroundColor Yellow
            }
            continue
        }

        # Remove by number
        $indices = $choice -split ',' |
                   ForEach-Object { $_.Trim() } |
                   Where-Object   { $_ -match '^\d+$' } |
                   ForEach-Object { [int]$_ - 1 } |
                   Where-Object   { $_ -ge 0 -and $_ -lt $allExtensions.Count } |
                   Select-Object  -Unique |
                   Sort-Object    -Descending

        if ($indices.Count -eq 0) { Write-Host "No valid selection." -ForegroundColor Yellow; continue }

        Write-Host "`nSelected for removal:"
        foreach ($idx in ($indices | Sort-Object)) {
            $e = $allExtensions[$idx]
            Write-Host ("  [{0,2}] {1} ({2} / {3})" -f ($idx + 1), $e.Name, $e.Browser, $e.User) -ForegroundColor Yellow
        }
        $confirm = Read-Host "Confirm removal? (yes/no)"
        if ($confirm -ne 'yes') { Write-Host "Aborted." -ForegroundColor Yellow; continue }

        $count = 0
        foreach ($idx in $indices) {
            if (Remove-Extension -ext $allExtensions[$idx]) {
                [void]$allExtensions.RemoveAt($idx)
                $count++
            }
        }
        Write-Host "`nRemoved $count extension(s)." -ForegroundColor Cyan
    }
}

# ── Main ───────────────────────────────────────────────────────────────────────
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
Write-Host "`n Browser Extension Manager" -ForegroundColor Magenta
Write-Host " Running as : $identity" -ForegroundColor Magenta
Write-Host " NOTE: Browsers on this machine should be closed before removing extensions.`n" -ForegroundColor Yellow

$userProfiles = Get-UserProfiles
if ($userProfiles.Count -eq 0) {
    Write-Host "No user profiles found. Exiting." -ForegroundColor Red
    exit 1
}

Write-Host "Found $($userProfiles.Count) user profile(s). Scanning...`n" -ForegroundColor Cyan

foreach ($profilePath in $userProfiles) {
    $userName = Split-Path $profilePath -Leaf

    Get-ChromiumExtensions -BrowserName "Chrome" `
        -BrowserPath (Join-Path $profilePath "AppData\Local\Google\Chrome\User Data\Default\Extensions") `
        -UserName $userName

    Get-ChromiumExtensions -BrowserName "Edge" `
        -BrowserPath (Join-Path $profilePath "AppData\Local\Microsoft\Edge\User Data\Default\Extensions") `
        -UserName $userName

    Get-FirefoxExtensions -ProfilePath $profilePath -UserName $userName
}

if ($allExtensions.Count -eq 0) {
    Write-Host "`nNo extensions found across any user profiles." -ForegroundColor Yellow
    exit
}

Write-Host "`nScan complete — $($allExtensions.Count) extension(s) across $($userProfiles.Count) profile(s)." -ForegroundColor Cyan

$answer = Read-Host "`nWould you like to remove any extensions? (yes/no)"
if ($answer -eq 'yes') {
    Invoke-RemovalMenu
}

# Export whatever remains post-removal
$allExtensions | ConvertTo-Json -Depth 5 | Out-File -FilePath $outputFile -Encoding UTF8
Write-Host "`nResults saved to: $outputFile" -ForegroundColor Green