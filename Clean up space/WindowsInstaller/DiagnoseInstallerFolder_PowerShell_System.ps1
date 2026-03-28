<#
.SYNOPSIS
   Checks the Windows Installer folder for ALL installer files and orphaned packages
.DESCRIPTION
    Scans C:\Windows\Installer directory, identifies MSI, MSP, and other installer files,
    reports their status, size, and product information. Highlights potentially Safe to Move orphaned files.
    Exports results to C:\Temp as a CSV file.
#>

$Installer = New-Object -ComObject WindowsInstaller.Installer
$Path = "C:\Windows\Installer"
$Results = New-Object System.Collections.Generic.List[PSCustomObject]
$CsvPath = "C:\Temp\InstallerScan_$(Get-Date -Format 'yyyy-MM-dd_HHmm').csv"

if (-not (Test-Path "C:\Temp")) { New-Item -Path "C:\Temp" -ItemType Directory | Out-Null }

Write-Host "Scanning $Path... This may take a minute." -ForegroundColor Cyan

Get-ChildItem -Path $Path -File | ForEach-Object {
    $FilePath = $_.FullName
    $Extension = $_.Extension.ToLower()
    $ProductName = "N/A"
    $Status = "Unknown"

    try {
        switch ($Extension) {
            ".msi" {
                $DB = $Installer.OpenDatabase($FilePath, 0)
                $View = $DB.OpenView("SELECT Value FROM Property WHERE Property='ProductName'")
                $View.Execute()
                $Record = $View.Fetch()
                $ProductName = if ($Record) { $Record.StringData(1) } else { "Unknown MSI" }
                $Status = "Active"
            }
            ".msp" {
                $SummaryInfo = $Installer.SummaryInformation($FilePath, 0)
                $ProductName = $SummaryInfo.Property(3)
                $Status = "Active"
            }
            default {
                $ProductName = "Non-Installer File"
                $Status = "Review"
            }
        }
    } catch {
        $ProductName = "Orphaned / Unknown"
        $Status = "Safe to Move?"
    }

    $Results.Add([PSCustomObject]@{
        FileName    = $_.Name
        Extension   = $Extension
        Status      = $Status
        SizeMB      = [math]::Round($_.Length / 1MB, 2)
        ProductName = $ProductName
    })
}

# Display results in the terminal
$Results | Sort-Object SizeMB -Descending | Format-Table -AutoSize

# Export to CSV
$Results | Sort-Object SizeMB -Descending | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
Write-Host "CSV saved to: $CsvPath" -ForegroundColor Cyan

# Summary bit
$TotalSize = ($Results | Measure-Object -Property SizeMB -Sum).Sum / 1024
$OrphanedSize = ($Results | Where-Object { $_.Status -eq "Safe to Move?" } | Measure-Object -Property SizeMB -Sum).Sum / 1024

Write-Host "`n--- SUMMARY ---" -ForegroundColor Yellow
Write-Host "Total Installer Folder Size: $([math]::Round($TotalSize, 2)) GB"
Write-Host "Total Orphaned (Potential Savings): $([math]::Round($OrphanedSize, 2)) GB" -ForegroundColor Green