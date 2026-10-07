# Architecture and security boundaries

[Deutsch](../README.md) · [English](../README.en.md)

The diagrams in the READMEs describe the existing implementation. This document maps the components to their files; no runtime behavior was changed for the portfolio presentation.

| Component | File | Responsibility |
|---|---|---|
| Scheduled usage engine | `Sperre.ps1` | Runs as SYSTEM every minute, at startup and logon; tracks time, sends notices, starts session interfaces. |
| Interactive lock | `Bildschirm.ps1` | Full-screen display, input handling, bonus-code verification and simulated error/graphics effects. |
| Administration | `KsAdmin.ps1` | Protected settings UI, JSON updates, password and support-code management. |
| User status display | `NvContainer/NvBar.ps1` | Reads the public status file and shows usage in a logged-in user session. |
| Idle measurement | `IdleProbe.cs`, `IdleProbe.exe` | Measures inactivity. |
| Configuration | `config.json` | Limits, exclusions, notices, visual options and recovery settings. |

## Boundaries

- `C:\ProgramData\Kindersperre` is restricted to SYSTEM and administrators through ACLs. Configuration, credentials and runtime state belong there.
- `C:\ProgramData\NVIDIA Corporation\NvContainer` allows standard users read/execute access, not write access. The engine publishes display data in `status.json`.
- WTS and Win32 APIs bridge the scheduled SYSTEM task and interactive Windows sessions. `Sperre.ps1` contains `WTSQueryUserToken` and `CreateProcessAsUser` paths; the status display runs as the logged-in user.
- PIN and tool-password verification uses salted PBKDF2 hashes. These credential files are excluded from the repository.
- The tool password does not protect against a Windows administrator who can change files directly. This is not an administrator-resistant security boundary.

## Existing setup assumptions

Some scripts hard-code `Verwalter` for Windows password changes or session selection. Documentation uses generic account roles, but code and configuration remain unchanged. Adjusting `ExcludeUsers` does not remove every account-name dependency.

The installation guides describe an existing Windows setup; a fresh-machine installation and the full multi-hour sequence are not claimed as verified. See the [German verification table](DOCUMENTATION.md#was-geprüft-ist-und-was-nicht) or [English verification table](DOCUMENTATION.en.md#what-is-verified-and-what-is-not).
