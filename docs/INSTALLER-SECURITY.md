# Installer security review

Scope: `Install.ps1` and `Uninstall.ps1`. This is a source and isolated-logic review, not a Windows integration certification.

- Administrator privileges and 64-bit Windows PowerShell are required; no automatic privilege elevation or remote script execution.
- No existing installation folders/tasks are overwritten. Destination paths are fixed, reparse-point ancestors are rejected, and uninstall rejects reparse-point descendants.
- Protected application files allow SYSTEM/Administrators only. Public status UI files allow standard users read/execute only. Actual ACL behavior must be checked on Windows.
- Secrets use hidden input, confirmation, random 16-byte salts and PBKDF2 with 100,000 iterations, matching existing runtime verification. BSTR buffers are cleared. .NET managed plaintext strings cannot be guaranteed erased immediately.
- Account input is restricted and checked against enabled local administrator-group membership. Only installed copies of known account literals are adapted.
- The SYSTEM task is registered only after files/configuration are written. Monitoring starts disabled. Failed setup attempts roll back newly created destinations; rollback errors require manual inspection.
- Uninstall requires a matching manifest and task identity, explicit confirmation and a separate decision to erase private data. Only matching installed application processes are stopped. Active preview tasks block removal.
- The installer performs no Windows account/password changes and installs no Claude tooling. IdleProbe is built from source.
- Rate limiting: no network service or externally accessible API is introduced. RLS: no database is used.

## Validation

PowerShell parsing passed for both scripts. Isolated checks cover default/invalid limits, hidden-input confirmation, runtime-compatible PBKDF2 hashes and parsing of account-adapted installed scripts. A redacted Gitleaks scan found no secrets.

Still required on a fresh Windows test machine: successful install, compiler invocation, effective ACL inspection, minute/startup/logon triggers, protected admin UI, PIN entry, cross-session display, refusal of existing installations, failure cleanup, and both uninstall data choices. The installer is experimental until these checks pass.
