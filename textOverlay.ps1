function Add-TextToImage {
   
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$InputImagePath,
        [Parameter(Mandatory=$true)]
        [string]$OutputImagePath,
        [Parameter(Mandatory=$true)]
        [string]$Text,
        [string]$FontName = "Segoe UI",
        [int]$FontSize = 33,
        [string]$FontStyle = "Bold",
        [string]$TextColor = "White",
        [ValidateSet("Left","Center","Right")]
        [string]$HorizontalAlign = "Center",
        [int]$YOffset = 50
    )

    Add-Type -AssemblyName System.Drawing

    $graphics = $null
    $bitmap = $null
    $originalImage = $null
    $brush = $null
    $font = $null
    try {
        $originalImage = [System.Drawing.Image]::FromFile($InputImagePath)
        $bitmap = New-Object System.Drawing.Bitmap($originalImage.Width, $originalImage.Height, $originalImage.PixelFormat)
        $bitmap.SetResolution($originalImage.HorizontalResolution, $originalImage.VerticalResolution)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
        $graphics.DrawImage($originalImage, 0, 0, $originalImage.Width, $originalImage.Height)

        $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::$TextColor)
        $fontStyleEnum = [System.Drawing.FontStyle]::$FontStyle
        $font = New-Object System.Drawing.Font($FontName, $FontSize, $fontStyleEnum)
        $textSize = $graphics.MeasureString($Text, $font)

        switch ($HorizontalAlign) {
            "Left"   { $x = 0 }
            "Center" { $x = ($bitmap.Width - $textSize.Width) / 2 }
            "Right"  { $x = $bitmap.Width - $textSize.Width }
        }
        $y = $bitmap.Height - $textSize.Height - $YOffset

        $graphics.DrawString($Text, $font, $brush, $x, $y)

        $jpegEncoder = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
        $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
        $encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 100L)
        $bitmap.Save($OutputImagePath, $jpegEncoder, $encoderParams)
        Write-Host "Text successfully added to image!" -ForegroundColor Green
        Write-Host "Output saved as: $OutputImagePath" -ForegroundColor Green
    }
    catch {
        Write-Error "An error occurred while processing the image: $($_.Exception.Message)"
    }
    finally {
        if ($graphics) { $graphics.Dispose() }
        if ($bitmap) { $bitmap.Dispose() }
        if ($originalImage) { $originalImage.Dispose() }
        if ($brush) { $brush.Dispose() }
        if ($font) { $font.Dispose() }
    }
}

# Export the function so it can be used when dot-sourcing this file
Export-ModuleMember -Function Add-TextToImage