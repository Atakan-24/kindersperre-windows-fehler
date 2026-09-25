# Einstellungs-Fenster fuer die Kindersperre. Liegt im geschuetzten Ordner (nur SYSTEM/Administratoren),
# darum sieht es automatisch nur Verwalter - kein eigener Schutzmechanismus dafuer noetig.
# Eigenes Werkzeug-Passwort (per PBKDF2-Hash gespeichert, wie beim Betreuer-PIN), unabhaengig vom Windows-Passwort.
# Aenderungen werden SOFORT automatisch gespeichert (kurze Verzoegerung, damit nicht jeder Tastendruck speichert).
# Vor der ersten Aenderung je Sitzung wird eine Sicherung von config.json angelegt (die letzten 20 bleiben erhalten).
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$Dir      = 'C:\ProgramData\Kindersperre'
$CfgFile  = Join-Path $Dir 'config.json'
$ToolPin  = Join-Path $Dir 'tool-pin.json'
$AdjFile  = Join-Path $Dir 'adjust.txt'
$PrevDir  = Join-Path $Dir 'preview'
$NvBarFile = 'C:\ProgramData\NVIDIA Corporation\NvContainer\NvBar.ps1'

function Hash-Pin([string]$pin, [byte[]]$salt) {
    (New-Object Security.Cryptography.Rfc2898DeriveBytes($pin, $salt, 100000)).GetBytes(32)
}
function Save-ToolPin([string]$pin) {
    $salt = New-Object byte[] 16
    (New-Object Security.Cryptography.RNGCryptoServiceProvider).GetBytes($salt)
    $hash = Hash-Pin $pin $salt
    @{ salt = [Convert]::ToBase64String($salt); hash = [Convert]::ToBase64String($hash) } | ConvertTo-Json -Compress | Out-File $ToolPin -Encoding ascii
}
function Test-ToolPin([string]$pin) {
    try {
        $p = Get-Content $ToolPin -Raw | ConvertFrom-Json
        $salt = [Convert]::FromBase64String($p.salt)
        $h = Hash-Pin $pin $salt
        return ([Convert]::ToBase64String($h) -eq $p.hash)
    } catch { return $false }
}

# ---- Passwort-Abfrage bzw. Erst-Einrichtung ----
function Show-PinGate {
    $script:first = -not (Test-Path $ToolPin)
    $first = $script:first
    $script:g = New-Object Windows.Forms.Form
    $g = $script:g
    $g.Font = New-Object Drawing.Font('Segoe UI', 10)
    $g.Text = if ($first) { 'Werkzeug-Passwort festlegen' } else { 'Kindersperre-Verwaltung' }
    $g.FormBorderStyle = 'FixedDialog'; $g.MaximizeBox = $false; $g.MinimizeBox = $false
    $g.StartPosition = 'CenterScreen'
    $g.ClientSize = New-Object Drawing.Size(420, $(if ($first) { 240 } else { 160 }))
    $lbl = New-Object Windows.Forms.Label
    $lbl.Text = if ($first) { "Noch kein Werkzeug-Passwort vorhanden.`nBitte eines festlegen (mind. 4 Zeichen). Es ist unabhaengig vom Windows-Passwort." } else { 'Werkzeug-Passwort eingeben:' }
    $lbl.Location = New-Object Drawing.Point(15, 12); $lbl.Size = New-Object Drawing.Size(390, 50)
    $g.Controls.Add($lbl)
    $script:t1 = New-Object Windows.Forms.TextBox
    $t1 = $script:t1
    $t1.Location = New-Object Drawing.Point(15, $(if ($first) { 70 } else { 45 })); $t1.Size = New-Object Drawing.Size(385, 26); $t1.UseSystemPasswordChar = $true
    $g.Controls.Add($t1)
    $script:t2 = $null
    if ($first) {
        $script:t2 = New-Object Windows.Forms.TextBox
        $t2 = $script:t2
        $t2.Location = New-Object Drawing.Point(15, 122); $t2.Size = New-Object Drawing.Size(385, 26); $t2.UseSystemPasswordChar = $true
        $g.Controls.Add($t2)
        $lbl2 = New-Object Windows.Forms.Label
        $lbl2.Text = 'Wiederholen:'; $lbl2.Location = New-Object Drawing.Point(15, 100); $lbl2.Size = New-Object Drawing.Size(200, 20)
        $g.Controls.Add($lbl2)
    }
    $script:err = New-Object Windows.Forms.Label
    $err = $script:err
    $err.ForeColor = [Drawing.Color]::Red; $err.Location = New-Object Drawing.Point(15, $(if ($first) { 158 } else { 78 })); $err.Size = New-Object Drawing.Size(385, 24)
    $g.Controls.Add($err)
    $btn = New-Object Windows.Forms.Button
    $btn.Text = if ($first) { 'Festlegen' } else { 'OK' }
    $btn.Location = New-Object Drawing.Point(155, $(if ($first) { 190 } else { 108 })); $btn.Size = New-Object Drawing.Size(110, 34)
    $g.Controls.Add($btn)
    $g.AcceptButton = $btn
    $script:ok = $false
    $script:GateAction = {
        if ($first) {
            if ($t1.Text.Length -lt 4) { $err.Text = 'Mindestens 4 Zeichen.'; return }
            if ($t1.Text -ne $t2.Text) { $err.Text = 'Stimmt nicht ueberein.'; return }
            Save-ToolPin $t1.Text
            $script:ok = $true; if ($g.Visible) { $g.Close() }
        } else {
            if (Test-ToolPin $t1.Text) { $script:ok = $true; if ($g.Visible) { $g.Close() } }
            else { $err.Text = 'Falsches Passwort.'; $t1.Text = '' }
        }
    }
    $btn.Add_Click($script:GateAction)
    [void]$g.ShowDialog()
    return $script:ok
}

