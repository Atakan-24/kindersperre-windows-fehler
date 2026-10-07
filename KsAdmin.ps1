# Einstellungs-Fenster (Anzeigename "NVIDIA Systemdiagnose"). Liegt im geschuetzten Ordner (nur SYSTEM/Administratoren),
# darum sieht es automatisch nur Verwalter - kein eigener Schutzmechanismus dafuer noetig.
# Alle sichtbaren Texte sind bewusst neutral gehalten (Diagnose-Werkzeug), damit man es benutzen kann, wenn jemand mitschaut.
# Eigenes Werkzeug-Passwort (per PBKDF2-Hash gespeichert), unabhaengig vom Windows-Passwort.
# Aenderungen werden SOFORT automatisch gespeichert (kurze Verzoegerung, damit nicht jeder Tastendruck speichert).
# Vor der ersten Aenderung je Sitzung wird eine Sicherung von config.json angelegt (die letzten 20 bleiben erhalten).
# Fenstergroesse und Schriftgroesse werden in tool-ui.json gemerkt.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()

$Dir      = 'C:\ProgramData\Kindersperre'
$CfgFile  = Join-Path $Dir 'config.json'
$ToolPin  = Join-Path $Dir 'tool-pin.json'
$AdjFile  = Join-Path $Dir 'adjust.txt'
$UiFile   = Join-Path $Dir 'tool-ui.json'
$PrevDir  = Join-Path $Dir 'preview'
$NvBarFile = 'C:\ProgramData\NVIDIA Corporation\NvContainer\NvBar.ps1'
$StatusFile = 'C:\ProgramData\NVIDIA Corporation\NvContainer\status.json'
$WinUser  = 'Verwalter'
$AppTitle = 'NVIDIA Systemdiagnose'

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

# Windows-Anmeldepasswort eines lokalen Kontos AENDERN (mit dem aktuellen Passwort, nicht zuruecksetzen):
# so bleiben gespeicherte Anmeldedaten und verschluesselte Daten des Kontos erhalten. Gibt $null bei Erfolg zurueck, sonst den Fehlertext.
# Das Passwort wird weder gespeichert noch protokolliert noch auf einer Kommandozeile uebergeben.
function Set-WinPassword([string]$user, [string]$oldPw, [string]$newPw) {
    try {
        Add-Type -AssemblyName System.DirectoryServices.AccountManagement
        $ctx = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Machine)
        $u = [System.DirectoryServices.AccountManagement.UserPrincipal]::FindByIdentity($ctx, $user)
        if (-not $u) { return 'Konto nicht gefunden.' }
        $u.ChangePassword($oldPw, $newPw)
        return $null
    } catch {
        $m = $_.Exception.Message
        if ($_.Exception.InnerException) { $m = $_.Exception.InnerException.Message }
        return $m
    }
}

