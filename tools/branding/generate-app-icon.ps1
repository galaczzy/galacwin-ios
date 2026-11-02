# Generates GalacWin's original, geometric iOS icon. No upstream artwork used.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$target = Join-Path $PSScriptRoot '../../app/Madeira/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png'
$bitmap = [System.Drawing.Bitmap]::new(1024, 1024, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.Clear([System.Drawing.Color]::FromArgb(10, 19, 38))

$aqua = [System.Drawing.Color]::FromArgb(91, 224, 218)
$deepAqua = [System.Drawing.Color]::FromArgb(26, 93, 112)
$cream = [System.Drawing.Color]::FromArgb(242, 248, 241)
$amber = [System.Drawing.Color]::FromArgb(255, 183, 102)
$orbitBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(17, 42, 65))
$aquaBrush = [System.Drawing.SolidBrush]::new($aqua)
$creamBrush = [System.Drawing.SolidBrush]::new($cream)
$amberBrush = [System.Drawing.SolidBrush]::new($amber)
$outerPen = [System.Drawing.Pen]::new($deepAqua, 22)
$innerPen = [System.Drawing.Pen]::new($aqua, 20)
$pathPen = [System.Drawing.Pen]::new($cream, 24)

try {
    $graphics.FillEllipse($orbitBrush, 145, 145, 734, 734)
    $graphics.DrawEllipse($outerPen, 145, 145, 734, 734)
    $graphics.DrawEllipse($innerPen, 260, 260, 504, 504)
    $graphics.DrawLine($pathPen, 221, 654, 799, 370)
    $graphics.FillEllipse($aquaBrush, 208, 641, 62, 62)
    $graphics.FillEllipse($amberBrush, 767, 337, 64, 64)
    $graphics.FillEllipse($creamBrush, 456, 456, 112, 112)
    $graphics.FillEllipse($aquaBrush, 492, 492, 40, 40)
    $graphics.FillEllipse($amberBrush, 722, 656, 22, 22)
    $graphics.FillEllipse($aquaBrush, 302, 282, 18, 18)
    $bitmap.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
}
finally {
    $pathPen.Dispose(); $innerPen.Dispose(); $outerPen.Dispose()
    $amberBrush.Dispose(); $creamBrush.Dispose(); $aquaBrush.Dispose(); $orbitBrush.Dispose()
    $graphics.Dispose(); $bitmap.Dispose()
}
