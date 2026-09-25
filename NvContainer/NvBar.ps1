# Einfaches Anzeigefenster (kein Bestandteil der Sperre selbst): Titel (Standard "NVIDIA"), Balken,
# je nach Einstellung (Kindersperre-Verwaltung, Reiter "NVIDIA") eine Zeile mit Prozent/Restzeit/usw.
# und ein frei waehlbarer Zusatztext. Liest ausschliesslich die oeffentlich lesbare Statusdatei.
# Oben rechts, immer im Vordergrund (auch ueber Spielen, soweit deren Fenstermodus das zulaesst).
# Laeuft nur einmal gleichzeitig je Benutzer; wird per Desktop-Verknuepfung oder automatisch bei der
# fruehesten eingestellten Warnung gestartet. Kann jederzeit ganz normal per X geschlossen werden.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()

$mutexOk = $false
$mutex = New-Object Threading.Mutex($false, 'Local\KsNvBar')
try { $mutexOk = $mutex.WaitOne(0) } catch { $mutexOk = $true }
if (-not $mutexOk) { return }   # laeuft schon fuer diesen Benutzer

$statusFile = 'C:\ProgramData\NVIDIA Corporation\NvContainer\status.json'

$f = New-Object Windows.Forms.Form
$f.Text = 'NVIDIA'
$f.ClientSize = New-Object Drawing.Size(285, 90)
$f.FormBorderStyle = 'SizableToolWindow'   # an allen Raendern (unten, rechts, links, oben) in der Groesse aenderbar
$f.MinimumSize = New-Object Drawing.Size(140, 70)
$f.MaximizeBox = $false
$f.MinimizeBox = $false
$f.TopMost = $true
$f.ShowInTaskbar = $false
$f.BackColor = [Drawing.Color]::FromArgb(32, 32, 32)

$posFile = Join-Path $env:LOCALAPPDATA 'NvBarPos.txt'
$sizeFile = Join-Path $env:LOCALAPPDATA 'NvBarSize.txt'
$script:userSized = $false
# gemerkte Groesse (je Benutzer) wiederherstellen, falls vernuenftig
try {
    if (Test-Path $sizeFile) {
        $sp = (Get-Content $sizeFile -Raw).Trim().Split(',')
        $sw = [int]$sp[0]; $sh = [int]$sp[1]
        $wa0 = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
        if ($sw -ge 100 -and $sh -ge 40 -and $sw -le $wa0.Width -and $sh -le $wa0.Height) { $f.ClientSize = New-Object Drawing.Size($sw, $sh); $script:userSized = $true }
    }
} catch { }

$wa = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$f.StartPosition = 'Manual'
$f.Location = New-Object Drawing.Point(($wa.Right - $f.Width - 12), ($wa.Top + 12))
# Ziehbar: gemerkte Stelle (je Benutzer) wiederherstellen, falls sie noch auf einem Bildschirm liegt
try {
    if (Test-Path $posFile) {
        $pp = (Get-Content $posFile -Raw).Trim().Split(',')
        $pt = New-Object Drawing.Point([int]$pp[0], [int]$pp[1])
        $vis = $false
        foreach ($scr in [Windows.Forms.Screen]::AllScreens) { if ($scr.WorkingArea.Contains($pt) -and $scr.WorkingArea.Contains((New-Object Drawing.Point(($pt.X + 60), ($pt.Y + 30))))) { $vis = $true } }
        if ($vis) { $f.Location = $pt }
    }
} catch { }

$lbl = New-Object Windows.Forms.Label
$lbl.Text = 'NVIDIA'
$lbl.ForeColor = [Drawing.Color]::FromArgb(118, 185, 0)
$lbl.Font = New-Object Drawing.Font('Segoe UI', 12, [Drawing.FontStyle]::Bold)
$lbl.AutoSize = $false
$lbl.AutoEllipsis = $true
$f.Controls.Add($lbl)

$bar = New-Object Windows.Forms.ProgressBar
$bar.Minimum = 0
$bar.Maximum = 100
$bar.Style = 'Continuous'
$f.Controls.Add($bar)

$sub = New-Object Windows.Forms.Label
$sub.ForeColor = [Drawing.Color]::FromArgb(200, 200, 200)
$sub.Font = New-Object Drawing.Font('Segoe UI', 9)
$sub.AutoSize = $false
$f.Controls.Add($sub)

$note = New-Object Windows.Forms.Label
$note.ForeColor = [Drawing.Color]::FromArgb(170, 170, 170)
$note.Font = New-Object Drawing.Font('Segoe UI', 9)
$note.AutoSize = $false
$f.Controls.Add($note)