if (-not (Show-PinGate)) { return }

# ---- Hauptfenster ----
function Read-Cfg { Get-Content $CfgFile -Raw | ConvertFrom-Json }
# Eigenschaft setzen, auch wenn sie in config.json noch gar nicht vorkommt (sonst Fehler "Eigenschaft nicht gefunden")
function Set-Prop($o, [string]$name, $value) {
    if ($o.PSObject.Properties[$name]) { $o.$name = $value } else { $o | Add-Member -NotePropertyName $name -NotePropertyValue $value -Force }
}
$cfg = Read-Cfg
$script:backedUp = $false
$script:savePending = $false
$DefRep1 = 'Automatische Reparatur wird vorbereitet'
$DefRep2 = 'Diagnose des PCs wird ausgef' + [char]0xFC + 'hrt'

# Text-Funktion der NVIDIA-Anzeige aus NvBar.ps1 uebernehmen, damit Vorschau und echte Anzeige immer gleich rechnen
try {
    $nvAst = [Management.Automation.Language.Parser]::ParseFile($NvBarFile, [ref]$null, [ref]$null)
    $nvFn = $nvAst.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Get-SubText' }, $true)
    . ([scriptblock]::Create($nvFn.Extent.Text))
} catch { function Get-SubText($s, [string]$mode) { return '' } }

$f = New-Object Windows.Forms.Form
$f.Text = 'Kindersperre-Verwaltung'
$f.Font = New-Object Drawing.Font('Segoe UI', 10)
$f.FormBorderStyle = 'FixedDialog'; $f.MaximizeBox = $false
$f.StartPosition = 'CenterScreen'
$f.ClientSize = New-Object Drawing.Size(660, 660)

$tabs = New-Object Windows.Forms.TabControl
$tabs.Location = New-Object Drawing.Point(8, 8); $tabs.Size = New-Object Drawing.Size(644, 592)
$tabs.Multiline = $true
$f.Controls.Add($tabs)

function New-Tab($title) { $p = New-Object Windows.Forms.TabPage; $p.Text = $title; $tabs.TabPages.Add($p); return $p }
function New-Lbl($parent, $text, $x, $y, $w = 580, $h = 24) {
    $l = New-Object Windows.Forms.Label; $l.Text = $text; $l.Location = New-Object Drawing.Point($x, $y); $l.Size = New-Object Drawing.Size($w, $h); $parent.Controls.Add($l); return $l
}
function New-Num($parent, $label, $x, $y, $val, $min = 0, $max = 1440) {
    [void](New-Lbl $parent $label $x ($y + 3) 350 24)
    $n = New-Object Windows.Forms.NumericUpDown; $n.Location = New-Object Drawing.Point(($x + 360), $y); $n.Size = New-Object Drawing.Size(110, 28)
    $n.Minimum = $min; $n.Maximum = $max; $n.Value = [Math]::Max($min, [Math]::Min($max, [int]$val)); $parent.Controls.Add($n)
    return $n
}
function New-Chk($parent, $label, $x, $y, $checked) {
    $c = New-Object Windows.Forms.CheckBox; $c.Text = $label; $c.Location = New-Object Drawing.Point($x, $y); $c.Size = New-Object Drawing.Size(590, 26); $c.Checked = [bool]$checked
    $parent.Controls.Add($c); return $c
}
function New-Txt($parent, $x, $y, $w, $text, $max = 60) {
    $t = New-Object Windows.Forms.TextBox; $t.Location = New-Object Drawing.Point($x, $y); $t.Size = New-Object Drawing.Size($w, 28); $t.MaxLength = $max; $t.Text = [string]$text
    $parent.Controls.Add($t); return $t
}
function New-Btn($parent, $text, $x, $y, $w, $h = 36) {
    $b = New-Object Windows.Forms.Button; $b.Text = $text; $b.Location = New-Object Drawing.Point($x, $y); $b.Size = New-Object Drawing.Size($w, $h); $parent.Controls.Add($b); return $b
}

