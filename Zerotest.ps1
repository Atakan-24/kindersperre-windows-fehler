# Zerotest: kompletter Testlauf des Sperrbildschirms (Bildfehler, Bluescreen, Logo, Reparatur, Neustart-Abschluss)
# in der aktiven Sitzung (nie Verwalter), auch wenn dieser Benutzer vom Limit ausgenommen ist. Dauert ca. 2 Minuten,
# schliesst sich selbst, bucht keinen Bonus, Programme-beenden ist im Test aus.
# -GlitchPreview zeigt gleich den Endstand (als waeren 24 Minuten vergangen)
# -GlitchPreview = nur die Vorschau des Grafikfehler-Modus (wie nach der Bonus-PIN), 150 s (baut sich auf, F1+F12 klingt ca. 25 s ab / kommt ca. 25 s zurueck), Bild in shot-glitch.png; F1+F12 blendet ihn aus/ein
# -Interlude = Zeitraffer-Vorschau des automatischen Terminal-Auftritts (alle 20-30 s statt 8-14 min, je 12 s statt 2 min), ca. 2,5 min, Bild in shot-term.png
# -Warnings  = vorher ALLE Vorwarnungen nacheinander zeigen (45/30/20/15/5/1 Min, je 7 s) = "Zerofull"
# -KillTest notepad = im Test nur diesen Prozess beenden (Pruefung der Programm-Beenden-Funktion)
# Tastensperre (Win, Alt+Tab, Strg+Alt+Tab, Strg+Esc ...) ist im Test wie in der echten Sperre AN; -NoKeys schaltet sie ab.
# Laeuft ueber einmalige SYSTEM-Aufgaben und raeumt danach auf.
param([int]$Seconds = 130, [double]$OutroAt = 100, [string]$KillTest = '', [switch]$Warnings, [switch]$GlitchPreview, [switch]$Interlude, [switch]$NoKeys)
$ErrorActionPreference = 'Stop'
$D = 'C:\ProgramData\Kindersperre'
$diag = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $D 'Sperre.ps1') -Diag)
$sid = $null
foreach ($l in $diag) {
    if ($l -match '^\s*(\d+)\s+0\s+(\S+)\s+\d+\s*$' -and $Matches[2] -ne 'Verwalter') { $sid = [int]$Matches[1]; break }
}
if ($null -eq $sid) { 'Keine aktive Benutzer-Sitzung gefunden - Abbruch.'; return }
if (($diag -join "`n") -match ('Sitzung {0}: Overlay laeuft = True' -f $sid)) { "In Sitzung $sid laeuft schon ein Sperrbildschirm - Abbruch."; return }

function Start-SysTask([string]$argLine) {
    $act = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argLine
    $pri = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName 'KS-Einmaltest' -Action $act -Principal $pri -Force | Out-Null
    Start-ScheduledTask -TaskName 'KS-Einmaltest'
}
function Clear-Flags { foreach ($f in 'overlay.log', 'outro.flag', 'keytest.flag', 'killtest.flag', 'glitch.flag', 'interlude.flag', 'attempts.flag', 'speed.txt') { if (Test-Path (Join-Path $D $f)) { [IO.File]::Delete((Join-Path $D $f)) } } }

Clear-Flags
try {
    if ($Warnings) {
        'Warnungen laufen in Sitzung {0} ab {1} (6 Meldungen, ca. 45 s).' -f $sid, (Get-Date -Format 'HH:mm:ss')
        Start-SysTask ('-NoProfile -ExecutionPolicy Bypass -File "{0}\Sperre.ps1" -DemoWarnings -SessionId {1} -Gap 7' -f $D, $sid)
        Start-Sleep -Seconds 3
        $w = 0
        while ((Get-ScheduledTask -TaskName 'KS-Einmaltest').State -eq 'Running' -and $w -lt 90) { Start-Sleep -Seconds 2; $w += 2 }
        Start-Sleep -Seconds 4
    }
    $shotArg = ''
    if (-not $NoKeys) { 'test' | Out-File (Join-Path $D 'keytest.flag') -Encoding ascii }
    if ($GlitchPreview) { $Seconds = 150; '24' | Out-File (Join-Path $D 'glitch.flag') -Encoding ascii; $shotArg = ' -Shot "' + $D + '\shot-glitch.png"' }
    else {
        if ($Interlude) { $OutroAt = 140; $Seconds = 170; '20 30 12' | Out-File (Join-Path $D 'interlude.flag') -Encoding ascii; '140' | Out-File (Join-Path $D 'attempts.flag') -Encoding ascii; $shotArg = ' -Shot "' + $D + '\shot-term.png"' }
        ([string]$OutroAt) | Out-File (Join-Path $D 'outro.flag') -Encoding ascii
    }
    if ($KillTest) { $KillTest | Out-File (Join-Path $D 'killtest.flag') -Encoding ascii }
    Start-SysTask ('-NoProfile -ExecutionPolicy Bypass -File "{0}\Sperre.ps1" -TestOverlay -SessionId {1} -Seconds {2}{3}' -f $D, $sid, $Seconds, $shotArg)
    'Sperrbildschirm-Test gestartet in Sitzung {0} um {1} (dauert ca. {2} s).' -f $sid, (Get-Date -Format 'HH:mm:ss'), [int]($OutroAt + 10)
    $end = (Get-Date).AddSeconds($Seconds + 20)
    while ((Get-Date) -lt $end) {
        if ((Test-Path (Join-Path $D 'overlay.log')) -and ((Get-Content (Join-Path $D 'overlay.log') -Raw) -match 'Gesperrte Tastenereignisse')) { break }
        Start-Sleep -Seconds 3
    }
    if (Test-Path (Join-Path $D 'overlay.log')) { Get-Content (Join-Path $D 'overlay.log') | Where-Object { $_ -match 'Phase:|Fehler|fertig|Outro|schliesse|beendet|nicht beendet|Grafikfehler|Terminal|Auftritt|Gesperrte|Zeichenfehler|Textfehler|Terminal-Zeichnen|Zeichenflaeche|Restzeit' } }
} finally {
    Unregister-ScheduledTask -TaskName 'KS-Einmaltest' -Confirm:$false -ErrorAction SilentlyContinue
    Clear-Flags
}
