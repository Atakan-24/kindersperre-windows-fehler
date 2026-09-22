# Kindersperre (Parental Screen-Time Lock) - private backup

A custom screen-time parental control for the family PC `cenks-pc`, built with Claude Code.
This repository is **private** and serves only as a backup for the owner/administrator (Verwalter account).

**[Deutsche Version: README.md](README.md)**

## How it works

- `Sperre.ps1` runs as a scheduled SYSTEM task every minute, tracks screen time PC-wide
  (except for excluded users), and when the daily limit is reached, launches `Bildschirm.ps1`
  as a full-screen overlay in the relevant user session (via a WTS session-launch technique).
- Advance warnings (default: 45/30/20/15/5/1 min before lock) shown as system messages.
- `Bildschirm.ps1` displays a multi-stage sequence modeled on a real Windows crash
  (screen glitches, bluescreen, logo, "Preparing automatic repair", a periodic terminal screen
  with a recovery-attempt counter spread across a timeline up to the daily reset).
- Keyboard lock while the screen is active (Win, Alt+Tab, Ctrl+Alt+Tab, Ctrl+Esc).
- Hidden PIN field (key combination) for bonus time; on a correct PIN, an additional
  glitch-effect mode distorts the real screen content (with seizure-safety limits:
  capped flash rate, almost no red, capped area with strong brightness change).
- `Zero.ps1` / `Zerooff.ps1` / `Zerotest.ps1`: commands to trigger, lift and test the
  lock immediately (test runs do not affect the real counter).
- `Claude-Start.ps1` / `Claude-Autostart-einrichten.ps1`: autostart of the controlling
  Claude Code session at PC boot.

## Screenshots

From test runs (Zerotest), not from live operation.

![Lock screen with supervisor PIN field](shot.png)
*Simple lock view with a hideable supervisor-PIN field at the bottom right.*

![Bluescreen view](shot5.png)
*Bluescreen view modeled on a real Windows crash, with real details of the installed graphics card.*

![Terminal view with countdown](shot3.png)
*Early version of the terminal view (later replaced by a recovery-attempt counter spread across a real timeline).*

## Configuration

`config.json` holds daily limits (weekday/weekend), reset time, grace period, bonus time,
excluded users and optional switches. The `*.bak-vor-*` files are backups of earlier versions
of the scripts, each created right before a single change (development history).

## Intentionally NOT in this repository (see .gitignore)

- `pin.json` / `Set-PIN.ps1` (the PIN hash, and the script that sets it)
- Real usage data: `zeit.json`, logs, history files, today's registry backups

## Context

Own PC, own administrator account, parental control for the owner's own children. No network access,
no keystroke logging, no persistent screen recording outside of test runs. See the comments in the
scripts themselves for further detail and development history.