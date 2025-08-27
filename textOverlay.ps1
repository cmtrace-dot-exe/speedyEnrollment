############################################################################################################
### Add-TextToImage Module
### Contains functions for adding text to images
### Mike O'Leary | mikeoleary.net | @cmtrace-dot-exe
############################################################################################################

function Add-TextToImage {
    <#
    .SYNOPSIS
    Adds enrollment status text overlay to an image with the same layout as the reference image.
    
    .DESCRIPTION
    This function replicates the text layout from the enrollment status image with three text elements:
    - Top text line 1 (large, bold, centered)
    - Top text line 2 (large, bold, centered, below line 1)
    - Bottom text (smaller, centered at bottom)
    
    .PARAMETER InputImagePath
    Path to the source image file
    
    .PARAMETER OutputImagePath
    Path where the modified image will be saved
    
    .PARAMETER TopText1
    First line of top text (required)
    
    .PARAMETER TopText2
    Second line of top text (required)
    
    .PARAMETER BottomText
    Bottom text line (required)
    
    .PARAMETER TopFontSize
    Font size for top text lines (default: 85)
    
    .PARAMETER BottomFontSize
    Font size for bottom text (default: 36)
    
    .PARAMETER FontName
    Font family name (default: "Segoe UI")
    
    .PARAMETER TextColor
    Text color (default: "White")
    
    .EXAMPLE
    Add-TextToImage -InputImagePath "background.jpg" -OutputImagePath "status.jpg" -TopText1 "DO NOT USE" -TopText2 "ENROLLMENT PENDING" -BottomText "Task sequence ABC123 started at 10:30:00 08/25/2025"
    
    .EXAMPLE
    Add-TextToImage -InputImagePath "background.jpg" -OutputImagePath "status.jpg" -TopText1 "SYSTEM READY" -TopText2 "DEPLOYMENT COMPLETE" -BottomText "Task sequence completed successfully"
    #>
 
    [CmdletBinding()]

    param(
        [Parameter(Mandatory=$true)]
        [string]$InputImagePath,
        [Parameter(Mandatory=$true)]
        [string]$OutputImagePath,
        [Parameter(Mandatory=$true)]
        [string]$TopText1,
        [Parameter(Mandatory=$true)]
        [string]$TopText2, 
        [Parameter(Mandatory=$true)]
        [string]$BottomText,
        [int]$TopFontSize = 82,
        [int]$BottomFontSize = 33,
        [string]$FontName = "Segoe UI",
        [string]$TextColor = "White"
    )

    Add-Type -AssemblyName System.Drawing

    $graphics = $null
    $bitmap = $null
    $originalImage = $null
    $brush = $null
    $topFont = $null
    $bottomFont = $null
    
    try {
        # Validate input file exists
        if (-not (Test-Path $InputImagePath)) {
            throw "Input image file not found: $InputImagePath"
        }
        
        $originalImage = [System.Drawing.Image]::FromFile($InputImagePath)
        $bitmap = New-Object System.Drawing.Bitmap($originalImage.Width, $originalImage.Height, $originalImage.PixelFormat)
        $bitmap.SetResolution($originalImage.HorizontalResolution, $originalImage.VerticalResolution)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
        $graphics.DrawImage($originalImage, 0, 0, $originalImage.Width, $originalImage.Height)

        $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::$TextColor)
        $topFont = New-Object System.Drawing.Font($FontName, $TopFontSize, [System.Drawing.FontStyle]::Bold)
        $bottomFont = New-Object System.Drawing.Font($FontName, $BottomFontSize, [System.Drawing.FontStyle]::Bold)

        # Calculate positions for text elements
        $topText1Size = $graphics.MeasureString($TopText1, $topFont)
        $topText2Size = $graphics.MeasureString($TopText2, $topFont)
        $bottomTextSize = $graphics.MeasureString($BottomText, $bottomFont)

        # Position first top text line (centered horizontally, just below halfway down the image)
        $topText1X = ($bitmap.Width - $topText1Size.Width) / 2
        $topText1Y = ($bitmap.Height * 0.58) - ($topText1Size.Height + $topText2Size.Height) / 2

        # Position second top text line (centered horizontally, directly below first line)
        $topText2X = ($bitmap.Width - $topText2Size.Width) / 2
        $topText2Y = $topText1Y + $topText1Size.Height - 20 # 10px spacing between lines

        # Position bottom text (centered horizontally, moved up by about a third from original position)
        # Original was 80px from bottom, now about 53px from bottom (moved up by ~27px which is about 1/3)
        $bottomTextX = ($bitmap.Width - $bottomTextSize.Width) / 2
        $bottomTextY = $bitmap.Height - $bottomTextSize.Height - 53  # Moved up from 80px to 53px

        # Draw all text elements
        $graphics.DrawString($TopText1, $topFont, $brush, $topText1X, $topText1Y)
        $graphics.DrawString($TopText2, $topFont, $brush, $topText2X, $topText2Y)
        $graphics.DrawString($BottomText, $bottomFont, $brush, $bottomTextX, $bottomTextY)

        # Ensure output directory exists
        $outputDir = Split-Path $OutputImagePath -Parent
        if (-not (Test-Path $outputDir)) {
            New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
        }

        # Save the image
        $jpegEncoder = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
        $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
        $encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 100L)
        $bitmap.Save($OutputImagePath, $jpegEncoder, $encoderParams)
        
        Write-Host "Text successfully added to image!" -ForegroundColor Green
        Write-Host "Output saved as: $OutputImagePath" -ForegroundColor Green
    }
    catch {
        Write-Error "An error occurred while processing the image: $($_.Exception.Message)"
        throw
    }
    finally {
        if ($graphics) { $graphics.Dispose() }
        if ($bitmap) { $bitmap.Dispose() }
        if ($originalImage) { $originalImage.Dispose() }
        if ($brush) { $brush.Dispose() }
        if ($topFont) { $topFont.Dispose() }
        if ($bottomFont) { $bottomFont.Dispose() }
    }
}

# Export the function so it can be used when dot-sourcing this file
#Export-ModuleMember -Function Add-TextToImage