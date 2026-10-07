# Geführte PowerShell-Einrichtung / Guided PowerShell setup

[Deutsch](../README.md) · [English](../README.en.md)

## Deutsch

Der Installer ist für einen frischen **Windows-10/11-Test-PC** vorgesehen. Der vollständige Windows-Ablauf wurde noch nicht ausgeführt; vor produktiver Nutzung Installation, Benutzerwechsel, Anzeige und Deinstallation auf einem Test-PC prüfen.

1. Das gesamte Repository als ZIP herunterladen und entpacken: [Download](https://github.com/Atakan-24/windows-screen-time-manager/archive/refs/heads/master.zip).
2. **Windows PowerShell (64 Bit) als Administrator** öffnen. Kein PowerShell-7-Fenster verwenden: Die Anwendung nutzt Windows PowerShell 5.1.
3. In den entpackten Ordner wechseln und starten:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
```

Der Installer fragt nach einem vorhandenen lokalen Administratorkonto (direktes Mitglied der Administratorgruppe), Werktag-/Wochenendlimits, Bonus-PIN und Werkzeug-Passwort. Kontonamen mit Leerzeichen oder Sonderzeichen werden wegen bestehender Sitzungsparser nicht unterstützt. Passwörter werden verdeckt eingegeben und nur als gesalzene PBKDF2-Hashes gespeichert. Windows-Passwörter und Konten werden nicht geändert.

Mit `INSTALL` bestätigen. Bestehende Zielordner oder die Aufgabe `Kindersperre` führen zum Abbruch; es gibt keinen Update-Modus. Bei Fehlern versucht das Setup, nur seine neu angelegten Dateien und seine Aufgabe wieder zu entfernen. Fehlgeschlagene Aufräumarbeiten sind bei Bedarf manuell zu prüfen.

### Was eingerichtet wird

- `C:\ProgramData\Kindersperre`: Anwendung, JSON-Konfiguration, PIN-Hashes und Vorschaubilder; Zugriff nur SYSTEM/Administratoren.
- `C:\ProgramData\NVIDIA Corporation\NvContainer`: Statusanzeige; Standardbenutzer erhalten nur Lesen/Ausführen.
- SYSTEM-Aufgabe `Kindersperre`: Start, Anmeldung und Minutenintervall.
- `IdleProbe.exe` wird mit dem vorhandenen .NET-Framework-Compiler aus `IdleProbe.cs` erzeugt.
- Nur installierte Kopien von `KsAdmin.ps1` und `Zerotest.ps1` erhalten den gewählten Kontonamen. Repository-Dateien bleiben unverändert.

**Überwachung ist zunächst aus.** Alle Konten außer dem gewählten Administrator werden beim Aktivieren gezählt. Es werden keine Desktop-Verknüpfungen erstellt. Einstellungen aus einer erhöhten PowerShell öffnen:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\ProgramData\Kindersperre\KsAdmin.ps1
```

Mit dem gewählten Werkzeug-Passwort anmelden, Einstellungen kontrollieren, Vorschau mit einem angemeldeten Testkonto testen und erst dann Überwachung aktivieren. Simulierte Fehlerbildschirme und Tastensperre sind Bestandteil der bestehenden Anwendung.

### Deinstallieren

Aus einer PowerShell als Administrator:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\ProgramData\Kindersperre\Uninstall.ps1
```

Mit `UNINSTALL` bestätigen. Aufgabe und Anwendungsprozesse werden gestoppt. Mit Enter bleiben private Konfiguration, PIN-Hashes und Nutzungsdaten in geschützten Ordnern erhalten. Mit `DELETE` werden die Installationsordner einschließlich dieser Daten gelöscht. Die Deinstallation verweigert fremde Aufgaben, Verzeichnisverknüpfungen und eine noch vorhandene Vorschau-Aufgabe. Bei behaltenen Daten verweigert der Installer eine Neuinstallation in denselben Ordnern.

## English

Download and extract the complete repository ZIP. On a fresh Windows 10/11 test machine, open **64-bit Windows PowerShell as administrator**, change to the extracted folder, and run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1`.

Choose an existing local administrator (direct Administrators-group member; account names without spaces or shell characters), weekday/weekend limits, a bonus PIN and a tool password. Confirm with `INSTALL`. Existing destination folders/tasks are never overwritten. Windows accounts and passwords are untouched. Only installed copies of the admin and preview scripts are adapted to the selected account. IdleProbe is built from source using the .NET Framework compiler.

Monitoring starts **off**. Open `C:\ProgramData\Kindersperre\KsAdmin.ps1` with elevated Windows PowerShell, verify settings, preview using a signed-in test account, then enable monitoring. All other accounts are monitored. No shortcuts are created.

Run the installed `Uninstall.ps1` as administrator and confirm with `UNINSTALL`. Enter keeps private data; `DELETE` removes the installation folders and their data. Complete preview tests first. Kept folders prevent reinstalling over private data.

**Validation limit:** PowerShell syntax and isolated compatibility checks can be performed on macOS. Installation, SYSTEM tasks, Windows ACLs, cross-session UI and full uninstallation require a fresh Windows test machine and are not yet verified for this installer.
