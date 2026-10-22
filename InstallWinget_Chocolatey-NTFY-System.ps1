<#
.SYNOPSIS
    Installs Chocolatey and installs Winget
.DESCRIPTION
    Installs the Chocolatey package manager and uses it to install installs Winget.
    Sends ntfy.sh notification when upgrade is complete.
    Sometimes needs you to delete Chocolatey ProgramData and rerun for it to work. Or just a reboot if certain dependencies aren't installed.
#>

# CONFIGURATION - CHANGE THIS!!!
$ntfyTopic = "Insertyourtopicnamehere"
$ntfyServer = "https://ntfy.sh"

# Install Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = `
    [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iwr https://community.chocolatey.org/install.ps1 -UseBasicParsing | iex

# Upgrade PowerShell
choco install winget-cli -y --force
choco install winget.powershell -y --force

# Send NTFY notification
$hostname = $env:COMPUTERNAME

Invoke-RestMethod `
    -Uri "$ntfyServer/$ntfyTopic" `
    -Method Post `
    -Body "Install completed on $hostname"