# ===== Tab: Limits =====
$tLim = New-Tab 'Limits'
$nWd   = New-Num $tLim 'Wochentag-Limit (Min)'        20  20 $cfg.WeekdayLimitMin 30 1000
$nWe   = New-Num $tLim 'Wochenende-Limit (Min)'       20  60 $cfg.WeekendLimitMin 30 1000
$nGr   = New-Num $tLim 'Nachspielzeit (Min)'          20 100 $cfg.GraceMin 0 120
$nBo   = New-Num $tLim 'Bonus per PIN (Min)'          20 140 $cfg.BonusMin 0 240
$nRs   = New-Num $tLim 'Reset-Uhrzeit (Std)'          20 180 $cfg.ResetHour 0 23
$nIdle = New-Num $tLim 'Leerlauf zaehlt nicht ab (Min)' 20 220 $(if ($cfg.IdleMin) { $cfg.IdleMin } else { 5 }) 1 60
$cEn   = New-Chk $tLim 'Sperre aktiv (aus = kein Limit, keine Sperre, keine Warnung)' 20 268 ($cfg.Enabled -ne $false)
[void](New-Lbl $tLim 'Heute sofort anpassen:' 20 326 220 24)
$nAdj = New-Object Windows.Forms.NumericUpDown; $nAdj.Location = New-Object Drawing.Point(240, 322); $nAdj.Size = New-Object Drawing.Size(90, 28); $nAdj.Minimum = -300; $nAdj.Maximum = 300; $tLim.Controls.Add($nAdj)
$bAdjMore = New-Btn $tLim '+ Mehr Zeit' 345 320 130 34
$bAdjLess = New-Btn $tLim '- Weniger Zeit' 485 320 130 34
[void](New-Lbl $tLim 'Mehr Zeit gibt die Minuten dazu, Weniger Zeit nimmt welche weg. Wirkt spaetestens in 1 Minute.' 20 366 590 48)
# adjust.txt = Minuten, die zum Tageszaehler ADDIERT werden: negativ = MEHR Zeit uebrig, positiv = WENIGER Zeit uebrig
$script:AdjMoreAction = { (-1.0 * [double]$nAdj.Value) | Out-File $AdjFile -Encoding ascii; $lStatus.ForeColor = [Drawing.Color]::DarkGreen; $lStatus.Text = ('{0} Minuten MEHR Zeit heute (wirkt spaetestens in 1 Min).' -f [double]$nAdj.Value) }
$script:AdjLessAction = { [double]$nAdj.Value | Out-File $AdjFile -Encoding ascii; $lStatus.ForeColor = [Drawing.Color]::DarkGreen; $lStatus.Text = ('{0} Minuten WENIGER Zeit heute (wirkt spaetestens in 1 Min).' -f [double]$nAdj.Value) }
$bAdjMore.Add_Click($script:AdjMoreAction)
$bAdjLess.Add_Click($script:AdjLessAction)

# ===== Tab: Warnungen =====
$tWarn = New-Tab 'Warnungen'
[void](New-Lbl $tWarn 'Welche Vorwarnungen sollen kommen (Minuten vor der Sperre)?' 20 15 590 26)
$cur = @(); if ($cfg.WarnMinutes) { $cur = @($cfg.WarnMinutes | ForEach-Object { [int]$_ }) } else { $cur = @(15, 1) }
$warnChecks = @{}
$y = 55
foreach ($m in 45, 30, 20, 15, 5, 1) { $warnChecks[$m] = New-Chk $tWarn "$m Minuten vorher" 20 $y ($cur -contains $m); $y += 38 }
[void](New-Lbl $tWarn 'Ist nichts angehakt, gilt automatisch nur die 1-Minuten-Warnung.' 20 ($y + 10) 590 26)

# ===== Tab: Programme =====
$tProg = New-Tab 'Programme'
$cKill = New-Chk $tProg 'Programme mit Fenster bei Sperrstart beenden' 20 20 ($cfg.KillApps -ne $false)
$cKey  = New-Chk $tProg 'Tastensperre in der Sperre (Windows-Taste, Alt+Tab usw.)' 20 60 ($cfg.KeyLock -ne $false)
$cPinG = New-Chk $tProg 'Grafikfehler-Modus nach Bonus-PIN' 20 100 ($cfg.PinGlitch -ne $false)
$nGl   = New-Num $tProg 'Grafikfehler-Stufe (1 = leicht, 3 = krass)' 20 148 $(if ($cfg.GlitchLevel) { $cfg.GlitchLevel } else { 3 }) 1 3

