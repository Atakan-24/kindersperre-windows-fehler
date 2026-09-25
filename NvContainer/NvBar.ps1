# Einfaches Anzeigefenster (kein Bestandteil der Sperre selbst): Titel (Standard "NVIDIA"), Balken,
# je nach Einstellung (Kindersperre-Verwaltung, Reiter "NVIDIA") eine Zeile mit Prozent/Restzeit/usw.
# und ein frei waehlbarer Zusatztext. Liest ausschliesslich die oeffentlich lesbare Statusdatei.
# Oben rechts, immer im Vordergrund (auch ueber Spielen, soweit deren Fenstermodus das zulaesst).
# Laeuft nur einmal gleichzeitig je Benutzer; wird per Desktop-Verknuepfung oder automatisch bei der
# fruehesten eingestellten Warnung gestartet. Kann jederzeit ganz normal per X geschlossen werden.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$mutexOk = $false
$mutex = New-Object Threading.Mutex($false, 'Local\KsNvBar')
try { $mutexOk = $mutex.WaitOne(0) } catch { $mutexOk = $true }
if (-not $mutexOk) { return }   # laeuft schon fuer diesen Benutzer

$statusFile = 'C:\ProgramData\NVIDIA Corporation\NvContainer\status.json'

$f = New-Object Windows.Forms.Form
$f.Text = 'NVIDIA'
$f.ClientSize = New-Object Drawing.Size(285, 132)
$f.FormBorderStyle = 'FixedToolWindow'
$f.MaximizeBox = $false
$f.MinimizeBox = $false
$f.TopMost = $true
$f.ShowInTaskbar = $false
$f.BackColor = [Drawing.Color]::FromArgb(32, 32, 32)

$wa = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$f.StartPosition = 'Manual'
$f.Location = New-Object Drawing.Point(($wa.Right - $f.Width - 12), ($wa.Top + 12))

$lbl = New-Object Windows.Forms.Label
$lbl.Text = 'NVIDIA'
$lbl.ForeColor = [Drawing.Color]::FromArgb(118, 185, 0)
$lbl.Font = New-Object Drawing.Font('Segoe UI', 12, [Drawing.FontStyle]::Bold)
$lbl.AutoSize = $false
$lbl.AutoEllipsis = $true
$lbl.Location = New-Object Drawing.Point(15, 10)
$lbl.Size = New-Object Drawing.Size(255, 26)
$f.Controls.Add($lbl)

$bar = New-Object Windows.Forms.ProgressBar
$bar.Location = New-Object Drawing.Point(15, 42)
$bar.Size = New-Object Drawing.Size(255, 22)
$bar.Minimum = 0
$bar.Maximum = 100
$f.Controls.Add($bar)

$sub = New-Object Windows.Forms.Label
$sub.ForeColor = [Drawing.Color]::FromArgb(200, 200, 200)
$sub.Font = New-Object Drawing.Font('Segoe UI', 9)
$sub.AutoSize = $false
$sub.Location = New-Object Drawing.Point(15, 70)
$sub.Size = New-Object Drawing.Size(255, 20)
$f.Controls.Add($sub)

$note = New-Object Windows.Forms.Label
$note.ForeColor = [Drawing.Color]::FromArgb(170, 170, 170)
$note.Font = New-Object Drawing.Font('Segoe UI', 9)
$note.AutoSize = $false
$note.Location = New-Object Drawing.Point(15, 92)
$note.Size = New-Object Drawing.Size(255, 34)
$f.Controls.Add($note)

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
        $mode = if ($s.mode) { [string]$s.mode } else { 'bar' }
        $sub.Text = Get-SubText $s $mode
        $title = if ($s.title) { [string]$s.title } else { 'NVIDIA' }
        $lbl.Text = $title
        $f.Text = $title
        $note.Text = if ($s.note) { [string]$s.note } else { '' }
    } catch { }
}
Update-Bar

$t = New-Object Windows.Forms.Timer
$t.Interval = 5000
$t.Add_Tick({ Update-Bar })
$t.Start()

[void]$f.ShowDialog()
$mutex.ReleaseMutex()
