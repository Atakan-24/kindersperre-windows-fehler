# Guide: install, configure, activate

[Back to the overview](../README.en.md) · [Anleitung (Deutsch)](ANLEITUNG.md)

This guide describes how the lock is built, how to **configure** it and how to **switch it on and off**. Everything runs on
Windows 10/11 with Windows PowerShell 5.1.

> **Honest note up front:** the "Set it up from scratch" section describes how the existing installation is built. The commands
> there were assembled from the running task, but **not executed again** on this PC (the installation already runs). On a fresh PC,
> try it with a test account first. The PIN file (`pin.json`) and the tool `Set-PIN.ps1` are deliberately not in the repository.

## 1. Day to day: the settings window

1. On **Verwalter's** desktop double-click the **"Systemdiagnose"** icon (starts `KsAdmin.ps1`).
2. On first start choose a **tool password** (at least 4 characters, independent of the Windows password). The window asks for it
   on every later start.
3. Change settings. **They are saved automatically and immediately**, there is no save button. A running lock picks changes up
   within 5 seconds.
4. Close the window. The changes are already active.

### The most important settings

| What | Where | Note |
|---|---|---|
| Daily threshold Mon-Fri / Sat-Sun | tab "Grenzwerte" | default 360 / 480 minutes |
| More or less time for today | tab "Grenzwerte", "+ Mehr" / "− Weniger" | applied on the next run (at most 1 minute) |
| **Monitoring on/off** | tab "Grenzwerte" | off = no counting, no warning, no lock |
| Which advance notices | tab "Meldungen" | default: 15 and 1 minute before |
| Close programs, key protection, glitch mode | tab "Prozesse" | |
| Text, title and look of the NVIDIA display | tab "NVIDIA" | with preview |
| Repair sentences, terminal font/interval/duration | tab "Diagnose" | with preview |
| **Recovery** (unused time gives minutes back) | tab "Abkühlung" | **on by default** |
| See example images, test everything | tab "Vorschau" | test buttons ask first |
| Change tool password / Windows password / **support code** (PIN on the error screen) | tab "Zugriff" | Windows password and support code only with the current one; support code at least 6 characters, effective immediately |
| All key combinations, commands and the sequence | tab "Hilfe" → "Info" button | |
| Font size of the window | tab "Hilfe" | size: drag the window edges |

## 2. Switching on and off

