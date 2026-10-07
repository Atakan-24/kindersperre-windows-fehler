# NVIADA Error save you kind

Ein Windows-System zur Bildschirmzeitverwaltung und Kindersicherung mit **PowerShell**, **Windows Task Scheduler/SYSTEM**, **WTS Session Handling**, **ACLs**, **Win32/.NET APIs**, **PBKDF2** und **JSON-Konfiguration**.

Systemweite Zeiterfassung läuft im Hintergrund; Status- und Sperroberflächen erscheinen in der aktiven Benutzersitzung. Entwickelt mit Unterstützung von Claude Code.

[English](README.en.md) · [Vollständige Dokumentation und Screenshots](docs/DOCUMENTATION.md) · [Einrichtung und Bedienung](docs/ANLEITUNG.md)

![Administrationsfenster: Bildschirmzeit-Grenzwerte](docs/tool-limits.png)

## Funktionen

- Tageslimits, Nachspielzeit, Bonuszeit und konfigurierbarer Tageswechsel.
- Vorab-Meldungen, Statusanzeige und Vollbild-Sperranzeige.
- Erholung: Pausen können verbrauchte Zeit teilweise zurückgeben.
- Administrationsfenster mit automatischer Speicherung der JSON-Konfiguration.
- Geschützte Konfiguration, getrennte Zugriffsrechte und gesalzene PBKDF2-Hashes für PIN und Werkzeug-Passwort.

## Architektur

```mermaid
flowchart TD
    Admin[Administrator] --> GUI[KsAdmin.ps1 · Admin GUI]
    GUI --> Config[Geschützte JSON-Konfiguration]
    subgraph System[Privilegierter SYSTEM-Kontext]
        Task[Windows Task Scheduler · jede Minute] --> Engine[Sperre.ps1 · Zeiterfassung]
        Engine --> State[Geschützter Laufzeitstatus]
    end
    Config --> Engine
    Engine -->|WTS / Win32 · Sitzungsgrenze| Lock[Bildschirm.ps1 · interaktive Sperranzeige]
    Engine --> Public[status.json · Benutzer nur lesen]
    Public --> Bar[NvBar.ps1 · Benutzeranzeige]
```

ACLs trennen den geschützten Systemordner von der für Benutzer lesbaren Statusanzeige. Details: [Architektur und Sicherheitsgrenzen](docs/ARCHITECTURE.md).

## Einstieg

Für Windows 10/11 gibt es einen [geführten PowerShell-Installer](docs/INSTALLER.md): Repository herunterladen und entpacken, Windows PowerShell als Administrator im Ordner öffnen und ausführen:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
```

Er fragt nach Administratorkonto, Zeitlimits und PINs; die Überwachung bleibt zunächst aus. Bestehende Installationen werden nicht überschrieben. **Der vollständige Installer-Ablauf auf Windows ist noch ungeprüft** – zuerst auf einem frischen Test-PC nutzen. [Einrichtung und Deinstallation](docs/INSTALLER.md) · [Manuelle Einrichtung](docs/ANLEITUNG.md)

## Bisherige Prüfung

Das bestehende Setup wurde getestet. Die [vollständige Dokumentation](docs/DOCUMENTATION.md#was-geprüft-ist-und-was-nicht) unterscheidet geprüfte Funktionen und offene Integrationsfälle. Vorschau- und Testfunktionen: [Anleitung](docs/ANLEITUNG.md#4-test-ohne-jemanden-zu-stören).

## Dokumentation

- [Abläufe, Einstellungen und alle Screenshots](docs/DOCUMENTATION.md)
- [Einrichtung, Bedienung und Fehlerbehebung](docs/ANLEITUNG.md)
- [Architektur und Sicherheitsgrenzen](docs/ARCHITECTURE.md)
- [Security](docs/DOCUMENTATION.md#sicherheit)

Die Fehler- und Reparaturbildschirme sind Simulationen, keine echten Hardware- oder Betriebssystemfehler. Das Projekt ist nicht mit Microsoft oder NVIDIA verbunden.
