# Kindersperre (privates Backup)

Eigene Bildschirmzeit-Kindersicherung fuer den Familien-PC `cenks-pc`, gebaut mit Claude Code.
Dieses Repository ist **privat** und dient nur als Sicherung fuer den Besitzer/Administrator (Konto Verwalter).

**[English version: README.en.md](README.en.md)**

## Ausgangslage

Konten: **Verwalter** (einziger Administrator, Passwort nur ihm bekannt), **Öztunc** (Konto, auf dem gespielt und
auch vom Erwachsenen selbst genutzt wird) und **Schwester** (Kinderkonto, Autologon ohne Passwort). Die Sperre
zaehlt Bildschirmzeit fuer alle Konten ausser Verwalter zusammen (`zeit.json`, PC-weit) und begrenzt sie pro Tag.

## Ablauf, wenn das Limit erreicht ist

1. **Vorwarnungen** vorher als System-Meldungen, getarnt als "NVIDIA Grafiktreiber"-Warnung (Standard: 45/30/20/15/5/1
   Minuten vor der Sperre, in diesem Stand auf 15 und 1 Minute reduziert, siehe `config.json`).
2. **Bildfehler und Schwarzbild** auf dem echten Desktop (kurze Ubergangsphasen).
3. **Bluescreen**, an Windows 10 angelehnt (Stop-Code `VIDEO_TDR_FAILURE`, echter Name und PCI-ID der verbauten
   NVIDIA-Grafikkarte, QR-Code, Sad-Face-Symbol).
4. **Windows-Logo** mit Ladepunkten, danach **"Automatische Reparatur wird vorbereitet"** und
   **"Diagnose des PCs wird ausgefuehrt"**.
5. Alle 8 bis 14 Minuten (zufaellig, aus einem Tagesschluessel abgeleitet) fuer 2 Minuten ein **Terminal-Bildschirm**:
   kein Countdown, sondern ein Wiederherstellungsversuchs-Zaehler ("Wiederherstellungsversuch N von 30"), dessen
   30 Versuche ueber die tatsaechliche Sperrdauer bis zum naechsten Tageswechsel (Reset-Uhrzeit) verteilt sind.
   Jeder Versuch endet mit `FEHLGESCHLAGEN (0xC000009A)`, der letzte mit `ERFOLGREICH`.
6. Am Ende (Tageswechsel oder aufgehobene Sperre): kurz Schwarzbild, dann Logo, dann normaler Desktop.

Waehrend der gesamten Sperre ist die Tastatur gesperrt (Windows-Taste, Alt+Tab, Strg+Alt+Tab, Strg+Esc,
Strg+Umschalt+Esc). Strg+Alt+Entf kann Windows selbst nicht sperren, das bleibt immer moeglich.

## Geheimtasten (nur waehrend einer laufenden Sperre)

Nichts davon wird irgendwo gespeichert oder protokolliert.

| Kombination | Wirkung |
|---|---|
| Leertaste + F12 + Alt | Zeigt fuer 30 s ein verstecktes PIN-Feld |
| F11 + F12 | Schaltet von Hand fuer 2 Minuten in den Terminal-Bildschirm (nur bei Logo/Reparatur) |
| F1 + F12 | Schaltet den Grafikfehler-Effekt (siehe unten) aus/an |
| Z + F12 | Zeigt ca. 6 s lang die geschaetzte Restzeit bis zum Sperrende (nur bei Logo/Reparatur/Terminal) |

## PIN und Grafikfehler-Modus

Eine richtige PIN im versteckten Feld gibt +60 Minuten Bonuszeit und schaltet danach bis zum naechsten
Tageswechsel einen **Grafikfehler-Modus** ein: ein durchsichtiges, klick-durchlaessiges Fenster ganz oben,
das mit `SetWindowDisplayAffinity` aus normalen Bildschirmaufnahmen ausgeschlossen ist und Stoerungen
**aus dem echten, aktuellen Bildschirminhalt** erzeugt (Zerreissen, Klotzbildung, abrutschende Bildteile,
Kachelmuell, Zeilenausfaelle, vertauschte Farben). Die Staerke baut sich nach der PIN ueber ca. 40 Sekunden
auf und waechst danach in festen Stufen weiter, je laenger die Bonuszeit her ist.

**Anfallsschutz (bewusst nicht lockerbar):** Wechsel hoechstens ca. 1,4 pro Sekunde, kaum reine Rottoene,
Flaeche mit starker Helligkeitsaenderung gegenueber dem echten Bild unter 25 % (gemessen maximal 22,9 %).

Weil dieser Effekt den echten Bildschirminhalt verwendet, gibt es dafuer bewusst **kein Beispielbild** in
diesem Repository (siehe Abschnitt "Absichtlich nicht enthalten").

## NVIDIA-Statusanzeige