# ===== Tab: NVIDIA (Titel, Text, Anzeige, Vorschau) =====
$tNv = New-Tab 'NVIDIA'
[void](New-Lbl $tNv 'Titel (Standard: NVIDIA):' 20 14 220 24)
$tbTitle = New-Txt $tNv 250 11 250 $(if ($cfg.NvBarTitle) { $cfg.NvBarTitle } else { 'NVIDIA' }) 24
[void](New-Lbl $tNv 'Zusatztext (optional):' 20 52 220 24)
$tbNote = New-Txt $tNv 250 49 350 $cfg.NvBarNote 60
[void](New-Lbl $tNv 'Zeile unter dem Balken:' 20 92 300 24)
$modes = [ordered]@{
    'bar'   = 'Nur Balken'
    'pct'   = 'Balken + Prozent'
    'rest'  = 'Balken + Restzeit (z. B. "noch 47 Min")'
    'used'  = 'Balken + verbrauchte Zeit von Limit'
    'clock' = 'Balken + geschaetzte Uhrzeit der Sperre'
}
$rbGroup = @()
$y = 118
foreach ($k in $modes.Keys) {
    $rb = New-Object Windows.Forms.RadioButton; $rb.Text = $modes[$k]; $rb.Tag = $k
    $rb.Location = New-Object Drawing.Point(20, $y); $rb.Size = New-Object Drawing.Size(570, 26)
    if (($cfg.NvBarMode -eq $k) -or (-not $cfg.NvBarMode -and $k -eq 'bar')) { $rb.Checked = $true }
    $tNv.Controls.Add($rb); $rbGroup += $rb; $y += 30
}
[void](New-Lbl $tNv 'Vorschau (so sieht es aus):' 20 282 300 24)
$pvPanel = New-Object Windows.Forms.Panel; $pvPanel.Location = New-Object Drawing.Point(20, 310); $pvPanel.Size = New-Object Drawing.Size(285, 132)
$pvPanel.BackColor = [Drawing.Color]::FromArgb(32, 32, 32); $pvPanel.BorderStyle = 'FixedSingle'; $tNv.Controls.Add($pvPanel)
$pvTitle = New-Object Windows.Forms.Label; $pvTitle.Location = New-Object Drawing.Point(15, 10); $pvTitle.Size = New-Object Drawing.Size(255, 26)
$pvTitle.ForeColor = [Drawing.Color]::FromArgb(118, 185, 0); $pvTitle.Font = New-Object Drawing.Font('Segoe UI', 12, [Drawing.FontStyle]::Bold); $pvPanel.Controls.Add($pvTitle)
$pvBar = New-Object Windows.Forms.ProgressBar; $pvBar.Location = New-Object Drawing.Point(15, 42); $pvBar.Size = New-Object Drawing.Size(255, 22); $pvPanel.Controls.Add($pvBar)
$pvSub = New-Object Windows.Forms.Label; $pvSub.Location = New-Object Drawing.Point(15, 70); $pvSub.Size = New-Object Drawing.Size(255, 20)
$pvSub.ForeColor = [Drawing.Color]::FromArgb(200, 200, 200); $pvSub.Font = New-Object Drawing.Font('Segoe UI', 9); $pvPanel.Controls.Add($pvSub)
$pvNote = New-Object Windows.Forms.Label; $pvNote.Location = New-Object Drawing.Point(15, 92); $pvNote.Size = New-Object Drawing.Size(255, 34)
$pvNote.ForeColor = [Drawing.Color]::FromArgb(170, 170, 170); $pvNote.Font = New-Object Drawing.Font('Segoe UI', 9); $pvPanel.Controls.Add($pvNote)
[void](New-Lbl $tNv 'Beispielwert (verbrauchte Zeit in %):' 325 310 290 24)
$tbSample = New-Object Windows.Forms.TrackBar; $tbSample.Location = New-Object Drawing.Point(325, 336); $tbSample.Size = New-Object Drawing.Size(285, 45)
$tbSample.Minimum = 0; $tbSample.Maximum = 100; $tbSample.TickFrequency = 10; $tbSample.Value = 60; $tNv.Controls.Add($tbSample)
$bNvMe  = New-Btn $tNv 'Bei mir zeigen' 20 456 150
$bNvKid = New-Btn $tNv 'In Kindersitzung zeigen' 180 456 220

function Update-NvPreview {
    $limit = [int]$nWd.Value + [int]$nGr.Value
    $pct = [int]$tbSample.Value
    $used = [int][Math]::Round($limit * $pct / 100.0)
    $rest = [Math]::Max(0, $limit - $used)
    $s = [pscustomobject]@{ pct = $pct; rest = $rest; used = $used; limit = $limit; clock = (Get-Date).AddMinutes($rest).ToString('HH:mm') }
    $mode = ($rbGroup | Where-Object { $_.Checked } | Select-Object -First 1).Tag
    $t = $tbTitle.Text.Trim()
    $pvTitle.Text = $(if ($t) { $t } else { 'NVIDIA' })
    $pvBar.Value = $pct
    $pvSub.Text = Get-SubText $s $mode
    $pvNote.Text = $tbNote.Text
}

