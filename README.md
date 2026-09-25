# Kindersperre (privates Backup)

Eigene Bildschirmzeit-Kindersicherung für den Familien-PC `cenks-pc`, gebaut mit Claude Code.
Dieses Repository ist **privat** und dient nur als Sicherung für den Besitzer/Administrator (Konto Verwalter).

**[English version: README.en.md](README.en.md)**

## Inhalt

1. [Ausgangslage](#ausgangslage)
2. [Ablauf, wenn das Limit erreicht ist](#ablauf-wenn-das-limit-erreicht-ist)
3. [Kindersperre-Verwaltung (Einstellungs-Fenster)](#kindersperre-verwaltung-einstellungs-fenster)
4. [NVIDIA-Anzeige](#nvidia-anzeige)
5. [Erholung](#erholung)
6. [Geheimtasten, PIN, Grafikfehler-Modus](#geheimtasten-pin-grafikfehler-modus)
7. [Befehle](#befehle)
8. [Alle Einstellungen (`config.json`)](#alle-einstellungen-configjson)
9. [Sicherheit](#sicherheit)
10. [Screenshots](#screenshots)
11. [Nicht in diesem Repository](#nicht-in-diesem-repository)

## Ausgangslage

Konten: **Verwalter** (einziger Administrator), **Öztunc** (Konto, auf dem gespielt und auch vom Erwachsenen
selbst genutzt wird) und **Schwester** (Kinderkonto). Die Sperre zählt die Bildschirmzeit aller Konten außer
Verwalter zusammen (`zeit.json`, PC-weit) und begrenzt sie pro Tag. `Sperre.ps1` läuft als geplante
SYSTEM-Aufgabe jede Minute und startet bei erreichtem Limit `Bildschirm.ps1` als Vollbild in der jeweiligen
Benutzersitzung (WTS-Sitzungstechnik, ohne dass sich jemand extra anmelden müsste).

## Ablauf, wenn das Limit erreicht ist

1. **Vorwarnungen** als System-Meldungen, getarnt als „NVIDIA Grafiktreiber"-Warnung. Standard: 15 Minuten und
   1 Minute vor der Sperre (im Einstellungs-Fenster wählbar aus 45/30/20/15/5/1).
2. **Bildfehler und Schwarzbild** auf dem echten Desktop (kurze Übergangsphasen).
3. **Bluescreen** im Stil von Windows 10 (`VIDEO_TDR_FAILURE`, echter Name der verbauten Grafikkarte, QR-Code).
4. **Windows-Logo** mit Ladepunkten, danach **„Automatische Reparatur wird vorbereitet"** und
   **„Diagnose des PCs wird ausgeführt"** (beide Sätze einstellbar).
5. Alle 8 bis 14 Minuten für 2 Minuten ein **Terminal-Bildschirm** mit einem Wiederherstellungsversuchs-Zähler
   („Versuch N von 30", keine Uhrzeit, kein Countdown), verteilt über die tatsächliche Sperrdauer bis zum
   Tageswechsel. Abstand, Dauer und Schrift sind einstellbar.
6. Am Ende (Tageswechsel oder aufgehobene Sperre): kurz Schwarz, Logo, dann Desktop.

Während der Sperre ist die Tastatur gesperrt (Windows-Taste, Alt+Tab, Strg+Alt+Tab, Strg+Esc,
Strg+Umschalt+Esc). Strg+Alt+Entf kann Windows selbst nicht sperren.

## Kindersperre-Verwaltung (Einstellungs-Fenster)

`KsAdmin.ps1` ist ein Fenster, in dem sich **alles einstellen lässt**, ohne Dateien zu bearbeiten.
Es liegt im geschützten Ordner `C:\ProgramData\Kindersperre` (nur SYSTEM und Administratoren), eine
Verknüpfung liegt nur auf dem Desktop von Verwalter. Kinder-Konten können es deshalb weder sehen noch öffnen
(geprüft: `Test-Path` liefert für Öztunc `False`).

- **Eigenes Werkzeug-Passwort**, unabhängig vom Windows-Passwort. Beim ersten Start legt man es selbst im
  Fenster fest (zweimal). Gespeichert wird nur ein PBKDF2-Hash (`tool-pin.json`, nicht in diesem Repository).
  Im Reiter *Passwort* lässt es sich jederzeit ändern (das alte Passwort wird dafür abgefragt).
- **Speichert sofort automatisch**, kurz nach jeder Änderung. Kein Speichern-Knopf nötig. Vor der ersten
  Änderung je Sitzung entsteht eine Sicherung von `config.json` (die letzten 20 bleiben).
- Änderungen an Limits, Ein/Aus usw. wirken auch bei einer **schon laufenden Sperre** (nach höchstens 5 Sekunden).

| Reiter | Was man einstellen kann |
|---|---|
| Limits | Limits Wochentag/Wochenende, Nachspielzeit, Bonus per PIN, Reset-Uhrzeit, Leerlauf-Grenze, **Sperre an/aus**, **heute sofort mehr/weniger Zeit** |
| Warnungen | Welche Vorwarnungen kommen (45/30/20/15/5/1 Minuten) |
| Programme | Programme bei Sperrstart beenden, Tastensperre, Grafikfehler-Modus nach PIN, Grafikfehler-Stufe |
| NVIDIA | Titel, Zusatztext, Zeile unter dem Balken, **Vorschau** mit Beispielwert-Regler, Test-Knöpfe |
| Fehleranzeige | Look, Endphase, Dateizeile, Neustart-Abschluss, **Reparatur-Sätze**, **Terminal-Schrift und -Größe**, **Terminal-Abstand und -Dauer**, Vorschau der Sätze und der Schrift |
| Erholung | siehe unten |
| Vorschau & Tests | Beispielbilder der Fehlerbildschirme und **Test-Knöpfe**: ganzer Ablauf, Terminal (Zeitraffer), Grafikfehler, Warnungen, NVIDIA-Anzeige (bei mir / in der Kindersitzung) |
| Passwort | Werkzeug-Passwort ändern |

Die Test-Knöpfe, die auf dem Bildschirm der Kindersitzung laufen, fragen vorher nach.

**„+ Mehr Zeit" / „− Weniger Zeit"** schreiben eine Zeitanpassung (`adjust.txt`), die `Sperre.ps1` beim
nächsten Lauf (höchstens 1 Minute) auf den Tageszähler anwendet. Negativ = mehr Zeit, positiv = weniger Zeit.

## NVIDIA-Anzeige

Ein kleines, freiwilliges Fenster (`NvContainer/NvBar.ps1`): Titel (Standard „NVIDIA"), Balken, optional eine
Zeile darunter (Prozent, Restzeit, verbraucht/Limit oder geschätzte Uhrzeit der Sperre) und ein frei wählbarer
Zusatztext. Es sitzt oben rechts, immer im Vordergrund, öffnet sich automatisch bei der frühesten eingestellten
Warnung und lässt sich jederzeit per Desktop-Verknüpfung öffnen oder mit X schließen.

`Sperre.ps1` schreibt jede Minute nur reine Zahlen und den Text in `status.json` in einen öffentlich **lesbaren**
Ordner (`C:\ProgramData\NVIDIA Corporation\NvContainer`), damit Standardbenutzer das Fenster ohne Zugriff auf
den geschützten Ordner nutzen können. Bei echtem Vollbild mancher Spiele ist ein solches Fenster wie jedes
andere Overlay unter Umständen nicht sichtbar (Windows-Grenze).

## Erholung

Nicht genutzte Zeit (Pause bei eingeschaltetem PC oder PC aus) gibt Minuten vom Tageslimit zurück. Alles
einstellbar, **standardmäßig ausgeschaltet** (Reiter *Erholung*, „Erholung aktiv"):

- Zurückgegeben je 60 Minuten Pause: Standard 30
- Pause muss mindestens so lang sein: Standard 10 Minuten
- Höchstens pro Tag zurück: Standard 120 Minuten (der Zähler geht nie unter 0)
- PC-aus-Zeit zählt auch als Pause: Standard ja
- Wirkt auch während einer laufenden Sperre: Standard nein

## Geheimtasten, PIN, Grafikfehler-Modus

Nur während einer laufenden Sperre, nichts wird gespeichert:

| Kombination | Wirkung |
|---|---|
| Leertaste + F12 + Alt | Zeigt 30 s ein verstecktes PIN-Feld |
| F11 + F12 | Terminal von Hand für 2 Minuten |
| F1 + F12 | Grafikfehler-Effekt aus/an |
| Z + F12 | Zeigt ca. 6 s die geschätzte Restzeit bis zum Sperrende |

Eine richtige PIN gibt +60 Minuten und schaltet bis zum Tageswechsel einen **Grafikfehler-Modus** ein: ein
durchsichtiges, klick-durchlässiges Fenster, das Störungen **aus dem echten Bildschirminhalt** erzeugt und aus
Bildschirmaufnahmen ausgeschlossen ist. **Anfallsschutz (nicht lockerbar):** höchstens ca. 1,4 Wechsel pro
Sekunde, kaum reine Rottöne, Fläche mit starker Helligkeitsänderung unter 25 %.

## Befehle

Per Wort an die steuernde Claude-Code-Sitzung (die Test-Knöpfe im Fenster machen dasselbe):

| Befehl | Wirkung |
|---|---|
| `Zerotest` | kompletter Testlauf, ca. 2,5 Min, ohne den echten Zähler zu ändern |
| `Zerofull` | wie oben, vorher alle Vorwarnungen |
| `Zeroterm` | Zeitraffer der Terminal-Auftritte |
| `Zeroglitch` | Vorschau des Grafikfehler-Modus |
| `Zero` / `Zerooff` | Sperre sofort auslösen / aufheben |
| `Zerokill` | wie `Zero`, beendet zusätzlich Programme in der Kindersitzung |

## Alle Einstellungen (`config.json`)

Reines ASCII (Sonderzeichen als `\uXXXX`). Fehlende Einträge gelten als Standard. Das Fenster schreibt sie.

| Schlüssel | Bedeutung (Standard) |
|---|---|
| `WeekdayLimitMin`, `WeekendLimitMin` | Tageslimit in Minuten (360 / 480) |
| `GraceMin` | Nachspielzeit (15) |
| `BonusMin` | Bonus per PIN (60) |
| `ResetHour` | Tageswechsel-Uhrzeit (6) |
| `IdleMin` | Leerlauf zählt nicht ab so vielen Minuten (5) |
| `Enabled` | `false` = kein Limit, keine Warnung, keine Sperre |
| `FreeDays`, `ExcludeUsers` | freie Wochentage / nicht gezählte Benutzer |
| `WarnMinutes` | Vorwarnungen, z. B. `[15,1]` |
| `KillApps`, `KillPauseUntil` | Programme beenden / Pause dafür bis Datum |
| `KeyLock`, `PinGlitch`, `GlitchLevel` | Tastensperre, Grafikfehler nach PIN, Stufe 1–3 |
| `Look`, `EndPhase`, `FileTicker`, `Outro` | Erscheinungsbild der Sperre |
| `RepairText1`, `RepairText2` | Reparatur-Sätze (leer = Standard) |
| `TermFont`, `TermFontScale` | Terminal-Schriftart und Größe in % der Automatik (50–100) |
| `TermMinGapSec`, `TermMaxGapSec`, `TermDurSec` | Terminal-Abstand (480–840 s) und Dauer (120 s) |
| `NvBarMode`, `NvBarTitle`, `NvBarNote` | NVIDIA-Anzeige: Modus, Titel, Zusatztext |
| `RegenEnabled`, `RegenPerHourMin`, `RegenMinPauseMin`, `RegenMaxPerDayMin`, `RegenCountOff`, `RegenWhileLocked` | Erholung |

Die `*.bak-vor-*`-Dateien sind Sicherungen früherer Versionen, jeweils direkt vor einer einzelnen Änderung
angelegt (Entwicklungsverlauf).

## Sicherheit

- Der Kindersperre-Ordner ist nur für SYSTEM und Administratoren zugänglich.
- Der öffentliche NVIDIA-Ordner erlaubt Standardbenutzern nur **Lesen und Ausführen**, kein Schreiben (sonst
  könnte ein Kind die Datei austauschen). Die NVIDIA-Anzeige wird als der **angemeldete Benutzer** gestartet,
  nicht als SYSTEM.
- Das Werkzeug-Passwort schützt das Fenster, **nicht** vor jemandem, der das Windows-Passwort von Verwalter kennt
  (der kann die Dateien direkt ändern). Das Windows-Passwort von Verwalter darf deshalb nicht weitergegeben werden.
- `pin.json` und `Set-PIN.ps1` werden grundsätzlich nie ausgegeben.

## Screenshots

Aus Testläufen, rein synthetisch (kein echter Bildschirminhalt).

![Bluescreen](shot-bsod.png)
![Logo](shot-logo.png)
![Reparatur](shot-repair.png)
![Terminal](shot-terminal.png)

Das Einstellungs-Fenster:

![Limits](docs/tool-limits.png)
![NVIDIA-Anzeige mit Vorschau](docs/tool-nvidia.png)
![Fehleranzeige](docs/tool-fehleranzeige.png)
![Erholung](docs/tool-erholung.png)
![Vorschau und Tests](docs/tool-tests.png)

## Nicht in diesem Repository

- `pin.json`, `Set-PIN.ps1`, `tool-pin.json` (PIN- bzw. Passwort-Hashes)
- echte Nutzungsdaten (`zeit.json`, Protokolle, Verlauf), tagesaktuelle Registry-Sicherungen
- ein Beispielbild des Grafikfehler-Modus: Er zeigt per Konstruktion immer den echten Bildschirminhalt.
