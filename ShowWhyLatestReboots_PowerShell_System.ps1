<#
.SYNOPSIS
    Shows the 5 most recent system shutdown events with reasons
.DESCRIPTION
    Displays the latest system shutdown events from the System event log.
    Shows event details including timestamp and shutdown reason messages.
#>

# CONFIGURATION
$maxEvents = 5

Get-WinEvent -FilterHashtable @{
    LogName = 'System'
    ID      = 1074
} -MaxEvents $maxEvents |
Format-List TimeCreated, Message