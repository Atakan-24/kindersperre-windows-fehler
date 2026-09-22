# Kindersperre (Parental Screen-Time Lock) - private backup

A custom screen-time parental control for the family PC `cenks-pc`, built with Claude Code.
This repository is **private** and serves only as a backup for the owner/administrator (Verwalter account).

**[Deutsche Version: README.md](README.md)**

## Background

Accounts: **Verwalter** (the sole administrator, password known only to them), **Öztunc** (the account used
for gaming, and also by the adult owner personally) and **Schwester** (a child account with passwordless
autologon). The lock tracks screen time for every account except Verwalter together (`zeit.json`, PC-wide)
and limits it per day.

## Sequence once the daily limit is reached

1. **Advance warnings** beforehand, shown as system messages disguised as an "NVIDIA graphics driver"
   warning (default: 45/30/20/15/5/1 minutes before the lock; in this configuration reduced to 15 and 1
   minute, see `config.json`).
2. **Screen glitches and a black screen** on the real desktop (short transition phases).
3. A **bluescreen** modeled on Windows 10 (stop code `VIDEO_TDR_FAILURE`, the real name and PCI ID of the
   installed NVIDIA graphics card, a QR code, the sad-face icon).
4. The **Windows logo** with loading dots, then **"Preparing automatic repair"** and
   **"Running PC diagnostics"**.
5. Every 8 to 14 minutes (random, derived from a daily key) for 2 minutes, a **terminal screen**: no
   countdown, instead a recovery-attempt counter ("Recovery attempt N of 30"), whose 30 attempts are spread
   across the real remaining lock time up to the next daily reset. Each attempt ends with
   `FAILED (0xC000009A)`, the last one with `SUCCESSFUL`.
6. At the end (daily reset, or the lock being lifted): briefly black, then the logo, then the normal desktop.

The keyboard is locked for the whole duration (Windows key, Alt+Tab, Ctrl+Alt+Tab, Ctrl+Esc,
Ctrl+Shift+Esc). Windows itself cannot lock Ctrl+Alt+Del, so that always stays available.

## Hidden key combinations (only while a lock is actually running)

None of these are ever logged or stored anywhere.

| Combination | Effect |
|---|---|
| Space + F12 + Alt | Shows a hidden supervisor-PIN field for 30 s |
| F11 + F12 | Manually switches to the terminal screen for 2 minutes (only during logo/repair) |
| F1 + F12 | Toggles the glitch-effect mode (see below) off/on |
| Z + F12 | Shows the estimated remaining time until the lock ends for about 6 s (only during logo/repair/terminal) |

## PIN and glitch-effect mode

A correct PIN entered in the hidden field grants +60 minutes of bonus time and then, until the next daily
reset, switches on a **glitch-effect mode**: a transparent, click-through window on top, excluded from
normal screen recordings via `SetWindowDisplayAffinity`, that distorts **the real, current screen content**
(tearing, blocking artifacts, slipping screen sections, tile garbage, dropped scan lines, swapped colors).
Its strength ramps up over about 40 seconds after the PIN is entered, then keeps growing in fixed steps the
longer ago the bonus was granted.

**Seizure-safety limits (deliberately not relaxable):** at most about 1.4 changes per second, almost no
pure red, and the area with a strong brightness change versus the real image stays under 25% (measured at
most 22.9%).

Because this effect uses the real screen content, this repository deliberately contains **no example image**
of it (see "Intentionally not included" below).

## NVIDIA status display

A simple, optional display window (`NvBar.ps1`) that shows only a bar and the word "NVIDIA". It lives in
its own, **publicly readable** folder (`C:\ProgramData\NVIDIA Corporation\NvContainer`), separate from the
protected Kindersperre folder, so standard user accounts can open it too. `Sperre.ps1` writes a plain
percentage value there every minute (time used out of the daily limit), nothing else. The window sits in
the top-right corner, stays on top, opens automatically when the 15-minute warning fires, and can otherwise
be opened or closed by hand at any time (a shortcut on the desktop). With some games running in true
exclusive fullscreen it may not be visible, like any other overlay window (a Windows-level limitation).

## Accounts and permissions

`Sperre.ps1` runs as a scheduled SYSTEM task every minute and, once the daily limit is reached, launches
`Bildschirm.ps1` as a full-screen overlay directly in the relevant user's session (via a WTS session-launch
technique, without anyone needing to log in separately). On the crash sequence, programs with a window in
the affected session get closed (`KillApps`), never for Verwalter, and never installers or running
installations. The folder `C:\ProgramData\Kindersperre` is accessible only to SYSTEM and administrators.

## Commands (Verwalter, by typing the word to the controlling Claude Code session)

| Command | Effect |
|---|---|
| `Zerotest` | Full test run (glitches, bluescreen, logo, repair, terminal, wrap-up), about 2.5 min, without touching the real counter |
| `Zerofull` | Same, but first shows every advance warning in sequence |
| `Zeroterm` | Fast-forward preview of the automatic terminal appearances |
| `Zeroglitch` | Preview of the glitch-effect mode at its end state |
| `Zero` | Triggers the lock immediately, without changing the daily counter |
| `Zerokill` | Same as `Zero`, and additionally closes every windowed program in the child's session |
| `Zerooff` | Lifts a lock that was triggered by `Zero` |

## Configuration (`config.json`)

Daily limits for weekday/weekend, reset time, grace period, PIN bonus time, excluded users, and on/off
switches for individual features. The `*.bak-vor-*` files are backups of earlier versions of the scripts,
each created right before a single change (the full development history is traceable).

## Screenshots

From a test run on 2026-09-22, current state (purely synthetic, no real screen content).

![Bluescreen view](shot-bsod.png)
*Bluescreen view modeled on a real Windows 10 crash, with real details of the installed graphics card.*

![Logo view](shot-logo.png)
*Windows logo with loading dots after the bluescreen.*

![Repair view](shot-repair.png)
*"Running PC diagnostics" - an intermediate step before the periodic terminal screen.*

![Terminal view](shot-terminal.png)
*Terminal screen with a recovery-attempt counter (N of 30) spread across a timeline, no countdown.*

## Intentionally NOT in this repository (see .gitignore)

- `pin.json` / `Set-PIN.ps1` (the PIN hash, and the script that sets it) - never output, as a standing rule.
- Real usage data: `zeit.json`, logs, history files, today's registry backups.
- An example image of the glitch-effect mode: by design it always shows the real, current screen content
  of whoever is currently locked out - there is no variant of it without real content.

## Context and limits

Own PC, own administrator account, parental control for the owner's own children, who know the lock exists.
No network access, no keystroke logging, no persistent screen recording outside of explicitly requested
test runs. The administrator always has access (hidden PIN field, their own account, Ctrl+Alt+Del). Further
detail and the complete development history live as comments directly in the scripts.
