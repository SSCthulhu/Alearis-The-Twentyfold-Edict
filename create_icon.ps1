# PowerShell script to convert PNG to multi-size ICO
# Usage: Run this script in PowerShell

$inputPng = "F:\Game Development\Aleatoris The Twentyfold Edict\assets\icon_optimized.png"
$outputIco = "F:\Game Development\Aleatoris The Twentyfold Edict\icon.ico"

Write-Host "Converting PNG to ICO with multiple sizes..." -ForegroundColor Cyan

# Load System.Drawing assembly
Add-Type -AssemblyName System.Drawing

# Load the source image
$sourceImage = [System.Drawing.Image]::FromFile($inputPng)

# Create a new icon with multiple sizes
$sizes = @(256, 128, 64, 48, 32, 16)
$iconStream = New-Object System.IO.MemoryStream

# Create ICO header
$iconDir = [byte[]]::new(6)
$iconDir[0] = 0  # Reserved
$iconDir[1] = 0  # Reserved
$iconDir[2] = 1  # Type: 1 = ICO
$iconDir[3] = 0  # Type
$iconDir[4] = $sizes.Length  # Number of images
$iconDir[5] = 0

$iconStream.Write($iconDir, 0, 6)

$imageDataOffset = 6 + (16 * $sizes.Length)
$imageDataList = @()

foreach ($size in $sizes) {
    Write-Host "  Creating ${size}x${size} icon..." -ForegroundColor Gray
    
    # Resize image
    $bitmap = New-Object System.Drawing.Bitmap($size, $size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.DrawImage($sourceImage, 0, 0, $size, $size)
    $graphics.Dispose()
    
    # Save to PNG in memory
    $pngStream = New-Object System.IO.MemoryStream
    $bitmap.Save($pngStream, [System.Drawing.Imaging.ImageFormat]::Png)
    $pngData = $pngStream.ToArray()
    $pngStream.Dispose()
    $bitmap.Dispose()
    
    # Write icon directory entry
    $entry = [byte[]]::new(16)
    $entry[0] = if ($size -eq 256) { 0 } else { $size }  # Width (0 means 256)
    $entry[1] = if ($size -eq 256) { 0 } else { $size }  # Height (0 means 256)
    $entry[2] = 0  # Color palette
    $entry[3] = 0  # Reserved
    $entry[4] = 1  # Color planes
    $entry[5] = 0
    $entry[6] = 32  # Bits per pixel
    $entry[7] = 0
    [BitConverter]::GetBytes($pngData.Length).CopyTo($entry, 8)  # Data size
    [BitConverter]::GetBytes($imageDataOffset).CopyTo($entry, 12)  # Data offset
    
    $iconStream.Write($entry, 0, 16)
    
    $imageDataList += $pngData
    $imageDataOffset += $pngData.Length
}

# Write all image data
foreach ($imageData in $imageDataList) {
    $iconStream.Write($imageData, 0, $imageData.Length)
}

# Save to file
[System.IO.File]::WriteAllBytes($outputIco, $iconStream.ToArray())
$iconStream.Dispose()
$sourceImage.Dispose()

Write-Host "`nIcon created successfully!" -ForegroundColor Green
Write-Host "Location: $outputIco" -ForegroundColor Yellow
Write-Host "`nYou can now use this icon.ico file in Godot." -ForegroundColor Cyan