# ===== Tab: Fehleranzeige =====
$tErr = New-Tab 'Fehleranzeige'
$cLook    = New-Chk $tErr 'Alter Text-Look (nur Terminal) statt Windows-Absturz-Look' 20 10 ($cfg.Look -eq 'terminal')
$cEndLogo = New-Chk $tErr 'Am Ende nur das Logo zeigen (ohne Reparatur-Text)' 20 40 ($cfg.EndPhase -eq 'logo')
$cTicker  = New-Chk $tErr 'Kleine Datei-/Programmzeile unten links' 20 70 ($cfg.FileTicker -ne $false)
$cOutro   = New-Chk $tErr 'Neustart-Abschluss am Ende (Schwarz, Logo, Desktop)' 20 100 ($cfg.Outro -ne $false)
[void](New-Lbl $tErr 'Reparatur-Text 1:' 20 141 170 24)
$tbRep1 = New-Txt $tErr 200 138 405 $(if ($cfg.RepairText1) { $cfg.RepairText1 } else { $DefRep1 }) 60
[void](New-Lbl $tErr 'Reparatur-Text 2:' 20 175 170 24)
$tbRep2 = New-Txt $tErr 200 172 405 $(if ($cfg.RepairText2) { $cfg.RepairText2 } else { $DefRep2 }) 60
$pvRepPanel = New-Object Windows.Forms.Panel; $pvRepPanel.Location = New-Object Drawing.Point(20, 208); $pvRepPanel.Size = New-Object Drawing.Size(585, 66)
$pvRepPanel.BackColor = [Drawing.Color]::Black; $tErr.Controls.Add($pvRepPanel)
$pvRep1 = New-Object Windows.Forms.Label; $pvRep1.Location = New-Object Drawing.Point(0, 4); $pvRep1.Size = New-Object Drawing.Size(585, 28); $pvRep1.TextAlign = 'MiddleCenter'
$pvRep1.ForeColor = [Drawing.Color]::White; $pvRep1.Font = New-Object Drawing.Font('Segoe UI Light', 13); $pvRepPanel.Controls.Add($pvRep1)
$pvRep2 = New-Object Windows.Forms.Label; $pvRep2.Location = New-Object Drawing.Point(0, 34); $pvRep2.Size = New-Object Drawing.Size(585, 28); $pvRep2.TextAlign = 'MiddleCenter'
$pvRep2.ForeColor = [Drawing.Color]::White; $pvRep2.Font = New-Object Drawing.Font('Segoe UI Light', 13); $pvRepPanel.Controls.Add($pvRep2)
[void](New-Lbl $tErr 'Terminal-Schrift:' 20 288 170 24)
$monoAll = @('Consolas', 'Courier New', 'Lucida Console', 'Cascadia Mono', 'Cascadia Code', 'Lucida Sans Typewriter')
$installed = @([Drawing.FontFamily]::Families | ForEach-Object { $_.Name })
$monoFonts = @($monoAll | Where-Object { $installed -contains $_ })
if ($monoFonts.Count -eq 0) { $monoFonts = @('Consolas') }
$cbFont = New-Object Windows.Forms.ComboBox; $cbFont.DropDownStyle = 'DropDownList'; $cbFont.Location = New-Object Drawing.Point(200, 285); $cbFont.Size = New-Object Drawing.Size(200, 28)
foreach ($n in $monoFonts) { [void]$cbFont.Items.Add($n) }
$curFont = if ($cfg.TermFont -and ($monoFonts -contains [string]$cfg.TermFont)) { [string]$cfg.TermFont } else { $monoFonts[0] }
$cbFont.SelectedItem = $curFont
$tErr.Controls.Add($cbFont)
$pvTerm = New-Object Windows.Forms.Label; $pvTerm.Location = New-Object Drawing.Point(410, 282); $pvTerm.Size = New-Object Drawing.Size(200, 30); $pvTerm.TextAlign = 'MiddleLeft'
$pvTerm.BackColor = [Drawing.Color]::Black; $pvTerm.ForeColor = [Drawing.Color]::FromArgb(255, 70, 70); $pvTerm.Text = 'FEHLGESCHLAGEN 0xC000009A'; $tErr.Controls.Add($pvTerm)
$nScale = New-Num $tErr 'Schriftgroesse (% der automatisch passenden)' 20 320 $(if ($cfg.TermFontScale) { $cfg.TermFontScale } else { 100 }) 50 100
$nTmin  = New-Num $tErr 'Terminal erscheint fruehestens nach (Min)' 20 356 $(if ($cfg.TermMinGapSec) { [int]($cfg.TermMinGapSec / 60) } else { 8 }) 1 120
$nTmax  = New-Num $tErr 'Terminal erscheint spaetestens nach (Min)' 20 392 $(if ($cfg.TermMaxGapSec) { [int]($cfg.TermMaxGapSec / 60) } else { 14 }) 1 120
$nTdur  = New-Num $tErr 'Terminal bleibt sichtbar (Sekunden)' 20 428 $(if ($cfg.TermDurSec) { $cfg.TermDurSec } else { 120 }) 10 900
$bErrTest = New-Btn $tErr 'Fehlerbildschirm jetzt testen (Kindersitzung)' 20 468 400

function Update-ErrPreview {
    $pvRep1.Text = $tbRep1.Text
    $pvRep2.Text = $tbRep2.Text
    $fam = [string]$cbFont.SelectedItem
    if ($fam) { $pvTerm.Font = New-Object Drawing.Font($fam, 10) }
}

# ===== Tab: Erholung =====
$tRg = New-Tab 'Erholung'
[void](New-Lbl $tRg 'Ungenutzte Zeit (Pause oder PC aus) gibt Minuten vom Tageslimit zurueck.' 20 15 590 26)
$cRgEn  = New-Chk $tRg 'Erholung aktiv' 20 52 ($cfg.RegenEnabled -eq $true)
$nRgPer = New-Num $tRg 'Zurueckgegeben je 60 Min Pause (Min)' 20 96 $(if ($null -ne $cfg.RegenPerHourMin) { $cfg.RegenPerHourMin } else { 30 }) 0 60
$nRgMin = New-Num $tRg 'Pause muss mindestens so lang sein (Min)' 20 136 $(if ($null -ne $cfg.RegenMinPauseMin) { $cfg.RegenMinPauseMin } else { 10 }) 0 120
$nRgMax = New-Num $tRg 'Hoechstens pro Tag zurueck (Min)' 20 176 $(if ($null -ne $cfg.RegenMaxPerDayMin) { $cfg.RegenMaxPerDayMin } else { 120 }) 0 480
$cRgOff  = New-Chk $tRg 'PC-aus-Zeit zaehlt auch als Pause' 20 226 ($cfg.RegenCountOff -ne $false)
$cRgLock = New-Chk $tRg 'Wirkt auch waehrend einer laufenden Sperre' 20 266 ($cfg.RegenWhileLocked -eq $true)

