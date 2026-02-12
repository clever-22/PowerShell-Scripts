<#
.SYNOPSIS
   Checks the Windows Installer folder for MSP files and orphaned packages
.DESCRIPTION
    Scans C:\Windows\Installer directory, identifies MSP patch files, reports their status,
    size, and product information. Highlights potentially Safe to Move orphaned files.
#>

$Installer = New-Object -ComObject WindowsInstaller.Installer
$Path = "C:\Windows\Installer"
$Results = New-Object System.Collections.Generic.List[PSCustomObject]
Write-Host "Scanning $Path... This may take a minute." -ForegroundColor Cyan
Get-ChildItem -Path $Path -Filter *.msp | ForEach-Object {
    $FilePath = $_.FullName
    try {
        $SummaryInfo = $Installer.SummaryInformation($FilePath, 0)
        $ProductName = $SummaryInfo.Property(3)
        $Status = "Active"
    } catch {
        $ProductName = "Orphaned / Unknown"
        $Status = "Safe to Move?"
    }
    $Results.Add([PSCustomObject]@{
        FileName    = $_.Name
        Status      = $Status
        SizeMB      = [math]::Round($_.Length / 1MB, 2)
        ProductName = $ProductName
    })
}
# Display results in the terminal
$Results | Sort-Object SizeMB -Descending | Format-Table -AutoSize
# Summary bit
$TotalSize = ($Results | Measure-Object -Property SizeMB -Sum).Sum / 1024
$OrphanedSize = ($Results | Where-Object { $_.Status -eq "Safe to Move?" } | Measure-Object -Property SizeMB -Sum).Sum / 1024
Write-Host "`n--- SUMMARY ---" -ForegroundColor Yellow
Write-Host "Total Installer Folder Size: $([math]::Round($TotalSize, 2)) GB"
Write-Host "Total Orphaned (Potential Savings): $([math]::Round($OrphanedSize, 2)) GB" -ForegroundColor Green