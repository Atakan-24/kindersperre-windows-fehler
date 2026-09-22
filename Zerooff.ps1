# Zerooff: hebt die per Zero ausgeloeste Sperre wieder auf. Der Sperrbildschirm spielt kurz den "Neustart" und schliesst sich.
# Ist das ECHTE Tageslimit erreicht, bleibt die Sperre bestehen (das hier ist kein Bonus) - das wird gemeldet.
$ErrorActionPreference = 'Stop'
$D = 'C:\ProgramData\Kindersperre'
$flag = Join-Path $D 'force.flag'
$was = Test-Path $flag
if ($was) { [IO.File]::Delete($flag) }
$cfg = Get-Content (Join-Path $D 'config.json') -Raw | ConvertFrom-Json
$z = Get-Content (Join-Path $D 'zeit.json') -Raw | ConvertFrom-Json
$diag = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $D 'Sperre.ps1') -Diag) -join "`n"
$lockAt = $null
if ($diag -match 'Bonus heute: (\d+(?:[.,]\d+)?) Min \| Limit: (\d+(?:[.,]\d+)?)') {
    $lockAt = [double]($Matches[1] -replace ',', '.') + [double]($Matches[2] -replace ',', '.') + [double]$cfg.GraceMin
}
if ($was) { 'force.flag entfernt.' } else { 'Es war keine Zero-Sperre aktiv (force.flag fehlte).' }
if ($lockAt -and [double]$z.minutes -ge $lockAt) {
    'ACHTUNG: Das echte Tageslimit ist erreicht ({0:N0} von {1:N0} Min). Die Sperre bleibt deshalb bestehen; sie endet erst mit Bonus oder Tageswechsel.' -f $z.minutes, $lockAt
} else {
    'Der Sperrbildschirm schliesst sich in ca. 10-15 Sekunden (kurzer Neustart-Abschluss).'
}
