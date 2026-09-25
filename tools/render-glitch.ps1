param([string]$OutDir)
# Erzeugt Beispielbilder des Grafikfehler-Modus mit der ECHTEN Effekt-Funktion (KsFx.LiveArtifacts3 aus Bildschirm.ps1),
# aber auf einem selbst gemalten Beispiel-Desktop. Es wird kein echter Bildschirm aufgenommen und nichts angezeigt.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force $OutDir | Out-Null
$s = [IO.File]::ReadAllText('C:\ProgramData\Kindersperre\Bildschirm.ps1', [Text.Encoding]::UTF8)
$i = $s.IndexOf('public static class KsFx'); $a = $s.LastIndexOf("@'", $i); $b = $s.IndexOf("'@", $i)
Add-Type -TypeDefinition $s.Substring($a + 2, $b - ($a + 2)) -ReferencedAssemblies System.Drawing
$W = 1280; $H = 720

# ---- Beispiel-Desktop malen ----
$bmp = New-Object Drawing.Bitmap($W, $H)
$g = [Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'ClearTypeGridFit'
$grad = New-Object Drawing.Drawing2D.LinearGradientBrush((New-Object Drawing.Rectangle(0, 0, $W, $H)), [Drawing.Color]::FromArgb(20, 60, 120), [Drawing.Color]::FromArgb(10, 140, 150), 45.0)
$g.FillRectangle($grad, 0, 0, $W, $H)
$fSm = New-Object Drawing.Font('Segoe UI', 10); $fMd = New-Object Drawing.Font('Segoe UI', 13, [Drawing.FontStyle]::Bold); $fBig = New-Object Drawing.Font('Segoe UI', 26, [Drawing.FontStyle]::Bold)
$white = [Drawing.Brushes]::White
# Symbole links
$k = 0
foreach ($nm in 'Games', 'Music', 'Photos', 'Notes') {
    $y = 24 + $k * 96
    $g.FillRectangle((New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(230, 245, 245, 245))), 26, $y, 48, 48)
    $g.FillEllipse((New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(255, 230, 120, 40 + $k * 40))), 36, ($y + 10), 28, 28)
    $g.DrawString($nm, $fSm, $white, 22, ($y + 52))
    $k++
}
# Fenster 1: Beispiel-Spiel
$g.FillRectangle((New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(255, 34, 38, 52))), 150, 60, 640, 420)
$g.FillRectangle((New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(255, 60, 70, 100))), 150, 60, 640, 30)
$g.DrawString('Example Game', $fSm, $white, 160, 66)
$g.FillEllipse((New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(255, 70, 160, 90))), 210, 150, 200, 200)
$g.FillRectangle((New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(255, 200, 60, 60))), 470, 190, 240, 90)
$g.FillRectangle((New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(255, 240, 200, 60))), 470, 300, 160, 120)
$g.FillRectangle((New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(255, 20, 20, 28))), 170, 108, 220, 22)
$g.FillRectangle((New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(255, 60, 200, 80))), 172, 110, 150, 18)
$g.DrawString('HP 72', $fSm, $white, 400, 108)
$g.DrawString('LEVEL 12', $fBig, $white, 470, 90)
# Fenster 2: Text
$g.FillRectangle((New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(255, 250, 250, 250))), 560, 250, 620, 330)
$g.FillRectangle((New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(255, 40, 110, 200))), 560, 250, 620, 30)
$g.DrawString('Notes - example.txt', $fSm, $white, 570, 256)
for ($r = 0; $r -lt 9; $r++) { $g.DrawString(('Example line {0}: the quick brown fox jumps over the lazy dog' -f ($r + 1)), $fMd, [Drawing.Brushes]::Black, 580, (296 + $r * 30)) }
# Taskleiste
$g.FillRectangle((New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(255, 18, 20, 28))), 0, ($H - 44), $W, 44)
$g.FillRectangle((New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(255, 40, 110, 200))), 0, ($H - 44), 52, 44)
foreach ($x in 70, 120, 170, 220) { $g.FillRectangle((New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(255, 90, 100, 130))), $x, ($H - 36), 36, 28) }
$g.DrawString('12:00', $fSm, $white, ($W - 60), ($H - 32))
$g.Dispose()
$bmp.Save((Join-Path $OutDir 'glitch-0-normal.png'), [Drawing.Imaging.ImageFormat]::Png)

# ---- Effekt anwenden (wie in Bildschirm.ps1: Art-Ebene, Magenta = durchsichtig) ----
$cap = [KsFx]::ToInts($bmp)
$variants = @(
    @{ n = 'glitch-1-anfang.png'; seed = 41; growth = 0; power = 30 },
    @{ n = 'glitch-2-mittel.png'; seed = 42; growth = 3; power = 65 },
    @{ n = 'glitch-3-voll.png';   seed = 43; growth = 6; power = 100 },
    @{ n = 'glitch-4-spaet.png';  seed = 44; growth = 12; power = 100 })
foreach ($v in $variants) {
    $art = [KsFx]::LiveArtifacts3($cap, $W, $H, $v.seed, ($W * 17 + $H), $v.growth, $v.power)
    $ia = New-Object Drawing.Imaging.ImageAttributes
    $ia.SetColorKey([Drawing.Color]::FromArgb(255, 0, 255), [Drawing.Color]::FromArgb(255, 0, 255))
    $out = New-Object Drawing.Bitmap($W, $H)
    $go = [Drawing.Graphics]::FromImage($out)
    $go.DrawImageUnscaled($bmp, 0, 0)
    $go.DrawImage($art, (New-Object Drawing.Rectangle(0, 0, $W, $H)), 0, 0, $W, $H, [Drawing.GraphicsUnit]::Pixel, $ia)
    $go.Dispose()
    $out.Save((Join-Path $OutDir $v.n), [Drawing.Imaging.ImageFormat]::Png)
    $out.Dispose(); $art.Dispose()
}
$bmp.Dispose()
'Beispielbilder erzeugt: ' + (Get-ChildItem $OutDir -Filter 'glitch-*.png').Count
