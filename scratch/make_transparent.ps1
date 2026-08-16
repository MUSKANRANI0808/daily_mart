Add-Type -AssemblyName System.Drawing
$imgPath = 'D:\project\daily_mart\assets\images\VERIFIDE.png'
$img = [System.Drawing.Image]::FromFile($imgPath)
$bmp = New-Object System.Drawing.Bitmap($img)
$img.Dispose()

for ($x = 0; $x -lt $bmp.Width; $x++) {
    for ($y = 0; $y -lt $bmp.Height; $y++) {
        $c = $bmp.GetPixel($x, $y)
        if ($c.R -ge 230 -and $c.G -ge 230 -and $c.B -ge 230) {
            $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, $c.R, $c.G, $c.B))
        }
    }
}

$bmp.Save('D:\project\daily_mart\assets\images\VERIFIDE.png', [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "VERIFIDE.png background converted to 100% transparent!"
