<#
.SYNOPSIS
    Prevents sleep while the computer is connected to AC power.
.DESCRIPTION
    Sets the plugged-in standby timeout to never and the battery standby
    timeout to 15 minutes using Windows Power Configuration.
#>

Powercfg /Change standby-timeout-ac 0 
Powercfg /Change standby-timeout-dc 15