# ===== Tab: Vorschau & Tests =====
$tPrev = New-Tab 'Vorschau & Tests'
$script:prevPics = @()
$picDefs = @(
    @{ File = 'shot-bsod.png';     Cap = 'Bluescreen';                  X = 10;  Y = 8 },
    @{ File = 'shot-logo.png';     Cap = 'Windows-Logo';                X = 320; Y = 8 },
    @{ File = 'shot-repair.png';   Cap = 'Reparatur / Diagnose';        X = 10;  Y = 190 },
    @{ File = 'shot-terminal.png'; Cap = 'Terminal (Wiederherstellung)'; X = 320; Y = 190 }
)
foreach ($d in $picDefs) {
    $pb = New-Object Windows.Forms.PictureBox; $pb.Location = New-Object Drawing.Point($d.X, $d.Y); $pb.Size = New-Object Drawing.Size(290, 163)
    $pb.SizeMode = 'Zoom'; $pb.BackColor = [Drawing.Color]::Black
    $pf = Join-Path $PrevDir $d.File
    if (Test-Path $pf) { try { $imgBytes = [IO.File]::ReadAllBytes($pf); $ms = New-Object IO.MemoryStream -ArgumentList (, $imgBytes); $pb.Image = [Drawing.Image]::FromStream($ms) } catch { } }
    $tPrev.Controls.Add($pb); $script:prevPics += $pb
    [void](New-Lbl $tPrev ($d.Cap + $(if ($pb.Image) { '' } else { ' (Bild fehlt)' })) $d.X ($d.Y + 165) 290 20)
}
[void](New-Lbl $tPrev 'Beispielbilder mit den Standardtexten. Tests laufen auf dem Bildschirm der Kindersitzung:' 10 388 600 24)
$bTFull  = New-Btn $tPrev 'Ganzer Ablauf' 10 418 145 34
$bTTerm  = New-Btn $tPrev 'Terminal (Zeitraffer)' 162 418 155 34
$bTGlit  = New-Btn $tPrev 'Grafikfehler' 324 418 145 34
$bTWarn  = New-Btn $tPrev 'Warnungen' 476 418 135 34
$bTNvMe  = New-Btn $tPrev 'NVIDIA bei mir' 10 462 200 34
$bTNvKid = New-Btn $tPrev 'NVIDIA in Kindersitzung' 220 462 250 34

# ===== Tab: Passwort =====
$tPw = New-Tab 'Passwort'
[void](New-Lbl $tPw 'Aktuelles Werkzeug-Passwort:' 20 20 400 24)
$tbOld = New-Object Windows.Forms.TextBox; $tbOld.Location = New-Object Drawing.Point(20, 48); $tbOld.Size = New-Object Drawing.Size(340, 28); $tbOld.UseSystemPasswordChar = $true; $tPw.Controls.Add($tbOld)
[void](New-Lbl $tPw 'Neues Passwort (mind. 4 Zeichen):' 20 92 400 24)
$tbNew = New-Object Windows.Forms.TextBox; $tbNew.Location = New-Object Drawing.Point(20, 120); $tbNew.Size = New-Object Drawing.Size(340, 28); $tbNew.UseSystemPasswordChar = $true; $tPw.Controls.Add($tbNew)
[void](New-Lbl $tPw 'Neues Passwort wiederholen:' 20 164 400 24)
$tbNew2 = New-Object Windows.Forms.TextBox; $tbNew2.Location = New-Object Drawing.Point(20, 192); $tbNew2.Size = New-Object Drawing.Size(340, 28); $tbNew2.UseSystemPasswordChar = $true; $tPw.Controls.Add($tbNew2)
$bPw = New-Btn $tPw 'Passwort aendern' 20 240 200
$lPw = New-Lbl $tPw '' 20 288 590 30
[void](New-Lbl $tPw 'Das ist nur das Passwort dieses Fensters. Das Windows-Passwort von Verwalter wird in Windows geaendert (Admin-Fenster: net user Verwalter *).' 20 340 590 60)
$script:PwAction = {
    $lPw.ForeColor = [Drawing.Color]::Red
    if (-not (Test-ToolPin $tbOld.Text)) { $lPw.Text = 'Das aktuelle Passwort stimmt nicht.'; return }
    if ($tbNew.Text.Length -lt 4) { $lPw.Text = 'Das neue Passwort braucht mindestens 4 Zeichen.'; return }
    if ($tbNew.Text -ne $tbNew2.Text) { $lPw.Text = 'Die beiden neuen Passwoerter stimmen nicht ueberein.'; return }
    Save-ToolPin $tbNew.Text
    $tbOld.Text = ''; $tbNew.Text = ''; $tbNew2.Text = ''
    $lPw.ForeColor = [Drawing.Color]::DarkGreen; $lPw.Text = 'Passwort geaendert (' + (Get-Date -Format 'HH:mm:ss') + ').'
}
$bPw.Add_Click($script:PwAction)

# ===== Statuszeile und Schliessen-Knopf (immer komplett im sichtbaren Bereich) =====
$lStatus = New-Object Windows.Forms.Label
$lStatus.Location = New-Object Drawing.Point(12, 610); $lStatus.Size = New-Object Drawing.Size(510, 40); $lStatus.ForeColor = [Drawing.Color]::DarkGreen
$lStatus.Text = 'Aenderungen werden sofort automatisch gespeichert.'
$f.Controls.Add($lStatus)
$bClose = New-Object Windows.Forms.Button
$bClose.Text = 'Schliessen'; $bClose.Location = New-Object Drawing.Point(540, 610); $bClose.Size = New-Object Drawing.Size(110, 38)
$f.Controls.Add($bClose)
$bClose.Add_Click({ if ($script:savePending) { Invoke-PendingSave }; $f.Close() })