# ---- Passwort-Abfrage bzw. Erst-Einrichtung ----
function Show-PinGate {
    $script:first = -not (Test-Path $ToolPin)
    $first = $script:first
    $script:g = New-Object Windows.Forms.Form
    $g = $script:g
    $g.Font = New-Object Drawing.Font('Segoe UI', 10)
    $g.Text = if ($first) { 'Werkzeug-Passwort festlegen' } else { $AppTitle }
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

# Ansicht (Fenster- und Schriftgroesse) aus tool-ui.json
$ui = $null
try { $ui = Get-Content $UiFile -Raw | ConvertFrom-Json } catch { }
$script:uiFont = 10
$winW = 620; $winH = 620
if ($ui) {
    if ($ui.FontSize -ge 9 -and $ui.FontSize -le 13) { $script:uiFont = [int]$ui.FontSize }
    if ($ui.Width -ge 520 -and $ui.Width -le 1600) { $winW = [int]$ui.Width }
    if ($ui.Height -ge 460 -and $ui.Height -le 1200) { $winH = [int]$ui.Height }
}

# Text-Funktion der NVIDIA-Anzeige aus NvBar.ps1 uebernehmen, damit Vorschau und echte Anzeige immer gleich rechnen
try {
    $nvAst = [Management.Automation.Language.Parser]::ParseFile($NvBarFile, [ref]$null, [ref]$null)
    $nvFn = $nvAst.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Get-SubText' }, $true)
    . ([scriptblock]::Create($nvFn.Extent.Text))
} catch { function Get-SubText($s, [string]$mode) { return '' } }

$f = New-Object Windows.Forms.Form
$f.Text = $AppTitle
$f.Font = New-Object Drawing.Font('Segoe UI', $script:uiFont)
$f.FormBorderStyle = 'Sizable'; $f.MaximizeBox = $true; $f.MinimizeBox = $true
$f.StartPosition = 'CenterScreen'
$f.MinimumSize = New-Object Drawing.Size(540, 500)
$f.ClientSize = New-Object Drawing.Size($winW, $winH)

$tabs = New-Object Windows.Forms.TabControl
$tabs.Location = New-Object Drawing.Point(8, 8); $tabs.Size = New-Object Drawing.Size(($winW - 16), ($winH - 8 - 92))
$tabs.Multiline = $true
$tabs.Padding = New-Object Drawing.Point(5, 3)
$tabs.Anchor = 'Top,Bottom,Left,Right'
$f.Controls.Add($tabs)

function New-Tab($title) { $p = New-Object Windows.Forms.TabPage; $p.Text = $title; $p.AutoScroll = $true; $tabs.TabPages.Add($p); return $p }
function New-Lbl($parent, $text, $x, $y, $w = 550, $h = 24) {
    $l = New-Object Windows.Forms.Label; $l.Text = $text; $l.Location = New-Object Drawing.Point($x, $y); $l.Size = New-Object Drawing.Size($w, $h); $parent.Controls.Add($l); return $l
}
function New-Num($parent, $label, $x, $y, $val, $min = 0, $max = 1440) {
    [void](New-Lbl $parent $label $x ($y + 3) 350 24)
    $n = New-Object Windows.Forms.NumericUpDown; $n.Location = New-Object Drawing.Point(($x + 360), $y); $n.Size = New-Object Drawing.Size(110, 28)
    $n.Minimum = $min; $n.Maximum = $max; $n.Value = [Math]::Max($min, [Math]::Min($max, [int]$val)); $parent.Controls.Add($n)
    return $n
}
function New-Chk($parent, $label, $x, $y, $checked) {
    $c = New-Object Windows.Forms.CheckBox; $c.Text = $label; $c.Location = New-Object Drawing.Point($x, $y); $c.Size = New-Object Drawing.Size(550, 26); $c.Checked = [bool]$checked
    $parent.Controls.Add($c); return $c
}
function New-Txt($parent, $x, $y, $w, $text, $max = 60) {
    $t = New-Object Windows.Forms.TextBox; $t.Location = New-Object Drawing.Point($x, $y); $t.Size = New-Object Drawing.Size($w, 28); $t.MaxLength = $max; $t.Text = [string]$text
    $parent.Controls.Add($t); return $t
}
function New-Btn($parent, $text, $x, $y, $w, $h = 34) {
    $b = New-Object Windows.Forms.Button; $b.Text = $text; $b.Location = New-Object Drawing.Point($x, $y); $b.Size = New-Object Drawing.Size($w, $h); $parent.Controls.Add($b); return $b
}

# ===== Tab: Grenzwerte =====
$tLim = New-Tab 'Grenzwerte'
$nWd   = New-Num $tLim 'Grenzwert Mo-Fr (Min)'        20  16 $cfg.WeekdayLimitMin 30 1000
$nWe   = New-Num $tLim 'Grenzwert Sa/So (Min)'        20  54 $cfg.WeekendLimitMin 30 1000
$nGr   = New-Num $tLim 'Toleranz (Min)'               20  92 $cfg.GraceMin 0 120
$nBo   = New-Num $tLim 'Zusatz per Code (Min)'        20 130 $cfg.BonusMin 0 240
$nRs   = New-Num $tLim 'Tageswechsel (Std)'           20 168 $cfg.ResetHour 0 23
$nIdle = New-Num $tLim 'Inaktiv ab (Min)'             20 206 $(if ($cfg.IdleMin) { $cfg.IdleMin } else { 5 }) 1 60
$cEn   = New-Chk $tLim 'Ueberwachung aktiv (aus = Funktion pausiert, keine Meldung)' 20 252 ($cfg.Enabled -ne $false)
[void](New-Lbl $tLim 'Heute sofort anpassen:' 20 306 220 24)
$nAdj = New-Object Windows.Forms.NumericUpDown; $nAdj.Location = New-Object Drawing.Point(240, 302); $nAdj.Size = New-Object Drawing.Size(90, 28); $nAdj.Minimum = -300; $nAdj.Maximum = 300; $tLim.Controls.Add($nAdj)
$bAdjMore = New-Btn $tLim '+ Mehr' 345 300 100
$bAdjLess = New-Btn $tLim '- Weniger' 455 300 110
[void](New-Lbl $tLim 'Mehr gibt Minuten dazu, Weniger nimmt welche weg. Wirkt spaetestens in 1 Minute.' 20 346 550 44)
# adjust.txt = Minuten, die zum Tageszaehler ADDIERT werden: negativ = MEHR uebrig, positiv = WENIGER uebrig
$script:AdjMoreAction = { (-1.0 * [double]$nAdj.Value) | Out-File $AdjFile -Encoding ascii; $lStatus.ForeColor = [Drawing.Color]::DarkGreen; $lStatus.Text = ('MEHR: {0} Minuten heute zusaetzlich (wirkt spaetestens in 1 Min).' -f [double]$nAdj.Value) }
$script:AdjLessAction = { [double]$nAdj.Value | Out-File $AdjFile -Encoding ascii; $lStatus.ForeColor = [Drawing.Color]::DarkGreen; $lStatus.Text = ('WENIGER: {0} Minuten heute abgezogen (wirkt spaetestens in 1 Min).' -f [double]$nAdj.Value) }
$bAdjMore.Add_Click($script:AdjMoreAction)
$bAdjLess.Add_Click($script:AdjLessAction)

# ===== Tab: Meldungen =====
$tWarn = New-Tab 'Meldungen'
[void](New-Lbl $tWarn 'Welche Vorab-Meldungen sollen kommen (Minuten vorher)?' 20 15 550 26)
$cur = @(); if ($cfg.WarnMinutes) { $cur = @($cfg.WarnMinutes | ForEach-Object { [int]$_ }) } else { $cur = @(15, 1) }
$warnChecks = @{}
$y = 52
foreach ($m in 45, 30, 20, 15, 5, 1) { $warnChecks[$m] = New-Chk $tWarn "$m Minuten vorher" 20 $y ($cur -contains $m); $y += 36 }
[void](New-Lbl $tWarn 'Ist nichts angehakt, gilt automatisch nur die 1-Minuten-Meldung.' 20 ($y + 8) 550 26)

# ===== Tab: Prozesse =====
$tProg = New-Tab 'Prozesse'
$cKill = New-Chk $tProg 'Programme mit Fenster bei Diagnosestart beenden' 20 18 ($cfg.KillApps -ne $false)
$cKey  = New-Chk $tProg 'Tastenschutz waehrend der Diagnose (Windows-Taste, Alt+Tab usw.)' 20 56 ($cfg.KeyLock -ne $false)
$cPinG = New-Chk $tProg 'Grafik-Ueberlagerung nach Zusatz-Code' 20 94 ($cfg.PinGlitch -ne $false)
$nGl   = New-Num $tProg 'Ueberlagerungs-Stufe (1 = leicht, 3 = stark)' 20 138 $(if ($cfg.GlitchLevel) { $cfg.GlitchLevel } else { 3 }) 1 3

# ===== Tab: NVIDIA (Titel, Text, Anzeige, Vorschau) =====
$tNv = New-Tab 'NVIDIA'
[void](New-Lbl $tNv 'Titel (Standard: NVIDIA):' 20 12 220 24)
$tbTitle = New-Txt $tNv 250 9 250 $(if ($cfg.NvBarTitle) { $cfg.NvBarTitle } else { 'NVIDIA' }) 24
[void](New-Lbl $tNv 'Zusatztext (optional):' 20 46 220 24)
$tbNote = New-Txt $tNv 250 43 320 $cfg.NvBarNote 60
[void](New-Lbl $tNv 'Zeile unter dem Balken:' 20 80 300 24)
$modes = [ordered]@{
    'bar'   = 'Nur Balken'
    'pct'   = 'Balken + Prozent'
    'rest'  = 'Balken + Restwert (z. B. "noch 47 Min")'
    'used'  = 'Balken + verbraucht vom Grenzwert'
    'clock' = 'Balken + geschaetzte Uhrzeit des Fehlers'
}
$rbGroup = @()
$y = 104
foreach ($k in $modes.Keys) {
    $rb = New-Object Windows.Forms.RadioButton; $rb.Text = $modes[$k]; $rb.Tag = $k
    $rb.Location = New-Object Drawing.Point(20, $y); $rb.Size = New-Object Drawing.Size(550, 26)
    if (($cfg.NvBarMode -eq $k) -or (-not $cfg.NvBarMode -and $k -eq 'pct')) { $rb.Checked = $true }
    $tNv.Controls.Add($rb); $rbGroup += $rb; $y += 28
}
[void](New-Lbl $tNv 'Vorschau (so sieht es aus):' 20 252 260 24)
$pvPanel = New-Object Windows.Forms.Panel; $pvPanel.Location = New-Object Drawing.Point(20, 278); $pvPanel.Size = New-Object Drawing.Size(285, 132)
$pvPanel.BackColor = [Drawing.Color]::FromArgb(32, 32, 32); $pvPanel.BorderStyle = 'FixedSingle'; $tNv.Controls.Add($pvPanel)
$pvTitle = New-Object Windows.Forms.Label; $pvTitle.Location = New-Object Drawing.Point(15, 10); $pvTitle.Size = New-Object Drawing.Size(255, 26)
$pvTitle.ForeColor = [Drawing.Color]::FromArgb(118, 185, 0); $pvTitle.Font = New-Object Drawing.Font('Segoe UI', 12, [Drawing.FontStyle]::Bold); $pvPanel.Controls.Add($pvTitle)
$pvBar = New-Object Windows.Forms.ProgressBar; $pvBar.Location = New-Object Drawing.Point(15, 42); $pvBar.Size = New-Object Drawing.Size(255, 22); $pvBar.Style = 'Continuous'; $pvPanel.Controls.Add($pvBar)
$pvSub = New-Object Windows.Forms.Label; $pvSub.Location = New-Object Drawing.Point(15, 70); $pvSub.Size = New-Object Drawing.Size(255, 20)
$pvSub.ForeColor = [Drawing.Color]::FromArgb(200, 200, 200); $pvSub.Font = New-Object Drawing.Font('Segoe UI', 9); $pvPanel.Controls.Add($pvSub)
$pvNote = New-Object Windows.Forms.Label; $pvNote.Location = New-Object Drawing.Point(15, 92); $pvNote.Size = New-Object Drawing.Size(255, 34)
$pvNote.ForeColor = [Drawing.Color]::FromArgb(170, 170, 170); $pvNote.Font = New-Object Drawing.Font('Segoe UI', 9); $pvPanel.Controls.Add($pvNote)
[void](New-Lbl $tNv 'Beispielwert (Auslastung in %):' 320 278 250 24)
$tbSample = New-Object Windows.Forms.TrackBar; $tbSample.Location = New-Object Drawing.Point(320, 304); $tbSample.Size = New-Object Drawing.Size(250, 45)
$tbSample.Minimum = 0; $tbSample.Maximum = 100; $tbSample.TickFrequency = 10; $tbSample.Value = 60; $tNv.Controls.Add($tbSample)
$bNvMe  = New-Btn $tNv 'Bei mir zeigen' 20 420 150
$bNvKid = New-Btn $tNv 'Auf Zielkonto zeigen' 180 420 210
[void](New-Lbl $tNv 'Das Fenster laesst sich mit der Maus verschieben, die Stelle wird gemerkt.' 20 452 550 24)

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

# ===== Tab: Fehlerdiagnose =====
$tErr = New-Tab 'Diagnose'
$cLook    = New-Chk $tErr 'Alter Text-Look (nur Konsole) statt Windows-Absturz-Look' 20 8 ($cfg.Look -eq 'terminal')
$cEndLogo = New-Chk $tErr 'Am Ende nur das Logo zeigen (ohne Reparatur-Text)' 20 36 ($cfg.EndPhase -eq 'logo')
$cTicker  = New-Chk $tErr 'Kleine Datei-/Programmzeile unten links' 20 64 ($cfg.FileTicker -ne $false)
$cOutro   = New-Chk $tErr 'Neustart-Abschluss am Ende (Schwarz, Logo, Desktop)' 20 92 ($cfg.Outro -ne $false)
[void](New-Lbl $tErr 'Reparatur-Text 1:' 20 129 170 24)
$tbRep1 = New-Txt $tErr 200 126 370 $(if ($cfg.RepairText1) { $cfg.RepairText1 } else { $DefRep1 }) 60
[void](New-Lbl $tErr 'Reparatur-Text 2:' 20 161 170 24)
$tbRep2 = New-Txt $tErr 200 158 370 $(if ($cfg.RepairText2) { $cfg.RepairText2 } else { $DefRep2 }) 60
$pvRepPanel = New-Object Windows.Forms.Panel; $pvRepPanel.Location = New-Object Drawing.Point(20, 192); $pvRepPanel.Size = New-Object Drawing.Size(550, 60)
$pvRepPanel.BackColor = [Drawing.Color]::Black; $tErr.Controls.Add($pvRepPanel)
$pvRep1 = New-Object Windows.Forms.Label; $pvRep1.Location = New-Object Drawing.Point(0, 2); $pvRep1.Size = New-Object Drawing.Size(550, 28); $pvRep1.TextAlign = 'MiddleCenter'
$pvRep1.ForeColor = [Drawing.Color]::White; $pvRep1.Font = New-Object Drawing.Font('Segoe UI Light', 13); $pvRepPanel.Controls.Add($pvRep1)
$pvRep2 = New-Object Windows.Forms.Label; $pvRep2.Location = New-Object Drawing.Point(0, 30); $pvRep2.Size = New-Object Drawing.Size(550, 28); $pvRep2.TextAlign = 'MiddleCenter'
$pvRep2.ForeColor = [Drawing.Color]::White; $pvRep2.Font = New-Object Drawing.Font('Segoe UI Light', 13); $pvRepPanel.Controls.Add($pvRep2)
[void](New-Lbl $tErr 'Konsolen-Schrift:' 20 268 170 24)
$monoAll = @('Consolas', 'Courier New', 'Lucida Console', 'Cascadia Mono', 'Cascadia Code', 'Lucida Sans Typewriter')
$installed = @([Drawing.FontFamily]::Families | ForEach-Object { $_.Name })
$monoFonts = @($monoAll | Where-Object { $installed -contains $_ })
if ($monoFonts.Count -eq 0) { $monoFonts = @('Consolas') }
$cbFont = New-Object Windows.Forms.ComboBox; $cbFont.DropDownStyle = 'DropDownList'; $cbFont.Location = New-Object Drawing.Point(200, 265); $cbFont.Size = New-Object Drawing.Size(180, 28)
foreach ($n in $monoFonts) { [void]$cbFont.Items.Add($n) }
$curFont = if ($cfg.TermFont -and ($monoFonts -contains [string]$cfg.TermFont)) { [string]$cfg.TermFont } else { $monoFonts[0] }
$cbFont.SelectedItem = $curFont
$tErr.Controls.Add($cbFont)
$pvTerm = New-Object Windows.Forms.Label; $pvTerm.Location = New-Object Drawing.Point(390, 262); $pvTerm.Size = New-Object Drawing.Size(180, 30); $pvTerm.TextAlign = 'MiddleLeft'
$pvTerm.BackColor = [Drawing.Color]::Black; $pvTerm.ForeColor = [Drawing.Color]::FromArgb(255, 70, 70); $pvTerm.Text = 'FEHLGESCHLAGEN'; $tErr.Controls.Add($pvTerm)
$nScale = New-Num $tErr 'Schriftgroesse (% der automatisch passenden)' 20 302 $(if ($cfg.TermFontScale) { $cfg.TermFontScale } else { 100 }) 50 100
$nTmin  = New-Num $tErr 'Konsole erscheint fruehestens nach (Min)' 20 338 $(if ($cfg.TermMinGapSec) { [int]($cfg.TermMinGapSec / 60) } else { 8 }) 1 120
$nTmax  = New-Num $tErr 'Konsole erscheint spaetestens nach (Min)' 20 374 $(if ($cfg.TermMaxGapSec) { [int]($cfg.TermMaxGapSec / 60) } else { 14 }) 1 120
$nTdur  = New-Num $tErr 'Konsole bleibt sichtbar (Sekunden)' 20 410 $(if ($cfg.TermDurSec) { $cfg.TermDurSec } else { 120 }) 10 900
$bErrTest = New-Btn $tErr 'Fehlerdiagnose jetzt testen (Zielkonto)' 20 452 380

function Update-ErrPreview {
    $pvRep1.Text = $tbRep1.Text
    $pvRep2.Text = $tbRep2.Text
    $fam = [string]$cbFont.SelectedItem
    if ($fam) { $pvTerm.Font = New-Object Drawing.Font($fam, 10) }
}

# ===== Tab: Abkuehlung =====
$tRg = New-Tab ('Abk' + [char]0xFC + 'hlung')
[void](New-Lbl $tRg 'Ungenutzte Phasen (Pause oder PC aus) geben dem System Minuten zurueck.' 20 15 550 26)
$cRgEn  = New-Chk $tRg 'Abkuehlung aktiv' 20 50 ($cfg.RegenEnabled -ne $false)
$nRgPer = New-Num $tRg 'Zurueckgegeben je 60 Min Pause (Min)' 20 92 $(if ($null -ne $cfg.RegenPerHourMin) { $cfg.RegenPerHourMin } else { 30 }) 0 60
$nRgMin = New-Num $tRg 'Pause muss mindestens so lang sein (Min)' 20 130 $(if ($null -ne $cfg.RegenMinPauseMin) { $cfg.RegenMinPauseMin } else { 10 }) 0 120
$nRgMax = New-Num $tRg 'Hoechstens pro Tag zurueck (Min)' 20 168 $(if ($null -ne $cfg.RegenMaxPerDayMin) { $cfg.RegenMaxPerDayMin } else { 120 }) 0 480
$cRgOff  = New-Chk $tRg 'PC-aus-Phase zaehlt auch als Pause' 20 216 ($cfg.RegenCountOff -ne $false)
$cRgLock = New-Chk $tRg 'Wirkt auch waehrend einer laufenden Diagnose' 20 252 ($cfg.RegenWhileLocked -eq $true)

# ===== Tab: Diagnose-Vorschau =====
$tPrev = New-Tab 'Vorschau'
$script:prevPics = @()
$picDefs = @(
    @{ File = 'shot-bsod.png';     Cap = 'Bluescreen';                   X = 10;  Y = 6 },
    @{ File = 'shot-logo.png';     Cap = 'Windows-Logo';                 X = 300; Y = 6 },
    @{ File = 'shot-repair.png';   Cap = 'Reparatur / Diagnose';         X = 10;  Y = 188 },
    @{ File = 'shot-terminal.png'; Cap = 'Konsole (Wiederherstellung)';  X = 300; Y = 188 }
)
foreach ($d in $picDefs) {
    $pb = New-Object Windows.Forms.PictureBox; $pb.Location = New-Object Drawing.Point($d.X, $d.Y); $pb.Size = New-Object Drawing.Size(270, 152)
    $pb.SizeMode = 'Zoom'; $pb.BackColor = [Drawing.Color]::Black
    $pf = Join-Path $PrevDir $d.File
    if (Test-Path $pf) { try { $imgBytes = [IO.File]::ReadAllBytes($pf); $ms = New-Object IO.MemoryStream -ArgumentList (, $imgBytes); $pb.Image = [Drawing.Image]::FromStream($ms) } catch { } }
    $tPrev.Controls.Add($pb); $script:prevPics += $pb
    [void](New-Lbl $tPrev ($d.Cap + $(if ($pb.Image) { '' } else { ' (Bild fehlt)' })) $d.X ($d.Y + 154) 270 22)
}
[void](New-Lbl $tPrev 'Beispielbilder mit den Standardtexten. Tests laufen auf dem Bildschirm des Zielkontos:' 10 370 560 24)
$bTFull  = New-Btn $tPrev 'Komplett-Diagnose' 10 398 160
$bTTerm  = New-Btn $tPrev 'Konsole (schnell)' 178 398 140
$bTGlit  = New-Btn $tPrev 'Grafik' 326 398 100
$bTWarn  = New-Btn $tPrev 'Meldungen' 434 398 130
$bTNvMe  = New-Btn $tPrev 'NVIDIA bei mir' 10 440 180
$bTNvKid = New-Btn $tPrev 'NVIDIA auf Zielkonto' 198 440 210

# ===== Tab: Zugriff (Werkzeug-Passwort, Windows-Passwort, Support-Code) - drei Spalten =====
$tPw = New-Tab 'Zugriff'
function New-PwBox($tab, [int]$x, [int]$y) {
    $b = New-Object Windows.Forms.TextBox; $b.Location = New-Object Drawing.Point($x, $y); $b.Size = New-Object Drawing.Size(178, 28); $b.UseSystemPasswordChar = $true
    $tab.Controls.Add($b); return $b
}
$cx1 = 12; $cx2 = 207; $cx3 = 402
[void](New-Lbl $tPw 'Werkzeug-Passwort' $cx1 10 180 24)
[void](New-Lbl $tPw 'Aktuell:' $cx1 40 180 22)
$tbOld = New-PwBox $tPw $cx1 62
[void](New-Lbl $tPw 'Neu (mind. 4 Zeichen):' $cx1 98 180 22)
$tbNew = New-PwBox $tPw $cx1 120
[void](New-Lbl $tPw 'Wiederholen:' $cx1 156 180 22)
$tbNew2 = New-PwBox $tPw $cx1 178
$bPw = New-Btn $tPw 'Passwort aendern' $cx1 216 178 34
$lPw = New-Lbl $tPw '' $cx1 256 178 66
[void](New-Lbl $tPw 'Windows-Passwort' $cx2 10 180 24)
[void](New-Lbl $tPw 'Aktuell:' $cx2 40 180 22)
$tbWinOld = New-PwBox $tPw $cx2 62
[void](New-Lbl $tPw 'Neu (mind. 6 Zeichen):' $cx2 98 180 22)
$tbWinNew = New-PwBox $tPw $cx2 120
[void](New-Lbl $tPw 'Wiederholen:' $cx2 156 180 22)
$tbWinNew2 = New-PwBox $tPw $cx2 178
$bWin = New-Btn $tPw 'Windows aendern' $cx2 216 178 34
$lWin = New-Lbl $tPw '' $cx2 256 178 66
[void](New-Lbl $tPw 'Support-Code' $cx3 10 180 24)
[void](New-Lbl $tPw 'Aktuell:' $cx3 40 180 22)
$tbPinOld = New-PwBox $tPw $cx3 62
[void](New-Lbl $tPw 'Neu (mind. 6 Zeichen):' $cx3 98 180 22)
$tbPinNew = New-PwBox $tPw $cx3 120
[void](New-Lbl $tPw 'Wiederholen:' $cx3 156 180 22)
$tbPinNew2 = New-PwBox $tPw $cx3 178
$bPin = New-Btn $tPw 'Code aendern' $cx3 216 178 34
$lPin = New-Lbl $tPw '' $cx3 256 178 66
[void](New-Lbl $tPw 'Support-Code: wird am Fehlerbildschirm im versteckten Feld eingegeben. Fuer das Windows-Passwort wird das aktuelle gebraucht. Nichts davon wird angezeigt, gespeichert oder protokolliert.' 12 330 570 50)
$script:PwAction = {
    $lPw.ForeColor = [Drawing.Color]::Red
    if (-not (Test-ToolPin $tbOld.Text)) { $lPw.Text = 'Aktuelles Passwort stimmt nicht.'; return }
    if ($tbNew.Text.Length -lt 4) { $lPw.Text = 'Neues Passwort: mindestens 4 Zeichen.'; return }
    if ($tbNew.Text -ne $tbNew2.Text) { $lPw.Text = 'Die neuen Passwoerter stimmen nicht ueberein.'; return }
    Save-ToolPin $tbNew.Text
    $tbOld.Text = ''; $tbNew.Text = ''; $tbNew2.Text = ''
    $lPw.ForeColor = [Drawing.Color]::DarkGreen; $lPw.Text = 'Passwort geaendert (' + (Get-Date -Format 'HH:mm:ss') + ').'
}
$bPw.Add_Click($script:PwAction)
$script:WinPwAction = {
    $lWin.ForeColor = [Drawing.Color]::Red
    if ($tbWinOld.Text.Length -eq 0) { $lWin.Text = 'Bitte das aktuelle Windows-Passwort eingeben.'; return }
    if ($tbWinNew.Text.Length -lt 6) { $lWin.Text = 'Das neue Windows-Passwort braucht mindestens 6 Zeichen.'; return }
    if ($tbWinNew.Text -ne $tbWinNew2.Text) { $lWin.Text = 'Die beiden neuen Passwoerter stimmen nicht ueberein.'; return }
    if ($tbWinNew.Text -eq $tbWinOld.Text) { $lWin.Text = 'Das neue Passwort muss sich vom aktuellen unterscheiden.'; return }
    $wErr = Set-WinPassword $WinUser $tbWinOld.Text $tbWinNew.Text
    if ($wErr) { $lWin.Text = 'Nicht geaendert: ' + $wErr; return }
    $tbWinOld.Text = ''; $tbWinNew.Text = ''; $tbWinNew2.Text = ''
    $lWin.ForeColor = [Drawing.Color]::DarkGreen; $lWin.Text = 'Windows-Passwort geaendert (' + (Get-Date -Format 'HH:mm:ss') + '). Ab jetzt gilt das neue Passwort.'
}
$bWin.Add_Click($script:WinPwAction)
# Support-Code (die PIN fuer das versteckte Feld am Fehlerbildschirm): gleiche Ablage und gleiches Verfahren wie das Werkzeug-Passwort (PBKDF2, Salz), Datei pin.json
$PinFile = Join-Path $Dir 'pin.json'
function Test-SupportCode([string]$code) {
    try {
        $p = Get-Content $PinFile -Raw | ConvertFrom-Json
        $h = Hash-Pin $code ([Convert]::FromBase64String($p.salt))
        return ([Convert]::ToBase64String($h) -eq $p.hash)
    } catch { return $false }
}
function Save-SupportCode([string]$code) {
    $salt = New-Object byte[] 16
    (New-Object Security.Cryptography.RNGCryptoServiceProvider).GetBytes($salt)
    $hash = Hash-Pin $code $salt
    @{ salt = [Convert]::ToBase64String($salt); hash = [Convert]::ToBase64String($hash) } | ConvertTo-Json -Compress | Out-File $PinFile -Encoding ascii
}
$script:PinAction = {
    $lPin.ForeColor = [Drawing.Color]::Red
    $exists = Test-Path $PinFile
    if ($exists -and -not (Test-SupportCode $tbPinOld.Text)) { $lPin.Text = 'Aktueller Code stimmt nicht.'; return }
    if ($tbPinNew.Text.Length -lt 6) { $lPin.Text = 'Neuer Code: mindestens 6 Zeichen.'; return }
    if ($tbPinNew.Text -ne $tbPinNew2.Text) { $lPin.Text = 'Die beiden neuen Codes stimmen nicht ueberein.'; return }
    if ($exists) { Copy-Item $PinFile ($PinFile + '.bak-vor-aenderung') -Force }
    Save-SupportCode $tbPinNew.Text
    $tbPinOld.Text = ''; $tbPinNew.Text = ''; $tbPinNew2.Text = ''
    $lPin.ForeColor = [Drawing.Color]::DarkGreen; $lPin.Text = 'Code geaendert (' + (Get-Date -Format 'HH:mm:ss') + '). Gilt sofort.'
}
$bPin.Add_Click($script:PinAction)
# ===== Tab: Hilfe (ganz rechts): nur ein Info-Knopf; Ablauf, Kurzbefehle und Tests stehen im Info-Fenster =====
$tKeys = New-Tab 'Hilfe'
$script:HelpText = @"
ABLAUF EINER FEHLERDIAGNOSE

1. Vorab-Meldungen (Standard: 15 und 1 Minute vorher) als Grafiktreiber-Hinweis.
   Die NVIDIA-Anzeige mit dem Balken erscheint.
2. Bildfehler auf dem echten Desktop, kurzes Schwarzbild, starker Bildfehler.
3. Bluescreen (VIDEO_TDR_FAILURE).
4. Windows-Logo mit Ladepunkten, danach "Automatische Reparatur wird vorbereitet"
   und "Diagnose des PCs wird ausgefuehrt".
5. Alle 8 bis 14 Minuten fuer 2 Minuten die Diagnose-Konsole
   ("Wiederherstellungsversuch N von 30"), verteilt bis zum Tageswechsel.
6. Ende zum Tageswechsel (6 Uhr): kurz Schwarz, Logo, dann der Desktop.
7. Nach einem gueltigen Code (+60 Minuten) laeuft bis zum Tageswechsel die
   Grafik-Ueberlagerung (Bildfehler-Effekte).
8. Abkuehlung: ungenutzte Zeit (Pause oder PC aus) gibt Minuten zurueck
   (Reiter "Abkuehlung", standardmaessig an).


TASTENKUERZEL WAEHREND EINES FEHLERBILDSCHIRMS
(nur wenn gerade ein Fehlerbildschirm angezeigt wird, nichts wird gespeichert)

Leertaste + F12 + Alt
    Oeffnet 30 Sekunden lang das versteckte Codefeld (Support-Zugang).

F11 + F12
    Schaltet 2 Minuten lang von Hand in die Diagnose-Konsole
    (nur beim Logo oder der Reparaturanzeige). Nochmal druecken beendet sie sofort.

F1 + F12
    Blendet die Grafik-Ueberlagerung aus bzw. wieder ein (erst F12 halten, dann F1).

Z + F12
    Zeigt ca. 6 Sekunden lang die geschaetzte Wiederherstellungsdauer.


BEFEHLE AN DEN ASSISTENTEN (die Nachricht besteht nur aus diesem einen Wort)

Zerotest     Komplett-Diagnose, ca. 2,5 Min, ohne den Tageszaehler zu aendern
Zerofull     wie Zerotest, vorher alle Vorab-Meldungen
Zeroterm     schnelle Wiedergabe der Konsolen-Auftritte
Zeroglitch   Vorschau der Grafik-Ueberlagerung
Zero         Diagnose sofort ausloesen
Zerooff      Diagnose beenden
Zerokill     wie Zero, beendet zusaetzlich Programme mit Fenster


TEST-KNOEPFE (Reiter "Vorschau" und "NVIDIA")
Sie starten dasselbe wie die Befehle, laufen aber auf dem Bildschirm des Zielkontos
und fragen vorher nach. "NVIDIA bei mir" oeffnet die Anzeige nur auf diesem Bildschirm.
"@
$script:InfoAction = {
    $d = New-Object Windows.Forms.Form
    $d.Text = 'Fehlerdiagnose - Ablauf'
    $d.Font = $f.Font
    $d.FormBorderStyle = 'Sizable'; $d.MinimizeBox = $false; $d.MaximizeBox = $false; $d.ShowInTaskbar = $false
    $d.StartPosition = 'CenterParent'; $d.ClientSize = New-Object Drawing.Size(600, 520)
    $tb = New-Object Windows.Forms.TextBox
    $tb.Multiline = $true; $tb.ReadOnly = $true; $tb.ScrollBars = 'Vertical'; $tb.WordWrap = $true
    $tb.BackColor = [Drawing.Color]::White; $tb.Font = New-Object Drawing.Font('Consolas', 9.5)
    $tb.Location = New-Object Drawing.Point(10, 10); $tb.Size = New-Object Drawing.Size(580, 456); $tb.Anchor = 'Top,Bottom,Left,Right'
    $tb.Text = $script:HelpText.Replace("`r`n", "`n").Replace("`n", "`r`n")
    $tb.TabStop = $false
    $d.Controls.Add($tb)
    $bx = New-Object Windows.Forms.Button
    $bx.Text = 'Schliessen'; $bx.Location = New-Object Drawing.Point(480, 474); $bx.Size = New-Object Drawing.Size(110, 34); $bx.Anchor = 'Bottom,Right'
    $bx.Add_Click({ $d.Close() })
    $d.Controls.Add($bx); $d.CancelButton = $bx
    $d.Add_Shown({ $tb.SelectionStart = 0; $tb.SelectionLength = 0; $bx.Focus() })
    [void]$d.ShowDialog($f)
}
[void](New-Lbl $tKeys 'Informationen zur Fehlerdiagnose:' 10 12 560 24)
$bInfo = New-Btn $tKeys 'Info' 10 44 200
$bInfo.Add_Click($script:InfoAction)
[void](New-Lbl $tKeys 'Ansicht - Schriftgroesse:' 10 116 200 24)
$cbSize = New-Object Windows.Forms.ComboBox; $cbSize.DropDownStyle = 'DropDownList'; $cbSize.Location = New-Object Drawing.Point(215, 113); $cbSize.Size = New-Object Drawing.Size(160, 28)
foreach ($n in 'Klein (9)', 'Normal (10)', 'Gross (11)', 'Sehr gross (12)') { [void]$cbSize.Items.Add($n) }
$cbSize.SelectedIndex = [Math]::Max(0, [Math]::Min(3, $script:uiFont - 9))
$tKeys.Controls.Add($cbSize)
[void](New-Lbl $tKeys 'Die Fenstergroesse laesst sich mit der Maus an den Raendern ziehen. Beides wird gemerkt.' 10 152 560 44)
# ===== Untere Leiste: Auslastung in %, Statuszeile, Schliessen =====
$pbDay = New-Object Windows.Forms.ProgressBar
$pbDay.Location = New-Object Drawing.Point(12, ($winH - 82)); $pbDay.Size = New-Object Drawing.Size(($winW - 24), 18)
$pbDay.Minimum = 0; $pbDay.Maximum = 100; $pbDay.Style = 'Continuous'; $pbDay.Anchor = 'Bottom,Left,Right'
$f.Controls.Add($pbDay)
$lDay = New-Object Windows.Forms.Label
$lDay.Location = New-Object Drawing.Point(12, ($winH - 60)); $lDay.Size = New-Object Drawing.Size(($winW - 24), 22); $lDay.Anchor = 'Bottom,Left,Right'
$lDay.Text = 'Heute: ...'
$f.Controls.Add($lDay)
$lStatus = New-Object Windows.Forms.Label
$lStatus.Location = New-Object Drawing.Point(12, ($winH - 36)); $lStatus.Size = New-Object Drawing.Size(($winW - 150), 30); $lStatus.Anchor = 'Bottom,Left,Right'
$lStatus.ForeColor = [Drawing.Color]::DarkGreen
$lStatus.Text = 'Aenderungen werden sofort automatisch gespeichert.'
$f.Controls.Add($lStatus)
$bClose = New-Object Windows.Forms.Button
$bClose.Text = 'Schliessen'; $bClose.Location = New-Object Drawing.Point(($winW - 122), ($winH - 40)); $bClose.Size = New-Object Drawing.Size(110, 34); $bClose.Anchor = 'Bottom,Right'
$f.Controls.Add($bClose)
$bClose.Add_Click({ if ($script:savePending) { Invoke-PendingSave }; $f.Close() })

function Update-DayBar {
    try {
        $s = Get-Content $StatusFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $p = [Math]::Max(0, [Math]::Min(100, [int]$s.pct))
        $pbDay.Value = $p
        if ([int]$s.rest -ge 0) { $lDay.Text = ('Heute: {0} % ausgelastet   |   noch {1} Min bis zum Grenzwert' -f $p, [int]$s.rest) }
        else { $lDay.Text = 'Heute: Ueberwachung ist aus' }
    } catch { $lDay.Text = 'Heute: Status nicht verfuegbar' }
}

function Save-Ui {
    try {
        @{ FontSize = [int]$script:uiFont; Width = [int]$f.ClientSize.Width; Height = [int]$f.ClientSize.Height } | ConvertTo-Json -Compress | Out-File $UiFile -Encoding ascii
    } catch { }
}
function Set-UiFont([int]$size) {
    $script:uiFont = [Math]::Max(9, [Math]::Min(13, $size))
    $f.Font = New-Object Drawing.Font('Segoe UI', $script:uiFont)
    Save-Ui
}
$cbSize.Add_SelectedIndexChanged({ Set-UiFont (9 + $cbSize.SelectedIndex) })
$f.Add_ResizeEnd({ Save-Ui })
$f.Add_FormClosing({ Save-Ui })

# ===== Tests starten =====
function Get-KidSession {
    $diag = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Dir 'Sperre.ps1') -Diag)
    foreach ($l in $diag) { if ($l -match '^\s*(\d+)\s+0\s+(\S+)\s+\d+\s*$' -and $Matches[2] -ne 'Verwalter') { return [int]$Matches[1] } }
    return $null
}
$script:testNames = @{ full = 'Komplett-Diagnose, ca. 2,5 Minuten'; term = 'Konsole schnell, ca. 3 Minuten'; glitch = 'Grafik-Vorschau, ca. 2,5 Minuten'; warn = 'alle Meldungen und dann die Komplett-Diagnose, ca. 3,5 Minuten'; nvkid = 'NVIDIA-Anzeige' }
function Start-KsTest([string]$which, [switch]$DryRun) {
    $zt = '"' + (Join-Path $Dir 'Zerotest.ps1') + '"'
    $base = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File')
    $a = $null; $msg = ''
    switch ($which) {
        'full'   { $a = $base + $zt;                    $msg = 'Komplett-Diagnose gestartet (ca. 2,5 Min auf dem Bildschirm des Zielkontos).' }
        'term'   { $a = $base + $zt + '-Interlude';     $msg = 'Konsolen-Test gestartet (ca. 3 Min auf dem Bildschirm des Zielkontos).' }
        'glitch' { $a = $base + $zt + '-GlitchPreview'; $msg = 'Grafik-Vorschau gestartet (ca. 2,5 Min auf dem Bildschirm des Zielkontos).' }
        'warn'   { $a = $base + $zt + '-Warnings';      $msg = 'Meldungen-Test gestartet (ca. 3,5 Min auf dem Bildschirm des Zielkontos).' }
        'nvme'   { $a = $base + ('"' + $NvBarFile + '"'); $msg = 'NVIDIA-Anzeige bei Ihnen geoeffnet.' }
        'nvkid'  { }
        default  { return 'Unbekannter Test.' }
    }
    if ($DryRun) { if ($which -eq 'nvkid') { return 'SYSTEM-Aufgabe: Sperre.ps1 -TestNvBar -SessionId <Zielkonto>' }; return ('powershell.exe ' + ($a -join ' ')) }
    try {
        if ($which -eq 'nvkid') {
            $sid = Get-KidSession
            if ($null -eq $sid) { return 'Kein aktives Zielkonto gefunden (ist gerade jemand angemeldet?).' }
            $act = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -ExecutionPolicy Bypass -File "{0}\Sperre.ps1" -TestNvBar -SessionId {1}' -f $Dir, $sid)
            $pri = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
            Register-ScheduledTask -TaskName 'KS-NvBar-Test' -Action $act -Principal $pri -Force | Out-Null
            Start-ScheduledTask -TaskName 'KS-NvBar-Test'
            Start-Sleep -Seconds 4
            Unregister-ScheduledTask -TaskName 'KS-NvBar-Test' -Confirm:$false -ErrorAction SilentlyContinue
            return 'NVIDIA-Anzeige auf dem Zielkonto geoeffnet.'
        }
        Start-Process -FilePath 'powershell.exe' -ArgumentList $a -WindowStyle Hidden | Out-Null
        return $msg
    } catch { return 'Test konnte nicht gestartet werden: ' + $_ }
}
function Invoke-TestWithConfirm([string]$which) {
    if ($which -in 'full', 'term', 'glitch', 'warn', 'nvkid') {
        $ans = [Windows.Forms.MessageBox]::Show(('Dieser Test laeuft auf dem Bildschirm des Zielkontos ({0}). Jetzt starten?' -f $script:testNames[$which]), 'Diagnose starten', 'YesNo', 'Question')
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
Update-DayBar
$script:dayTimer = New-Object Windows.Forms.Timer
$script:dayTimer.Interval = 5000
$script:dayTimer.Add_Tick({ Update-DayBar })
$script:dayTimer.Start()

# Erst NACH dem Aufbau anhaengen, damit das Befuellen der Felder kein Speichern ausloest
foreach ($c in @($nWd, $nWe, $nGr, $nBo, $nRs, $nIdle, $nGl, $nRgPer, $nRgMin, $nRgMax, $nScale, $nTmin, $nTmax, $nTdur)) { $c.Add_ValueChanged({ Request-Save; Update-NvPreview }) }
foreach ($c in (@($cEn, $cKill, $cKey, $cPinG, $cRgEn, $cRgOff, $cRgLock, $cLook, $cEndLogo, $cTicker, $cOutro) + @($warnChecks.Values) + $rbGroup)) { $c.Add_CheckedChanged({ Request-Save; Update-NvPreview }) }
foreach ($c in @($tbTitle, $tbNote)) { $c.Add_TextChanged({ Request-Save; Update-NvPreview }) }
foreach ($c in @($tbRep1, $tbRep2)) { $c.Add_TextChanged({ Request-Save; Update-ErrPreview }) }
$cbFont.Add_SelectedIndexChanged({ Request-Save; Update-ErrPreview })
$tbSample.Add_ValueChanged({ Update-NvPreview })

[void]$f.ShowDialog()
