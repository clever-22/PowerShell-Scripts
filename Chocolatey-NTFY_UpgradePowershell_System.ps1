<#
.SYNOPSIS
    Installs Chocolatey and upgrades PowerShell Core
.DESCRIPTION
    Installs the Chocolatey package manager and uses it to install PowerShell Core.
    Sends ntfy.sh notification when upgrade is complete.
    Sometimes needs you to delete Chocolatey ProgramData and rerun for it to work. Or just a reboot if certain dependencies aren't installed.
#>

# CONFIGURATION
$ntfyTopic = "Insertyourtopicnamehere"
$ntfyServer = "https://ntfy.sh"

# Install Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = `
    [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iwr https://community.chocolatey.org/install.ps1 -UseBasicParsing | iex

# Upgrade PowerShell
choco install powershell-core -y --force

# Send NTFY notification
$hostname = $env:COMPUTERNAME

Invoke-RestMethod `
    -Uri "https://ntfy.sh/$ntfyTopic" `
    -Method Post `
    -Body "✅ PowerShell Core upgrade completed on $hostname"

# Open new PowerShell
pwsh
