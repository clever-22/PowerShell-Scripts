<#
.SYNOPSIS
Determines if the system is running as a virtual machine.

.DESCRIPTION
Checks the WMI Win32_ComputerSystem model to detect if the computer is running virtualized.
Returns true if "Virtual" or "VMware" is detected in the system model name, indicating a virtual environment.
#>

(Get-CimInstance Win32_ComputerSystem).Model -match 'Virtual|VMware'