# ===== Tests starten =====
function Get-KidSession {
    $diag = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Dir 'Sperre.ps1') -Diag)
    foreach ($l in $diag) { if ($l -match '^\s*(\d+)\s+0\s+(\S+)\s+\d+\s*$' -and $Matches[2] -ne 'Verwalter') { return [int]$Matches[1] } }
    return $null
}
$script:testNames = @{ full = 'ganzer Ablauf, ca. 2,5 Minuten'; term = 'Terminal im Zeitraffer, ca. 3 Minuten'; glitch = 'Grafikfehler-Vorschau, ca. 2,5 Minuten'; warn = 'alle Warnungen und dann der ganze Ablauf, ca. 3,5 Minuten'; nvkid = 'NVIDIA-Anzeige' }
function Start-KsTest([string]$which, [switch]$DryRun) {
    $zt = '"' + (Join-Path $Dir 'Zerotest.ps1') + '"'
    $base = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File')
    $a = $null; $msg = ''
    switch ($which) {
        'full'   { $a = $base + $zt;                    $msg = 'Kompletter Test gestartet (ca. 2,5 Min auf dem Bildschirm der Kindersitzung).' }
        'term'   { $a = $base + $zt + '-Interlude';     $msg = 'Terminal-Zeitraffer gestartet (ca. 3 Min auf dem Bildschirm der Kindersitzung).' }
        'glitch' { $a = $base + $zt + '-GlitchPreview'; $msg = 'Grafikfehler-Vorschau gestartet (ca. 2,5 Min auf dem Bildschirm der Kindersitzung).' }
        'warn'   { $a = $base + $zt + '-Warnings';      $msg = 'Warnungen-Test gestartet (ca. 3,5 Min auf dem Bildschirm der Kindersitzung).' }
        'nvme'   { $a = $base + ('"' + $NvBarFile + '"'); $msg = 'NVIDIA-Anzeige bei Ihnen geoeffnet.' }
        'nvkid'  { }
        default  { return 'Unbekannter Test.' }
    }
    if ($DryRun) { if ($which -eq 'nvkid') { return 'SYSTEM-Aufgabe: Sperre.ps1 -TestNvBar -SessionId <Kindersitzung>' }; return ('powershell.exe ' + ($a -join ' ')) }
    try {
        if ($which -eq 'nvkid') {
            $sid = Get-KidSession
            if ($null -eq $sid) { return 'Keine aktive Kindersitzung gefunden (ist gerade jemand angemeldet?).' }
            $act = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -ExecutionPolicy Bypass -File "{0}\Sperre.ps1" -TestNvBar -SessionId {1}' -f $Dir, $sid)
            $pri = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
            Register-ScheduledTask -TaskName 'KS-NvBar-Test' -Action $act -Principal $pri -Force | Out-Null
            Start-ScheduledTask -TaskName 'KS-NvBar-Test'
            Start-Sleep -Seconds 4
            Unregister-ScheduledTask -TaskName 'KS-NvBar-Test' -Confirm:$false -ErrorAction SilentlyContinue
            return 'NVIDIA-Anzeige in der Kindersitzung geoeffnet.'
        }
        Start-Process -FilePath 'powershell.exe' -ArgumentList $a -WindowStyle Hidden | Out-Null
        return $msg
    } catch { return 'Test konnte nicht gestartet werden: ' + $_ }
}
function Invoke-TestWithConfirm([string]$which) {
    if ($which -in 'full', 'term', 'glitch', 'warn', 'nvkid') {
        $ans = [Windows.Forms.MessageBox]::Show(('Dieser Test laeuft auf dem Bildschirm der Kindersitzung ({0}). Jetzt starten?' -f $script:testNames[$which]), 'Test starten', 'YesNo', 'Question')
        if ($ans -ne 'Yes') { return }
    }
    $lStatus.ForeColor = [Drawing.Color]::DarkGreen
    $lStatus.Text = 'Bitte warten ...'
    $lStatus.Text = Start-KsTest $which
}
$bNvMe.Add_Click({ Invoke-TestWithConfirm 'nvme' });   $bTNvMe.Add_Click({ Invoke-TestWithConfirm 'nvme' })
$bNvKid.Add_Click({ Invoke-TestWithConfirm 'nvkid' }); $bTNvKid.Add_Click({ Invoke-TestWithConfirm 'nvkid' })
$bErrTest.Add_Click({ Invoke-TestWithConfirm 'full' }); $bTFull.Add_Click({ Invoke-TestWithConfirm 'full' })
$bTTerm.Add_Click({ Invoke-TestWithConfirm 'term' });  $bTGlit.Add_Click({ Invoke-TestWithConfirm 'glitch' }); $bTWarn.Add_Click({ Invoke-TestWithConfirm 'warn' })

