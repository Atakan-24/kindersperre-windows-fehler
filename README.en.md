# Kindersperre (Parental Screen-Time Lock) - private backup

A custom screen-time parental control for the family PC `cenks-pc`, built with Claude Code.
This repository is **private** and serves only as a backup for the owner/administrator (Verwalter account).

**[Deutsche Version: README.md](README.md)**

## Background

Accounts: **Verwalter** (the sole administrator), **Öztunc** (used for gaming, and also by the adult owner) and
**Schwester** (a child account). The lock adds up screen time for every account except Verwalter (`zeit.json`,
PC-wide) and limits it per day. `Sperre.ps1` runs as a scheduled SYSTEM task every minute and, when the limit
is reached, launches `Bildschirm.ps1` as a full-screen overlay in the relevant user session (WTS session
technique, nobody has to log in separately).

## Sequence once the limit is reached

1. **Advance warnings** as system messages disguised as an "NVIDIA graphics driver" warning. Default: 15 and
   1 minute before the lock (selectable in the settings window from 45/30/20/15/5/1).
2. **Screen glitches and a black screen** on the real desktop (short transitions).
3. A **bluescreen** modeled on Windows 10 (`VIDEO_TDR_FAILURE`, real name of the installed graphics card, QR code).
4. The **Windows logo** with loading dots, then **"Preparing automatic repair"** and **"Running PC diagnostics"**
   (both sentences are editable).
5. Every 8 to 14 minutes for 2 minutes a **terminal screen** with a recovery-attempt counter ("Attempt N of 30",
   no clock, no countdown) spread across the real lock duration until the daily reset. Interval, duration and
   font are configurable.
6. At the end (daily reset or lock lifted): briefly black, logo, then the desktop.

The keyboard is locked during the lock (Windows key, Alt+Tab, Ctrl+Alt+Tab, Ctrl+Esc, Ctrl+Shift+Esc).
Windows itself cannot lock Ctrl+Alt+Del.

## Kindersperre-Verwaltung (settings window)

`KsAdmin.ps1` is a window in which **everything can be configured** without editing files. It lives in the
protected folder `C:\ProgramData\Kindersperre` (SYSTEM and administrators only); a shortcut exists only on
Verwalter's desktop. Child accounts can neither see nor open it (verified: `Test-Path` returns `False` for Öztunc).

- **Its own tool password**, independent of the Windows password. Set by you on first start (entered twice).
  Only a PBKDF2 hash is stored (`tool-pin.json`, not in this repository). It can be changed any time in the
  *Passwort* tab (the current password is required).
- **Saves immediately and automatically**, shortly after every change. No save button. A backup of
  `config.json` is made before the first change of a session (the last 20 are kept).
- Changes to limits, on/off etc. also take effect on an **already running lock** (within 5 seconds).

| Tab | What can be set |
|---|---|
| Limits | weekday/weekend limits, grace period, PIN bonus, reset hour, idle threshold, **lock on/off**, **more/less time for today** |
| Warnungen | which advance warnings are sent (45/30/20/15/5/1 minutes) |
| Programme | close programs at lock start, key lock, glitch mode after PIN, glitch level |
| NVIDIA | title, extra text, line under the bar, **preview** with a sample-value slider, test buttons |
| Fehleranzeige | look, end phase, file ticker, restart outro, **repair sentences**, **terminal font and size**, **terminal interval and duration**, previews |
| Erholung | see below |
| Vorschau & Tests | example images of the error screens and **test buttons**: full sequence, terminal (fast-forward), glitch, warnings, NVIDIA display (here / in the child session) |
| Passwort | change the tool password |

Test buttons that run on the child session's screen ask for confirmation first.

**"+ Mehr Zeit" / "- Weniger Zeit"** write a time adjustment (`adjust.txt`) that `Sperre.ps1` applies to the daily
counter on its next run (at most 1 minute). Negative = more time, positive = less time.

## NVIDIA display

A small, optional window (`NvContainer/NvBar.ps1`): title (default "NVIDIA"), a bar, optionally a line below
(percent, time left, used/limit or estimated lock time) and a free extra text. It sits at the top right, always
on top, opens automatically at the earliest configured warning, and can be opened from a desktop shortcut or
closed with X at any time.

`Sperre.ps1` writes only plain numbers and the text to `status.json` in a publicly **readable** folder
(`C:\ProgramData\NVIDIA Corporation\NvContainer`) every minute, so standard users can use the window without
access to the protected folder. With some games in true exclusive fullscreen such a window may not be visible,
like any overlay (a Windows limitation).

## Recovery

