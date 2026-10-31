<#
.SYNOPSIS
    Installs Chocolatey and the WinGet PowerShell packages.
.DESCRIPTION
    Installs Chocolatey, uses it to install or reinstall winget-cli and
    winget.powershell, and sends a completion notification to ntfy.sh.
    A reboot or removal of Chocolatey ProgramData may be required if package
    dependencies are not available.
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