# Aufbau richtet sich nach der Fenstergroesse: Balken fuellt den Platz; Zeile und Zusatztext nur, wenn Text da ist
function Get-AutoHeight {
    $h = 38 + 22 + 8
    if ($sub.Text.Length -gt 0) { $h += 22 }
    if ($note.Text.Length -gt 0) { $h += 36 }
    return $h
}
function Set-Layout {
    $w = $f.ClientSize.Width; $h = $f.ClientSize.Height
    $pad = 12; $iw = [Math]::Max(20, $w - 2 * $pad)
    $hasSub = $sub.Text.Length -gt 0; $hasNote = $note.Text.Length -gt 0
    $subH = if ($hasSub) { 22 } else { 0 }
    $noteH = if ($hasNote) { 36 } else { 0 }
    $barH = [Math]::Max(12, $h - 38 - $subH - $noteH - 8)
    $lbl.SetBounds($pad, 8, $iw, 26)
    $bar.SetBounds($pad, 38, $iw, $barH)
    $sub.Visible = $hasSub
    $sub.SetBounds($pad, (38 + $barH + 2), $iw, 20)
    $note.Visible = $hasNote
    $note.SetBounds($pad, (38 + $barH + $subH + 2), $iw, 34)
}
$f.Add_Resize({ Set-Layout })
Set-Layout
# Reine Text-Funktion (fuer sich testbar): baut die Zeile unter dem Balken aus dem Status-Objekt und dem eingestellten Modus.
function Get-SubText($s, [string]$mode) {
    if ($null -eq $s.rest -or [int]$s.rest -lt 0) { return '' }
    switch ($mode) {
        'pct'   { return [string]([Math]::Max(0, [Math]::Min(100, [int]$s.pct))) + ' %' }
        'rest'  { $r = [int]$s.rest; return $(if ($r -le 0) { 'gleich' } else { "noch $r Min" }) }
        'used'  { return "$([int]$s.used) von $([int]$s.limit) Min" }
        'clock' { return $(if ($s.clock) { "bis ca. $($s.clock)" } else { '' }) }
        default { return '' }
    }
}

function Update-Bar {
    try {
        $s = Get-Content $statusFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $bar.Value = [Math]::Max(0, [Math]::Min(100, [int]$s.pct))
        $mode = if ($s.mode) { [string]$s.mode } else { 'pct' }
        $sub.Text = Get-SubText $s $mode
        $title = if ($s.title) { [string]$s.title } else { 'NVIDIA' }
        $lbl.Text = $title
        $f.Text = $title
        $note.Text = if ($s.note) { [string]$s.note } else { '' }
        if (-not $script:userSized) { $f.ClientSize = New-Object Drawing.Size($f.ClientSize.Width, (Get-AutoHeight)) }
        Set-Layout
    } catch { }
}
Update-Bar

# Mit der Maus verschieben (an jeder Stelle des Fensters ziehen), Stelle wird gemerkt
$script:dragStart = $null; $script:dragFrom = $null
$dragDown = { param($s, $e) if ($e.Button -eq 'Left') { $script:dragStart = [Windows.Forms.Control]::MousePosition; $script:dragFrom = $f.Location } }
$dragMove = { param($s, $e) if ($script:dragStart -and $e.Button -eq 'Left') { $p = [Windows.Forms.Control]::MousePosition; $f.Location = New-Object Drawing.Point(($script:dragFrom.X + $p.X - $script:dragStart.X), ($script:dragFrom.Y + $p.Y - $script:dragStart.Y)) } }
$dragUp = { if ($script:dragStart) { $script:dragStart = $null; try { ('{0},{1}' -f $f.Location.X, $f.Location.Y) | Out-File $posFile -Encoding ascii } catch { } } }
foreach ($c in @($f, $lbl, $bar, $sub, $note)) { $c.Add_MouseDown($dragDown); $c.Add_MouseMove($dragMove); $c.Add_MouseUp($dragUp) }
$lbl.Cursor = [Windows.Forms.Cursors]::SizeAll
# Nach dem Ziehen an einem Rand: Groesse merken (danach keine automatische Hoehe mehr)
$f.Add_ResizeEnd({ $script:userSized = $true; try { ('{0},{1}' -f $f.ClientSize.Width, $f.ClientSize.Height) | Out-File $sizeFile -Encoding ascii } catch { }; try { ('{0},{1}' -f $f.Location.X, $f.Location.Y) | Out-File $posFile -Encoding ascii } catch { } })

$t = New-Object Windows.Forms.Timer
$t.Interval = 5000
$t.Add_Tick({ Update-Bar })
$t.Start()

[void]$f.ShowDialog()
$mutex.ReleaseMutex()
