# Startet beim PC-Start die Verwalter-Claude-Sitzung unsichtbar und MIT Remote Control (Steuerung per App) (Aufgabe "Claude-Verwalter-Autostart").
# Laeuft als Verwalter. Startet nichts doppelt: gibt es schon eine aktive Sitzung mit diesem Namen, passiert nichts.
# Die Sitzung tut von allein NICHTS ausser sich mit "bereit" zu melden; sie handelt nur, wenn der Nutzer ihr schreibt.
# Hinweis: "claude --bg" allein erzeugt KEINE App-Verbindung (geprueft). Darum eine interaktive Sitzung mit --remote-control in einer versteckten Konsole.
$ErrorActionPreference = 'Continue'
$c    = 'C:\Users\Verwalter\.local\bin\claude.exe'
$name = 'Kindersperre-Verwalter'
$log  = 'C:\ProgramData\Kindersperre\claude-start.log'
$sess = 'C:\Users\Verwalter\.claude\sessions'
function L($m) { ('{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) | Out-File $log -Append -Encoding ascii }
function Get-Mine {
    $r = @()
    foreach ($f in @(Get-ChildItem $sess -Filter '*.json' -ErrorAction SilentlyContinue)) {
        try { $j = Get-Content $f.FullName -Raw | ConvertFrom-Json } catch { continue }
        if ($j.name -eq $name -and (Get-Process -Id $j.pid -ErrorAction SilentlyContinue)) { $r += $j }
    }
    return $r
}
try {
    L 'Start-Skript laeuft'
    Set-Location 'C:\Windows\System32'
    # Netzwerk abwarten (bis 3 Minuten), sonst kann die Sitzung sich nicht anmelden
    for ($i = 0; $i -lt 36; $i++) { if (Test-Connection -ComputerName 1.1.1.1 -Count 1 -Quiet -ErrorAction SilentlyContinue) { break }; Start-Sleep -Seconds 5 }
    if (@(Get-Mine).Count -gt 0) { L 'Sitzung laeuft schon - nichts zu tun'; return }
    $prompt = 'Der PC wurde gerade gestartet. Du bist die Verwalter-Sitzung fuer die Kindersperre. Lies deine Anweisungen (CLAUDE.md) und antworte nur mit einem kurzen Wort: bereit. Tu sonst nichts, bis der Nutzer dir schreibt.'
    $p = Start-Process -FilePath $c -ArgumentList @('--remote-control', $name, '--name', $name, '--permission-mode', 'auto', $prompt) -WorkingDirectory 'C:\Windows\System32' -WindowStyle Hidden -PassThru
    L ('Sitzung gestartet: PID ' + $p.Id + ' (interaktiv, Remote Control angefordert)')
    # Kontrolle: nach bis zu 90 s nachsehen, ob die Sitzung lebt und mit der App verbunden ist (nur Protokoll)
    for ($i = 0; $i -lt 18; $i++) {
        Start-Sleep -Seconds 5
        $m = @(Get-Mine)
        if ($m.Count -gt 0 -and $m[0].bridgeSessionId) { L 'Remote Control aktiv: App-Verbindung vorhanden'; break }
        if (-not (Get-Process -Id $p.Id -ErrorAction SilentlyContinue)) { L 'WARNUNG: Sitzung wurde beendet'; break }
    }
    $m = @(Get-Mine)
    if ($m.Count -eq 0) { L 'WARNUNG: keine Sitzung gefunden' }
    elseif (-not $m[0].bridgeSessionId) { L 'WARNUNG: Sitzung laeuft, aber ohne App-Verbindung (Remote Control nicht aktiv)' }
} catch { L ('FEHLER: ' + $_) }
