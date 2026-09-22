# Zero: Kindersperre SOFORT ausloesen (ohne den Tageszaehler der Kinder zu aendern). Zerooff hebt sie wieder auf.
# Wirkt ueber die Merkerdatei force.flag; Sperre.ps1 startet daraufhin den Sperrbildschirm in den Kinder-Sitzungen
# (nicht in Verwalter/ExcludeUsers). Ablauf: Bildfehler -> Bluescreen -> Logo -> Reparatur.
param([switch]$Kill)   # -Kill = wie beim echten Limit auch alle Programme der Sitzung beenden (Zerokill)
$ErrorActionPreference = 'Stop'
$D = 'C:\ProgramData\Kindersperre'
$since = Get-Date
# Absturz-Ablauf soll komplett laufen (sonst springt er wegen des Tagesmarkers direkt zum Logo)
Get-ChildItem $D -Filter 'crash-*.txt' -ErrorAction SilentlyContinue | ForEach-Object { [IO.File]::Delete($_.FullName) }
(('zero' + $(if ($Kill) { ' kill' } else { '' })) + ' ' + (Get-Date -Format 's')) | Out-File (Join-Path $D 'force.flag') -Encoding ascii
Start-ScheduledTask -TaskName 'Kindersperre'
$log = Join-Path $D 'log.txt'
$hit = $null
for ($i = 0; $i -lt 25 -and -not $hit; $i++) {
    Start-Sleep -Seconds 1
    $hit = Get-Content $log -Tail 12 -ErrorAction SilentlyContinue | Where-Object { $_ -match 'Sperrbildschirm fuer Sitzung' -and [datetime]::Parse($_.Substring(0, 19)) -ge $since.AddSeconds(-2) }
}
if ($hit) { 'Sperre ausgeloest: ' + ($hit -join ' | ') } else { 'force.flag gesetzt; Sperre startet spaetestens mit dem naechsten Minutenlauf (oder es ist keine Kinder-Sitzung aktiv).' }
