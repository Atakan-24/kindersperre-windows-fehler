# Richtet die Aufgabe "Claude-Verwalter-Autostart" ein: beim PC-Start (1 Minute Verzoegerung) laeuft Claude-Start.ps1 als
# Verwalter, unsichtbar und auch ohne angemeldeten Benutzer. Windows braucht dafuer EINMAL das Verwalter-Passwort.
# Das Passwort fragt schtasks selbst ab (Eingabe unsichtbar); es steht in keiner Datei und in keinem Skript und wird von
# Windows geschuetzt im Aufgabenplaner abgelegt. Nur Administratoren koennen die Aufgabe aendern oder loeschen.
$ErrorActionPreference = 'Stop'
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Bitte als Administrator (Verwalter) starten.' -ForegroundColor Red; Read-Host 'Enter zum Schliessen'; exit 1
}
if (-not (Test-Path 'C:\ProgramData\Kindersperre\Claude-Start.ps1')) {
    Write-Host 'Claude-Start.ps1 fehlt - nichts eingerichtet.' -ForegroundColor Red; Read-Host 'Enter zum Schliessen'; exit 1
}
$user = "$env:COMPUTERNAME\Verwalter"
$xml = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><Description>Startet die Verwalter-Claude-Sitzung unsichtbar beim PC-Start (Kindersperre)</Description></RegistrationInfo>
  <Triggers><BootTrigger><Enabled>true</Enabled><Delay>PT1M</Delay></BootTrigger></Triggers>
  <Principals><Principal id="Author"><LogonType>Password</LogonType><RunLevel>HighestAvailable</RunLevel></Principal></Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <StartWhenAvailable>true</StartWhenAvailable>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Enabled>true</Enabled>
  </Settings>
  <Actions Context="Author"><Exec><Command>powershell.exe</Command><Arguments>-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\ProgramData\Kindersperre\Claude-Start.ps1"</Arguments></Exec></Actions>
</Task>
'@
$f = Join-Path $env:TEMP 'claude-autostart.xml'
[IO.File]::WriteAllText($f, $xml, [Text.Encoding]::Unicode)
Write-Host ''
Write-Host 'Gleich wird nach dem VERWALTER-Passwort gefragt (Eingabe bleibt unsichtbar), dann Enter.' -ForegroundColor Cyan
Write-Host ''
schtasks /create /tn 'Claude-Verwalter-Autostart' /xml $f /ru $user /rp * /f
$rc = $LASTEXITCODE
[IO.File]::Delete($f)
Write-Host ''
if ($rc -eq 0) {
    Write-Host 'Fertig: Claude startet ab jetzt mit dem PC (1 Minute nach dem Hochfahren) unsichtbar unter Verwalter.' -ForegroundColor Green
    Write-Host 'Entfernen: schtasks /delete /tn "Claude-Verwalter-Autostart" /f' -ForegroundColor Gray
} else {
    Write-Host 'Das hat nicht geklappt (falsches Passwort?). Es wurde nichts eingerichtet.' -ForegroundColor Red
}
Read-Host 'Enter zum Schliessen'
