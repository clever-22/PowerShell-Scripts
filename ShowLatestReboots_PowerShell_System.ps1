<#
.SYNOPSIS
    Shows the 10 most recent system startup and shutdown events
.DESCRIPTION
    Displays boot, clean shutdown, and unexpected shutdown events from the System event log.
    Shows the most recent 10 events with timestamps and event types.
#>

# CONFIGURATION
$maxEventsToCheck = 30
$maxEventsToShow  = 10

$eventIDs = @(
    6005, # Startup
    6006, # Clean shutdown
    6008  # Unexpected shutdown
)

Get-WinEvent -FilterHashtable @{
    LogName = 'System'
    ID      = $eventIDs
} -MaxEvents $maxEventsToCheck |
Sort-Object TimeCreated -Descending |
Select-Object @{N='When';E={$_.TimeCreated}},
              @{N='Type';E={
                  switch ($_.Id) {
                      6005 { 'Startup' }
                      6006 { 'Shutdown (clean)' }
                      6008 { 'Shutdown (unexpected)' }
                  }
              }} |
Select-Object -First $maxEventsToShow