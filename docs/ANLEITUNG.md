# Anleitung: Einrichten, Einstellen, Aktivieren

[Zurück zur Übersicht](../README.md) · [Guide in English](GUIDE.en.md)

Diese Anleitung beschreibt, wie die Kindersperre aufgebaut ist, wie man sie **einstellt** und wie man sie **ein- und ausschaltet**.
Alles läuft unter Windows 10/11 mit Windows PowerShell 5.1.

> **Ehrlich vorab:** Der Abschnitt „Neu einrichten" beschreibt den Aufbau der vorhandenen Installation. Die Befehle dort sind nach
> dem Vorbild der laufenden Aufgabe zusammengestellt, aber auf diesem PC **nicht erneut ausgeführt** worden (die Installation
> läuft ja schon). Auf einem frischen PC bitte zuerst mit einem Testkonto probieren. Die PIN-Datei (`pin.json`) und das Werkzeug
> `Set-PIN.ps1` sind absichtlich nicht im Repository.

**Kontonamen:** Die Dokumentation verwendet neutrale Rollen. Die bestehenden Skripte setzen teilweise den Kontonamen `Verwalter` voraus; Details und Grenzen stehen in der [vollständigen Dokumentation](DOCUMENTATION.md#ausgangslage).

## 1. Im Alltag: das Einstellungs-Fenster

1. Auf dem Desktop von **Administrator** das Symbol **„Systemdiagnose"** doppelklicken (startet `KsAdmin.ps1`).
2. Beim ersten Start ein **Werkzeug-Passwort** festlegen (mindestens 4 Zeichen, unabhängig vom Windows-Passwort). Danach
   fragt das Fenster bei jedem Start danach.
3. Einstellungen ändern. **Es wird sofort automatisch gespeichert**, es gibt keinen Speichern-Knopf. Eine laufende Sperre
   übernimmt Änderungen nach höchstens 5 Sekunden.
4. Fenster schließen. Die Änderungen sind schon aktiv.

### Wichtigste Einstellungen

| Was | Wo | Hinweis |
|---|---|---|
| Tagesgrenzwert Mo–Fr / Sa–So | Reiter „Grenzwerte" | Standard 360 / 480 Minuten |
| Heute mehr oder weniger Zeit | Reiter „Grenzwerte", „+ Mehr" / „− Weniger" | wirkt beim nächsten Lauf (höchstens 1 Minute) |
| **Überwachung an/aus** | Reiter „Grenzwerte" | aus = keine Zählung, keine Warnung, keine Sperre |
| Welche Vorab-Meldungen | Reiter „Meldungen" | Standard: 15 und 1 Minute vorher |
| Programme beenden, Tastenschutz, Grafikfehler-Modus | Reiter „Prozesse" | |
| Text, Titel und Aussehen der NVIDIA-Anzeige | Reiter „NVIDIA" | mit Vorschau |
| Reparatur-Sätze, Terminal-Schrift/-Abstand/-Dauer | Reiter „Diagnose" | mit Vorschau |
| **Erholung** (ungenutzte Zeit gibt Minuten zurück) | Reiter „Abkühlung" | **standardmäßig an** |
| Beispielbilder ansehen, alles testen | Reiter „Vorschau" | Test-Knöpfe fragen vorher nach |
| Werkzeug-Passwort / Windows-Passwort / **Support-Code** (PIN am Fehlerbildschirm) ändern | Reiter „Zugriff" | Windows-Passwort und Support-Code nur mit dem aktuellen; Support-Code mind. 6 Zeichen, gilt sofort |
| Alle Tastenkürzel, Befehle und der Ablauf | Reiter „Hilfe" → Knopf „Info" | |
| Schriftgröße des Fensters | Reiter „Hilfe" | Größe: Fenster an den Rändern ziehen |

## 2. Ein- und ausschalten

| Ziel | So geht es |
|---|---|
| **Aktivieren** | Reiter „Grenzwerte": Überwachung **an**. Oder in `config.json` den Eintrag `"Enabled"` auf `true` setzen bzw. entfernen. Die geplante Aufgabe `Kindersperre` muss aktiviert sein (siehe unten). |
| **Vorübergehend ausschalten** | Reiter „Grenzwerte": Überwachung **aus** (oder `"Enabled": false`). Eine laufende Sperre endet dann nach höchstens 5 Sekunden. |
| **Ganz stoppen** | Als Administrator: `Disable-ScheduledTask -TaskName Kindersperre` |
| **Wieder starten** | `Enable-ScheduledTask -TaskName Kindersperre` |
| Sperre sofort auslösen | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\ProgramData\Kindersperre\Zero.ps1` (als Administrator; sperrt das ausgenommene Administratorkonto nie) |
| Sperre aufheben | `...\Zerooff.ps1` (ist der echte Grenzwert erreicht, bleibt sie bestehen; das Skript meldet es) |
| Komplett-Test (ohne den echten Zähler zu ändern) | Reiter „Vorschau" → „Komplett-Diagnose", oder `...\Zerotest.ps1` |

Prüfen, ob alles läuft: `Get-ScheduledTaskInfo -TaskName Kindersperre` (LastTaskResult 0) und die letzten Zeilen von
`C:\ProgramData\Kindersperre\log.txt`.

## 3. Die NVIDIA-Anzeige

- Sie öffnet sich automatisch bei der frühesten eingestellten Vorab-Meldung.
- Von Hand: Desktop-Verknüpfung **„NVIDIA"**, oder im Einstellungs-Fenster (Reiter „NVIDIA" / „Vorschau") „Bei mir zeigen".
- **Verschieben:** an einer beliebigen Stelle mit der Maus ziehen. **Größe:** an einem Rand (unten, rechts, links, oben) ziehen.
  Beides wird gemerkt. Ohne Zusatztext ist sie schlank, mit Text wird sie höher.
- Was unter dem Balken steht (nichts, Prozent, Restzeit, verbraucht/Grenzwert, Uhrzeit) und der Zusatztext: Reiter „NVIDIA".

## 4. Test, ohne jemanden zu stören

| Test | Wo | Was passiert |
|---|---|---|
| Komplett-Diagnose | Reiter „Vorschau" | ganzer Ablauf, ca. 2,5 Minuten, ändert den Zähler nicht |
| Konsole (schnell) | Reiter „Vorschau" | Zeitraffer der Terminal-Auftritte |
| Grafik | Reiter „Vorschau" | 60 s Vorschau des Grafikfehler-Modus |
| Meldungen | Reiter „Vorschau" | die Vorab-Meldungen nacheinander |
| NVIDIA bei mir | Reiter „Vorschau" / „NVIDIA" | zeigt die Anzeige nur auf dem eigenen Bildschirm |
| NVIDIA auf Zielkonto | Reiter „Vorschau" / „NVIDIA" | zeigt sie in der Sitzung des Kindes (fragt vorher nach) |

Die Tests laufen als einmalige SYSTEM-Aufgabe `KS-Einmaltest`, die danach gelöscht wird. Die Tastensperre ist im Test **an** (wie
echt).

## 5. Neu einrichten (Aufbau der vorhandenen Installation)

Alle Befehle in einer PowerShell **als Administrator**.

**Schritt 1: Ordner mit Schutz.** Nur SYSTEM und Administratoren dürfen hinein:

```powershell
$K = 'C:\ProgramData\Kindersperre'
New-Item -ItemType Directory -Force $K | Out-Null
icacls $K /inheritance:r /grant 'SYSTEM:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F'
```

**Schritt 2: Dateien kopieren.** Aus diesem Repository nach `C:\ProgramData\Kindersperre`: `Sperre.ps1`, `Bildschirm.ps1`,
`KsAdmin.ps1`, `Zero.ps1`, `Zerooff.ps1`, `Zerotest.ps1`, `IdleProbe.exe` (+ `IdleProbe.cs`), `config.json`, `assets\winlogo.png`.
`Sperre.ps1` und `Bildschirm.ps1` müssen **UTF-8 mit BOM und LF-Zeilenenden** bleiben (nicht mit einem Editor speichern, der das
ändert). Danach in `config.json` die Konten anpassen (`ExcludeUsers`: Konten, die nicht gezählt werden, mindestens der
Administrator; Sonderzeichen als `\uXXXX`).

**Schritt 3: Öffentlicher Ordner für die NVIDIA-Anzeige.** Benutzer dürfen dort nur lesen und ausführen:

```powershell
$N = 'C:\ProgramData\NVIDIA Corporation\NvContainer'
New-Item -ItemType Directory -Force $N | Out-Null
Copy-Item .\NvContainer\NvBar.ps1 $N
icacls $N /inheritance:r /grant 'SYSTEM:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-32-545:(OI)(CI)RX'
```

**Schritt 3b: PIN.** Die PIN für den Zusatz-Code (+60 Minuten) legt das lokale, nicht veröffentlichte Werkzeug `Set-PIN.ps1` an
(schreibt `pin.json` im Sperr-Ordner). Ohne `pin.json` gibt es keinen Zusatz-Code.

**Schritt 4: geplante Aufgabe.** So ist die vorhandene Aufgabe `Kindersperre` aufgebaut (SYSTEM, höchste Rechte, drei Auslöser,
Zeitlimit 2 Minuten, keine parallelen Läufe):

```powershell
$a  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\ProgramData\Kindersperre\Sperre.ps1"'
$t1 = New-ScheduledTaskTrigger -AtStartup
$t2 = New-ScheduledTaskTrigger -AtLogOn
$t3 = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration (New-TimeSpan -Days 3650)
$p  = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest -LogonType ServiceAccount
$s  = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 2) -MultipleInstances IgnoreNew -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName 'Kindersperre' -Action $a -Trigger $t1, $t2, $t3 -Principal $p -Settings $s
```

**Schritt 5: Desktop-Verknüpfungen (nur für den Administrator).** „Systemdiagnose" startet das Einstellungs-Fenster, „NVIDIA" die
Anzeige:

```powershell
$desk = [Environment]::GetFolderPath('Desktop'); $ws = New-Object -ComObject WScript.Shell
$l = $ws.CreateShortcut((Join-Path $desk 'Systemdiagnose.lnk'))
$l.TargetPath = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
$l.Arguments  = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\ProgramData\Kindersperre\KsAdmin.ps1"'
$l.WorkingDirectory = 'C:\ProgramData\Kindersperre'; $l.IconLocation = 'C:\Windows\System32\shell32.dll,44'; $l.Save()
```

**Schritt 6: prüfen.** `Start-ScheduledTask Kindersperre`, dann `Get-ScheduledTaskInfo Kindersperre` (Ergebnis 0) und
`log.txt` ansehen. Danach im Einstellungs-Fenster den Reiter „Vorschau" öffnen und die „Komplett-Diagnose" testen.

## 6. Wenn etwas nicht klappt

| Problem | Ursache / Lösung |
|---|---|
| Fenster meldet „Eigenschaft … nicht gefunden" | alte Fassung; die neue legt fehlende Einstellungen selbst an |
| Sperre kommt nicht | `Get-ScheduledTaskInfo Kindersperre`; ist die Aufgabe aktiv? Steht `Enabled` in `config.json` auf `false`? Ist `zeit.json` unter dem Grenzwert? |
| NVIDIA-Anzeige erscheint nicht | Nur bei erreichter Meldeschwelle oder von Hand; bei Vollbild-Spielen im exklusiven Modus zeigt Windows sie u. U. nicht |
| Ein Skript hat plötzlich Umlaut-Fehler | Datei ohne BOM gespeichert. `Sperre.ps1`/`Bildschirm.ps1` nur mit `UTF8Encoding($true)` schreiben |
| Nach Änderung im Editor läuft die Sperre nicht mehr | Vor jeder Änderung sichern (`*.bak-vor-<Grund>`), danach `Parser::ParseFile` prüfen |
| Windows-Passwort ändern schlägt fehl | Das aktuelle Passwort stimmt nicht oder die Passwortrichtlinie des PCs lehnt das neue ab |

## 7. Regeln, die man nicht lockern sollte

- Den Ordner `C:\ProgramData\Kindersperre` nur SYSTEM und Administratoren zugänglich lassen.
- Im öffentlichen NVIDIA-Ordner Benutzern **kein Schreibrecht** geben.
- Den Anfallsschutz des Grafikfehler-Effekts nicht lockern.
- Das Windows-Passwort des Administrators nicht weitergeben; PIN-Hash und `Set-PIN.ps1` nie veröffentlichen.