| Goal | How |
|---|---|
| **Activate** | tab "Grenzwerte": monitoring **on**. Or set `"Enabled"` to `true` (or remove it) in `config.json`. The scheduled task `Kindersperre` must be enabled (see below). |
| **Switch off temporarily** | tab "Grenzwerte": monitoring **off** (or `"Enabled": false`). A running lock ends within 5 seconds. |
| **Stop completely** | as administrator: `Disable-ScheduledTask -TaskName Kindersperre` |
| **Start again** | `Enable-ScheduledTask -TaskName Kindersperre` |
| Lock immediately | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\ProgramData\Kindersperre\Zero.ps1` (as administrator; never locks Verwalter) |
| Lift the lock | `...\Zerooff.ps1` (if the real threshold is reached the lock stays; the script says so) |
| Full test (without changing the real counter) | tab "Vorschau" → "Komplett-Diagnose", or `...\Zerotest.ps1` |

Check that everything runs: `Get-ScheduledTaskInfo -TaskName Kindersperre` (LastTaskResult 0) and the last lines of
`C:\ProgramData\Kindersperre\log.txt`.

## 3. The NVIDIA display

- It opens automatically at the earliest configured advance notice.
- By hand: the **"NVIDIA"** desktop shortcut, or "Bei mir zeigen" in the settings window (tab "NVIDIA" / "Vorschau").
- **Move:** drag anywhere with the mouse. **Size:** drag an edge (bottom, right, left, top). Both are remembered. Without extra
  text it is slim, with text it grows.
- What is shown under the bar (nothing, percent, remaining time, used/threshold, clock time) and the extra text: tab "NVIDIA".

## 4. Testing without disturbing anyone

| Test | Where | What happens |
|---|---|---|
| Komplett-Diagnose | tab "Vorschau" | the whole sequence, about 2.5 minutes, does not change the counter |
| Konsole (schnell) | tab "Vorschau" | fast-forward of the terminal appearances |
| Grafik | tab "Vorschau" | 60 s preview of the glitch mode |
| Meldungen | tab "Vorschau" | the advance notices in a row |
| NVIDIA bei mir | tab "Vorschau" / "NVIDIA" | shows the display only on your own screen |
| NVIDIA auf Zielkonto | tab "Vorschau" / "NVIDIA" | shows it in the child's session (asks first) |

Tests run as a one-off SYSTEM task `KS-Einmaltest` that is deleted afterwards. The key lock is **on** during the test (as for real).

## 5. Set it up from scratch (how the existing installation is built)

All commands in a PowerShell **as administrator**.

**Step 1: folder with protection.** Only SYSTEM and administrators may enter:

```powershell
$K = 'C:\ProgramData\Kindersperre'
New-Item -ItemType Directory -Force $K | Out-Null
icacls $K /inheritance:r /grant 'SYSTEM:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F'
```

**Step 2: copy the files** from this repository to `C:\ProgramData\Kindersperre`: `Sperre.ps1`, `Bildschirm.ps1`, `KsAdmin.ps1`,
`Zero.ps1`, `Zerooff.ps1`, `Zerotest.ps1`, `IdleProbe.exe` (+ `IdleProbe.cs`), `config.json`, `assets\winlogo.png`. `Sperre.ps1`
and `Bildschirm.ps1` must stay **UTF-8 with BOM and LF line endings** (do not save them with an editor that changes this). Then
adapt the accounts in `config.json` (`ExcludeUsers`: accounts that are not counted, at least the administrator; special characters
as `\uXXXX`).

**Step 3: public folder for the NVIDIA display.** Users may only read and execute there:

```powershell
$N = 'C:\ProgramData\NVIDIA Corporation\NvContainer'
New-Item -ItemType Directory -Force $N | Out-Null
Copy-Item .\NvContainer\NvBar.ps1 $N
icacls $N /inheritance:r /grant 'SYSTEM:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-32-545:(OI)(CI)RX'
```

**Step 3b: PIN.** The PIN for the bonus code (+60 minutes) is created by the local, unpublished tool `Set-PIN.ps1` (it writes
`pin.json` in the lock folder). Without `pin.json` there is no bonus code.

**Step 4: scheduled task.** This is how the existing task `Kindersperre` is built (SYSTEM, highest privileges, three triggers,
2 minute time limit, no parallel runs):

```powershell
$a  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\ProgramData\Kindersperre\Sperre.ps1"'
$t1 = New-ScheduledTaskTrigger -AtStartup
$t2 = New-ScheduledTaskTrigger -AtLogOn
$t3 = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration (New-TimeSpan -Days 3650)
$p  = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest -LogonType ServiceAccount
$s  = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 2) -MultipleInstances IgnoreNew -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName 'Kindersperre' -Action $a -Trigger $t1, $t2, $t3 -Principal $p -Settings $s
```

**Step 5: desktop shortcuts (administrator only).** "Systemdiagnose" starts the settings window, "NVIDIA" the display:

```powershell
$desk = [Environment]::GetFolderPath('Desktop'); $ws = New-Object -ComObject WScript.Shell
$l = $ws.CreateShortcut((Join-Path $desk 'Systemdiagnose.lnk'))
$l.TargetPath = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
$l.Arguments  = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\ProgramData\Kindersperre\KsAdmin.ps1"'
$l.WorkingDirectory = 'C:\ProgramData\Kindersperre'; $l.IconLocation = 'C:\Windows\System32\shell32.dll,44'; $l.Save()
```

**Step 6: check.** `Start-ScheduledTask Kindersperre`, then `Get-ScheduledTaskInfo Kindersperre` (result 0) and look at `log.txt`.
Then open the "Vorschau" tab in the settings window and test the "Komplett-Diagnose".

## 6. If something does not work

| Problem | Cause / solution |
|---|---|
| Window reports "property … not found" | old version; the new one creates missing settings itself |
| The lock does not come | `Get-ScheduledTaskInfo Kindersperre`; is the task enabled? Is `Enabled` in `config.json` set to `false`? Is `zeit.json` below the threshold? |
| NVIDIA display does not appear | only at a reached notice threshold or by hand; over games in exclusive fullscreen Windows may not show it |
| A script suddenly shows umlaut errors | file saved without BOM. Write `Sperre.ps1`/`Bildschirm.ps1` only with `UTF8Encoding($true)` |
| The lock stops working after an editor change | back up before every change (`*.bak-vor-<reason>`), then check with `Parser::ParseFile` |
| Changing the Windows password fails | the current password is wrong, or the PC's password policy rejects the new one |

## 7. Rules not to relax

- Keep `C:\ProgramData\Kindersperre` accessible only to SYSTEM and administrators.
- Give users **no write permission** in the public NVIDIA folder.
- Do not relax the seizure safety of the glitch effect.
- Do not share the administrator's Windows password; never publish the PIN hash or `Set-PIN.ps1`.
