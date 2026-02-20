<#
.SYNOPSIS
    Captures a screenshot and uploads it to ntfy.sh
.DESCRIPTION
    Takes a screenshot of all monitors and saves it to C:\temp\screenshot.png,
    then sends it to the configured ntfy.sh topic.
    Good for updating Zoom/Teams to make sure they aren't already in a meeting.
#>

# CONFIGURATION - CHANGE THIS!!!
$ntfyTopic = "Insertyourtopicnamehere"
$ntfyServer = "https://ntfy.sh"

# Load the necessary .NET assemblies
Add-Type -AssemblyName System.Drawing, System.Windows.Forms

# Define the output file path
$outputDir  = "C:\temp"
$outputFile = "$outputDir\screenshot.png"

# Ensure the output directory exists
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

# Get the screen dimensions (virtual screen supports multi-monitor setups)
$screen = [System.Windows.Forms.SystemInformation]::VirtualScreen
$width  = $screen.Width
$height = $screen.Height

# Create a new bitmap object with the screen dimensions
$bitmap = New-Object System.Drawing.Bitmap($width, $height)

# Create a Graphics object from the bitmap
$graphic = [System.Drawing.Graphics]::FromImage($bitmap)

# Copy the entire screen to the bitmap
$graphic.CopyFromScreen($screen.Left, $screen.Top, 0, 0, $bitmap.Size)

# Save the bitmap to a file
$bitmap.Save($outputFile)

Write-Host "Screenshot saved to: $outputFile"

# Clean up objects
$graphic.Dispose()
$bitmap.Dispose()

# Send the screenshot via curl to ntfy.sh
Write-Host "Sending screenshot to ntfy.sh..."
curl.exe `
    --data-binary "@$outputFile" `
    -H "Content-Type: image/png" `
    -H "Filename: screenshot.png" `
    -H "Title: $env:COMPUTERNAME" `
    "$ntfyServer/$ntfyTopic"

if ($LASTEXITCODE -eq 0) {
    Remove-Item -Path $outputFile -Force
    Write-Host "Screenshot sent and deleted successfully!"
} else {
    Write-Host "Upload may have failed (exit code $LASTEXITCODE) — file kept at $outputFile"
}