<#
.SYNOPSIS
    Maps the Q: drive to the shared Business QuickBooks folder.
.DESCRIPTION
    Creates a persistent Q: file-system drive mapped to the configured network
    share using the credentials defined in the script. Run in the user context
    that should access the mapped drive.
#>

New-PSDrive -Name "Q" -PSProvider "FileSystem" -Root "\\192.168.126.152\Business Quickbooks" -Persist -Credential (New-Object PSCredential ("Domain\username", (ConvertTo-SecureString "supersecurepassword" -AsPlainText -Force)))