Ein einfaches, freiwilliges Anzeigefenster (`NvBar.ps1`), das nur einen Balken und die Aufschrift "NVIDIA"
zeigt. Es liegt in einem eigenen, **oeffentlich lesbaren** Ordner (`C:\ProgramData\NVIDIA Corporation\NvContainer`),
getrennt vom geschuetzten Kindersperre-Ordner, damit auch Standardbenutzer es oeffnen koennen. `Sperre.ps1`
schreibt dort jede Minute einen reinen Prozentwert (verbrauchte Zeit von der Tagesgrenze) hinein, mehr nicht.
Das Fenster ist oben rechts, immer im Vordergrund, oeffnet sich automatisch bei der 15-Minuten-Warnung und
laesst sich jederzeit von Hand oeffnen oder schliessen (Verknuepfung auf dem Desktop). Bei echtem Vollbild
mancher Spiele ist es wie jedes andere Overlay-Fenster unter Umstaenden nicht sichtbar (Windows-Grenze).

## Konten und Rechte

`Sperre.ps1` laeuft als geplante SYSTEM-Aufgabe jede Minute und startet bei erreichtem Tageslimit
`Bildschirm.ps1` als Vollbild-Overlay direkt in der jeweiligen Benutzersitzung (per WTS-Sitzungstechnik,
ohne dass sich jemand extra anmelden muesste). Beim Absturz werden Programme mit Fenster in der betroffenen
Sitzung beendet (`KillApps`), nie bei Verwalter, nie Installer oder laufende Installationen. Der Ordner
`C:\ProgramData\Kindersperre` ist nur fuer SYSTEM und Administratoren zugaenglich.

## Befehle (Verwalter, per Wort an die steuernde Claude-Code-Sitzung)

| Befehl | Wirkung |
|---|---|
| `Zerotest` | Kompletter Testlauf (Bildfehler, Bluescreen, Logo, Reparatur, Terminal, Abschluss), ca. 2,5 Min, ohne den echten Zaehler zu beeinflussen |
| `Zerofull` | Wie oben, aber vorher alle Vorwarnungen nacheinander |
| `Zeroterm` | Zeitraffer-Vorschau der automatischen Terminal-Auftritte |
| `Zeroglitch` | Vorschau des Grafikfehler-Modus im Endstand |
| `Zero` | Loest die Sperre sofort aus, ohne den Tageszaehler zu aendern |
| `Zerokill` | Wie `Zero`, beendet zusaetzlich alle Programme mit Fenster in der Kindersitzung |
| `Zerooff` | Hebt eine per `Zero` ausgeloeste Sperre wieder auf |

## Konfiguration (`config.json`)

Tageslimits fuer Wochentag/Wochenende, Reset-Uhrzeit, Nachspielzeit ("Grace"), Bonuszeit per PIN,
ausgenommene Benutzer, sowie Ein/Aus-Schalter fuer einzelne Funktionen. Die `*.bak-vor-*`-Dateien sind
Sicherungen fruehrerer Versionen der Skripte, jeweils direkt vor einer einzelnen Aenderung angelegt
(kompletter Entwicklungsverlauf nachvollziehbar).

## Screenshots

Aus einem Testlauf vom 22.09.2026, aktueller Stand (rein synthetisch erzeugt, kein echter Bildschirminhalt).

![Bluescreen-Ansicht](shot-bsod.png)
*An einen echten Windows-10-Absturz angelehnte Bluescreen-Ansicht, mit echten Angaben zur verbauten Grafikkarte.*

![Logo-Ansicht](shot-logo.png)
*Windows-Logo mit Ladepunkten nach dem Bluescreen.*

![Reparatur-Ansicht](shot-repair.png)
*"Diagnose des PCs wird ausgefuehrt" - Zwischenschritt vor dem periodischen Terminal-Bildschirm.*

![Terminal-Ansicht](shot-terminal.png)
*Terminal-Bildschirm mit Wiederherstellungsversuchs-Zaehler (N von 30) auf einer Zeitachse, kein Countdown.*

## Absichtlich NICHT in diesem Repository (siehe .gitignore)

- `pin.json` / `Set-PIN.ps1` (PIN-Hash bzw. das Skript, das ihn setzt) - wird grundsaetzlich nie ausgegeben.
- Echte Nutzungsdaten: `zeit.json`, Protokolle, Verlaufsdateien, tagesaktuelle Registry-Sicherungen.
- Ein Beispielbild des Grafikfehler-Modus: Der zeigt per Konstruktion immer den echten, aktuellen
  Bildschirminhalt der Person, die gerade gesperrt ist - dafuer gibt es keine Variante ohne echten Inhalt.

## Kontext und Grenzen

Eigener PC, eigenes Administrator-Konto, Kindersicherung fuer die eigenen Kinder mit deren Wissen ueber die
Existenz der Sperre. Kein Netzwerkzugriff, keine Tastatureingaben-Aufzeichnung, keine dauerhafte
Bildspeicherung ausser in ausdruecklich angeforderten Testlaeufen. Der Administrator hat jederzeit Zugang
(verstecktes PIN-Feld, eigenes Konto, Strg+Alt+Entf). Weitere Details und der vollstaendige
Entwicklungsverlauf stehen als Kommentare direkt in den Skripten.
