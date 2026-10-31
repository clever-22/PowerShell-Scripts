<#
.SYNOPSIS
    Creates a local administrator account.
.DESCRIPTION
    Creates the configured local user with a secure string password and adds the
    user to the local Administrators group.
#>

# Variables
$username = "Local-Admin"
$passwordPlain = "Put-Something-Here-That-Is-Hopefully-Secure" # CHANGE THIS!  
$securePassword = ConvertTo-SecureString $passwordPlain -AsPlainText -Force

# Create the local user
New-LocalUser `
    -Name $username `
    -Password $securePassword `
    -FullName "Admin Account" `
    -Description "Local administrator account" `
    -PasswordNeverExpires

# Add user to local Administrators group
Add-LocalGroupMember `
    -Group "Administrators" `
    -Member $username

Write-Host "Local admin account '$username' created and added to Administrators."