Unused time (idle while the PC is on, or PC off) gives minutes back from the daily limit. Everything is
configurable, **off by default** (tab *Erholung*, "Erholung aktiv"):

- Given back per 60 minutes of pause: default 30
- Minimum pause length: default 10 minutes
- At most per day: default 120 minutes (the counter never goes below 0)
- PC-off time counts as a pause: default yes
- Also works during a running lock: default no

## Hidden keys, PIN, glitch mode

Only during a running lock, nothing is stored:

| Combination | Effect |
|---|---|
| Space + F12 + Alt | shows a hidden PIN field for 30 s |
| F11 + F12 | terminal by hand for 2 minutes |
| F1 + F12 | glitch effect off/on |
| Z + F12 | shows the estimated time until the lock ends for about 6 s |

A correct PIN grants +60 minutes and then switches on a **glitch mode** until the daily reset: a transparent,
click-through window that distorts **the real screen content** and is excluded from screen recordings.
**Seizure-safety limits (not relaxable):** at most about 1.4 changes per second, almost no pure red, area with
a strong brightness change under 25%.

## Commands

By typing the word to the controlling Claude Code session (the test buttons in the window do the same):

| Command | Effect |
|---|---|
| `Zerotest` | full test run, about 2.5 min, without touching the real counter |
| `Zerofull` | same, with every advance warning first |
| `Zeroterm` | fast-forward of the terminal appearances |
| `Zeroglitch` | preview of the glitch mode |
| `Zero` / `Zerooff` | trigger / lift the lock immediately |
| `Zerokill` | like `Zero`, and also closes programs in the child session |

## All settings (`config.json`)

Pure ASCII (special characters as `\uXXXX`). Missing entries use the default. The window writes them.

| Key | Meaning (default) |
|---|---|
| `WeekdayLimitMin`, `WeekendLimitMin` | daily limit in minutes (360 / 480) |
| `GraceMin` | grace period (15) |
| `BonusMin` | PIN bonus (60) |
| `ResetHour` | daily reset hour (6) |
| `IdleMin` | idle time after which minutes stop counting (5) |
| `Enabled` | `false` = no limit, no warning, no lock |
| `FreeDays`, `ExcludeUsers` | free weekdays / users that are not counted |
| `WarnMinutes` | advance warnings, e.g. `[15,1]` |
| `KillApps`, `KillPauseUntil` | close programs / pause for that until a date |
| `KeyLock`, `PinGlitch`, `GlitchLevel` | key lock, glitch after PIN, level 1-3 |
| `Look`, `EndPhase`, `FileTicker`, `Outro` | appearance of the lock |
| `RepairText1`, `RepairText2` | repair sentences (empty = default) |
| `TermFont`, `TermFontScale` | terminal font and size in % of the automatic size (50-100) |
| `TermMinGapSec`, `TermMaxGapSec`, `TermDurSec` | terminal interval (480-840 s) and duration (120 s) |
| `NvBarMode`, `NvBarTitle`, `NvBarNote` | NVIDIA display: mode, title, extra text |
| `RegenEnabled`, `RegenPerHourMin`, `RegenMinPauseMin`, `RegenMaxPerDayMin`, `RegenCountOff`, `RegenWhileLocked` | recovery |

The `*.bak-vor-*` files are backups of earlier versions, each created right before a single change
(development history).

## Security

- The Kindersperre folder is accessible only to SYSTEM and administrators.
- The public NVIDIA folder allows standard users **read and execute only**, no writing (otherwise a child could
  replace the file). The NVIDIA display is started as the **logged-in user**, not as SYSTEM.
- The tool password protects the window, **not** against someone who knows Verwalter's Windows password (they can
  edit the files directly). Verwalter's Windows password must therefore not be shared.
- `pin.json` and `Set-PIN.ps1` are never output, as a standing rule.

## Screenshots

From test runs, purely synthetic (no real screen content).

![Bluescreen](shot-bsod.png)
![Logo](shot-logo.png)
![Repair](shot-repair.png)
![Terminal](shot-terminal.png)

The settings window:

![Limits](docs/tool-limits.png)
![NVIDIA display with preview](docs/tool-nvidia.png)
![Error screens](docs/tool-fehleranzeige.png)
![Recovery](docs/tool-erholung.png)
![Preview and tests](docs/tool-tests.png)

## Not in this repository

- `pin.json`, `Set-PIN.ps1`, `tool-pin.json` (PIN / password hashes)
- real usage data (`zeit.json`, logs, history), day-specific registry backups
- an example image of the glitch mode: by design it always shows the real screen content.