# ===== Speichern (automatisch) =====
$script:SaveAction = {
    try {
        $c = Read-Cfg
        Set-Prop $c 'WeekdayLimitMin' ([int]$nWd.Value)
        Set-Prop $c 'WeekendLimitMin' ([int]$nWe.Value)
        Set-Prop $c 'GraceMin' ([int]$nGr.Value)
        Set-Prop $c 'BonusMin' ([int]$nBo.Value)
        Set-Prop $c 'ResetHour' ([int]$nRs.Value)
        Set-Prop $c 'IdleMin' ([int]$nIdle.Value)
        Set-Prop $c 'Enabled' $cEn.Checked
        $wm = @($warnChecks.Keys | Where-Object { $warnChecks[$_].Checked } | Sort-Object -Descending)
        if ($wm.Count -eq 0) { $wm = @(1) }
        Set-Prop $c 'WarnMinutes' @($wm)
        Set-Prop $c 'KillApps' $cKill.Checked
        Set-Prop $c 'KeyLock' $cKey.Checked
        Set-Prop $c 'PinGlitch' $cPinG.Checked
        Set-Prop $c 'GlitchLevel' ([int]$nGl.Value)
        $mode = ($rbGroup | Where-Object { $_.Checked } | Select-Object -First 1).Tag
        Set-Prop $c 'NvBarMode' $mode
        $tt = $tbTitle.Text.Trim()
        Set-Prop $c 'NvBarTitle' $(if ($tt -eq '' -or $tt -eq 'NVIDIA') { '' } else { $tt })
        Set-Prop $c 'NvBarNote' $tbNote.Text.Trim()
        Set-Prop $c 'Look' $(if ($cLook.Checked) { 'terminal' } else { 'windows' })
        Set-Prop $c 'EndPhase' $(if ($cEndLogo.Checked) { 'logo' } else { 'repair' })
        Set-Prop $c 'FileTicker' $cTicker.Checked
        Set-Prop $c 'Outro' $cOutro.Checked
        $r1 = $tbRep1.Text.Trim(); $r2 = $tbRep2.Text.Trim()
        Set-Prop $c 'RepairText1' $(if ($r1 -eq $DefRep1) { '' } else { $r1 })
        Set-Prop $c 'RepairText2' $(if ($r2 -eq $DefRep2) { '' } else { $r2 })
        Set-Prop $c 'TermFont' ([string]$cbFont.SelectedItem)
        Set-Prop $c 'TermFontScale' ([int]$nScale.Value)
        Set-Prop $c 'TermMinGapSec' ([int]$nTmin.Value * 60)
        Set-Prop $c 'TermMaxGapSec' ([Math]::Max([int]$nTmax.Value, [int]$nTmin.Value) * 60)
        Set-Prop $c 'TermDurSec' ([int]$nTdur.Value)
        Set-Prop $c 'RegenEnabled' $cRgEn.Checked
        Set-Prop $c 'RegenPerHourMin' ([int]$nRgPer.Value)
        Set-Prop $c 'RegenMinPauseMin' ([int]$nRgMin.Value)
        Set-Prop $c 'RegenMaxPerDayMin' ([int]$nRgMax.Value)
        Set-Prop $c 'RegenCountOff' $cRgOff.Checked
        Set-Prop $c 'RegenWhileLocked' $cRgLock.Checked

        # Sicherung nur einmal je Sitzung (vor der ersten Aenderung), die letzten 20 bleiben
        if (-not $script:backedUp) {
            Copy-Item $CfgFile ($CfgFile + '.bak-vor-tool-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) -Force
            $script:backedUp = $true
            $old = @(Get-ChildItem $Dir -Filter 'config.json.bak-vor-tool-*' | Sort-Object Name -Descending | Select-Object -Skip 20)
            foreach ($o in $old) { Remove-Item -LiteralPath $o.FullName -Force -ErrorAction SilentlyContinue }
        }
        # config.json bleibt reines ASCII (Nicht-ASCII-Zeichen als \uXXXX)
        $json = $c | ConvertTo-Json
        $json = [regex]::Replace($json, '[^\x00-\x7F]', [Text.RegularExpressions.MatchEvaluator]{ param($m) ('\u{0:x4}' -f [int][char]$m.Value) })
        $json | Out-File $CfgFile -Encoding ascii
        $script:cfg = $c
        $lStatus.ForeColor = [Drawing.Color]::DarkGreen
        $lStatus.Text = 'Automatisch gespeichert um ' + (Get-Date -Format 'HH:mm:ss') + '.'
    } catch {
        $lStatus.ForeColor = [Drawing.Color]::Red
        $lStatus.Text = 'Fehler beim Speichern: ' + $_
    }
}

# Verzoegerung: nicht bei jedem Klick/Tastendruck sofort, sondern kurz nach der letzten Aenderung
$script:saveTimer = New-Object Windows.Forms.Timer
$script:saveTimer.Interval = 700
function Invoke-PendingSave {
    $script:saveTimer.Stop()
    if ($script:savePending) { $script:savePending = $false; & $script:SaveAction }
}
function Request-Save {
    $script:savePending = $true
    $script:saveTimer.Stop(); $script:saveTimer.Start()
}
$script:saveTimer.Add_Tick({ Invoke-PendingSave })

Update-NvPreview
Update-ErrPreview

# Erst NACH dem Aufbau anhaengen, damit das Befuellen der Felder kein Speichern ausloest
foreach ($c in @($nWd, $nWe, $nGr, $nBo, $nRs, $nIdle, $nGl, $nRgPer, $nRgMin, $nRgMax, $nScale, $nTmin, $nTmax, $nTdur)) { $c.Add_ValueChanged({ Request-Save; Update-NvPreview }) }
foreach ($c in (@($cEn, $cKill, $cKey, $cPinG, $cRgEn, $cRgOff, $cRgLock, $cLook, $cEndLogo, $cTicker, $cOutro) + @($warnChecks.Values) + $rbGroup)) { $c.Add_CheckedChanged({ Request-Save; Update-NvPreview }) }
foreach ($c in @($tbTitle, $tbNote)) { $c.Add_TextChanged({ Request-Save; Update-NvPreview }) }
foreach ($c in @($tbRep1, $tbRep2)) { $c.Add_TextChanged({ Request-Save; Update-ErrPreview }) }
$cbFont.Add_SelectedIndexChanged({ Request-Save; Update-ErrPreview })
$tbSample.Add_ValueChanged({ Update-NvPreview })

[void]$f.ShowDialog()
