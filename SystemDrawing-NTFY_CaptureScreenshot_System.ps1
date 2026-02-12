<#
.SYNOPSIS
    Captures a screenshot and uploads it to ntfy.sh
.DESCRIPTION
    Takes a screenshot of all monitors and saves it to C:\temp\screenshot.png,
    then sends it to the configured ntfy.sh topic.
    Good for updating Zoom/Team to make sure they aren't already in a meeting.
#>

# CONFIGURATION
$ntfyTopic = "Insertyourtopicnamehere"
$ntfyServer = "https://ntfy.sh"

# Load the necessary .NET assemblies
Add-Type -AssemblyName System.Drawing, System.Windows.Forms

# Define the output file path
$outputFile = "C:\temp\screenshot.png"

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
curl.exe -T $outputFile `
    -H "Filename: screenshot.png" `
    -H "Title: $env:COMPUTERNAME" `
    "$ntfyServer/$ntfyTopic" 


Write-Host "Screenshot sent successfully!"
