# Kindersperre v3 - PC-weites Tageslimit fuer ALLE Benutzer (Windows 10 Home tauglich, nutzt die WTS-API).
# Laeuft jede Minute + bei jeder Anmeldung als SYSTEM. Zaehlt Minuten, in denen irgendein Benutzer aktiv ist
# (Maus/Tastatur benutzt, Bildschirm nicht gesperrt). Ist das Limit erreicht, wird in jeder Sitzung ein
# schwarzer Vollbildschirm (Bildschirm.ps1) gestartet, den nur die Betreuer-PIN oder der Tageswechsel aufhebt.
param(
    [switch]$Diag,
    [switch]$TestOverlay,
    [int]$SessionId = -1,
    [int]$Seconds = 12,
    [string]$Shot = '',
    [switch]$DemoWarnings,
    [int]$Gap = 7
)

$Dir       = 'C:\ProgramData\Kindersperre'
$StateFile = Join-Path $Dir 'zeit.json'
$LogFile   = Join-Path $Dir 'log.txt'
$cfg       = Get-Content (Join-Path $Dir 'config.json') -Raw | ConvertFrom-Json
# LimitMin wird jetzt pro Wochentag berechnet, siehe Get-LimitMinForToday unten
$GraceMin  = [double]$cfg.GraceMin
$IdleMin   = [double]$cfg.IdleMin
$PsExe     = Join-Path $env:windir 'System32\WindowsPowerShell\v1.0\powershell.exe'

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public class Wts {
    [StructLayout(LayoutKind.Sequential)]
    struct WTS_SESSION_INFO { public int SessionId; public IntPtr pWinStationName; public int State; }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct WTSINFO {
        public int State; public int SessionId;
        public int IncomingBytes; public int OutgoingBytes; public int IncomingFrames; public int OutgoingFrames;
        public int IncomingCompressedBytes; public int OutgoingCompressedBytes;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string WinStationName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 17)] public string Domain;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 21)] public string UserName;
        public long ConnectTime; public long DisconnectTime; public long LastInputTime; public long LogonTime; public long CurrentTime;
    }

    [DllImport("wtsapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern bool WTSEnumerateSessions(IntPtr h, int reserved, int version, out IntPtr info, out int count);
    [DllImport("wtsapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern bool WTSQuerySessionInformation(IntPtr h, int sessionId, int infoClass, out IntPtr buf, out int bytes);
    [DllImport("wtsapi32.dll")] static extern void WTSFreeMemory(IntPtr p);
    [DllImport("wtsapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern bool WTSSendMessage(IntPtr h, int sessionId, string title, int titleLen, string msg, int msgLen, int style, int timeout, out int response, bool wait);

    // Liste: "SessionId;State;User;IdleSekunden"  (State 0 = aktiv, 4 = getrennt)
    public static string[] List() {
        IntPtr info; int count;
        var res = new List<string>();
        if (!WTSEnumerateSessions(IntPtr.Zero, 0, 1, out info, out count)) return res.ToArray();
        int size = Marshal.SizeOf(typeof(WTS_SESSION_INFO));
        for (int i = 0; i < count; i++) {
            WTS_SESSION_INFO s = (WTS_SESSION_INFO)Marshal.PtrToStructure(new IntPtr(info.ToInt64() + i * size), typeof(WTS_SESSION_INFO));
            IntPtr buf; int bytes;
            if (!WTSQuerySessionInformation(IntPtr.Zero, s.SessionId, 24, out buf, out bytes)) continue;
            WTSINFO w = (WTSINFO)Marshal.PtrToStructure(buf, typeof(WTSINFO));
            WTSFreeMemory(buf);
            long idle = 0;
            if (w.LastInputTime > 0 && w.CurrentTime >= w.LastInputTime) idle = (w.CurrentTime - w.LastInputTime) / 10000000L;
            res.Add(s.SessionId + ";" + s.State + ";" + w.UserName + ";" + idle);
        }
        WTSFreeMemory(info);
        return res.ToArray();
    }

    public static void Message(int id, string title, string text, int seconds, int style) {
        int r; WTSSendMessage(IntPtr.Zero, id, title, title.Length * 2, text, text.Length * 2, style, seconds, out r, false);
    }

    // ---- Prozess mit SYSTEM-Rechten in der Sitzung eines Benutzers starten (normaler Benutzer kann ihn nicht beenden) ----
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct STARTUPINFO {
        public int cb; public string lpReserved; public string lpDesktop; public string lpTitle;
        public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
        public short wShowWindow, cbReserved2; public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
    }
    [StructLayout(LayoutKind.Sequential)]
    struct PROCESS_INFORMATION { public IntPtr hProcess, hThread; public int dwProcessId, dwThreadId; }
    [StructLayout(LayoutKind.Sequential)]
    struct TP { public int Count; public int LuidLow; public int LuidHigh; public int Attr; }

    [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
    [DllImport("advapi32.dll", SetLastError = true)] static extern bool OpenProcessToken(IntPtr p, int access, out IntPtr tok);
    [DllImport("advapi32.dll", SetLastError = true)] static extern bool DuplicateTokenEx(IntPtr tok, int access, IntPtr attr, int impLevel, int type, out IntPtr newTok);
    [DllImport("advapi32.dll", SetLastError = true)] static extern bool SetTokenInformation(IntPtr tok, int cls, ref int val, int len);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern bool LookupPrivilegeValue(string sys, string name, out long luid);
    [DllImport("advapi32.dll", SetLastError = true)] static extern bool AdjustTokenPrivileges(IntPtr tok, bool disableAll, ref TP tp, int len, IntPtr prev, IntPtr retLen);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern bool CreateProcessAsUser(IntPtr tok, string app, StringBuilder cmd, IntPtr pa, IntPtr ta, bool inherit, uint flags, IntPtr env, string cwd, ref STARTUPINFO si, out PROCESS_INFORMATION pi);

    public static string StartInSession(int sessionId, string cmdLine) {
        IntPtr tok = IntPtr.Zero, dup = IntPtr.Zero;
        try {
            if (!OpenProcessToken(GetCurrentProcess(), 0xF01FF, out tok)) return "OpenProcessToken Fehler " + Marshal.GetLastWin32Error();
            long luid;
            if (LookupPrivilegeValue(null, "SeTcbPrivilege", out luid)) {
                TP tp = new TP(); tp.Count = 1; tp.LuidLow = (int)(luid & 0xFFFFFFFF); tp.LuidHigh = (int)(luid >> 32); tp.Attr = 2;
                AdjustTokenPrivileges(tok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
            }
            if (!DuplicateTokenEx(tok, 0x2000000, IntPtr.Zero, 2, 1, out dup)) return "DuplicateTokenEx Fehler " + Marshal.GetLastWin32Error();
            int sid = sessionId;
            if (!SetTokenInformation(dup, 12, ref sid, 4)) return "SetTokenInformation Fehler " + Marshal.GetLastWin32Error();
            STARTUPINFO si = new STARTUPINFO(); si.cb = Marshal.SizeOf(typeof(STARTUPINFO)); si.lpDesktop = "winsta0\\default";
            PROCESS_INFORMATION pi;
            if (!CreateProcessAsUser(dup, null, new StringBuilder(cmdLine), IntPtr.Zero, IntPtr.Zero, false, 0x08000000, IntPtr.Zero, null, ref si, out pi))
                return "CreateProcessAsUser Fehler " + Marshal.GetLastWin32Error();
            CloseHandle(pi.hProcess); CloseHandle(pi.hThread);
            return "OK pid " + pi.dwProcessId;
        } finally {
            if (dup != IntPtr.Zero) CloseHandle(dup);
            if (tok != IntPtr.Zero) CloseHandle(tok);
        }
    }
}
'@

function Log($m) { ('{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) | Out-File $LogFile -Append -Encoding ascii }
function Get-DayKey { (Get-Date).AddHours(-[double]$cfg.ResetHour).ToString('yyyy-MM-dd') }
# Text und Symbol einer Vorwarnung "t Minuten bis zur Sperre" bei G Minuten Nachspielzeit.
# Kopie der Texte aus dem Normalbetrieb (weiter unten), nur fuer den Demo-Modus -DemoWarnings.
function Get-WarnText([int]$t, [int]$G) {
    if ($t -gt $G) {
        return @{ Style = 0x30; Text = ("GRAFIKTREIBER-WARNUNG`n`nDer NVIDIA-Grafiktreiber (nvlddmkm.sys) meldet Instabilität. Ein Grafikfehler wird in ca. {0} Minuten erwartet.`n`nBitte keine neuen Spiele oder Dateien starten." -f $t) }
    } elseif ($t -eq $G) {
        return @{ Style = 0x30; Text = ("WARNUNG: GRAFIKFEHLER IN CA. {0} MINUTEN`n`nDer Grafiktreiber ist instabil. Bitte KEINE Spiele oder Dateien starten, sonst kann der Fehler früher auftreten.`n`nALLE ANWENDUNGEN BEENDEN und nicht gespeicherte Daten sichern." -f $t) }
    } elseif ($t -gt 1) {
        return @{ Style = 0x10; Text = ("KRITISCH: GRAFIKFEHLER IN CA. {0} MINUTEN`n`nALLE ANWENDUNGEN JETZT BEENDEN! Nicht gespeicherte Daten gehen verloren." -f $t) }
    }
    return @{ Style = 0x10; Text = "KRITISCH: GRAFIKFEHLER IN WENIGER ALS 1 MINUTE`n`nALLE ANWENDUNGEN SOFORT BEENDEN!" }
}


function Test-FreeDay {
    # Tage ohne Limit laut config.json "FreeDays" (0 = Sonntag ... 6 = Samstag). Massgeblich ist der Tagesschluessel,
    # d. h. ein freier Tag laeuft wie das Limit-Zaehlen von ResetHour bis ResetHour des Folgetags.
    try {
        $dow = [int][datetime]::ParseExact((Get-DayKey), 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture).DayOfWeek
        return (@($cfg.FreeDays) -contains $dow)
    } catch { return $false }
}
function Get-LimitMinForToday {
    # Wochenend-/Wochentaglimit statt einem einzelnen LimitMin. 0=Sonntag,6=Samstag = Wochenende.
    try {
        $dow = [int][datetime]::ParseExact((Get-DayKey), 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture).DayOfWeek
        if ($dow -eq 0 -or $dow -eq 6) { return [double]$cfg.WeekendLimitMin }
        return [double]$cfg.WeekdayLimitMin
    } catch { return [double]$cfg.WeekdayLimitMin }
}
function Get-Bonus {
    $f = Join-Path $Dir 'bonus.txt'
    if (Test-Path $f) {
        try { $p = (Get-Content $f -Raw).Trim().Split(';'); if ($p[0] -eq (Get-DayKey)) { return [double]$p[1] } } catch { }
    }
    return 0.0
}
function Test-OverlayRunning($sid) {
    [bool](Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
        Where-Object { $_.SessionId -eq $sid -and $_.CommandLine -like '*Bildschirm.ps1*' })
}
function Get-SessionIdle($list) {
    # Sekunden seit der letzten Tastatur-/Mauseingabe je Sitzung. Die WTS-API liefert dafuer auf der Konsole nichts (LastInputTime = 0);
    # deshalb laeuft in jeder Sitzung kurz IdleProbe.exe (als SYSTEM gestartet, vom Benutzer nicht beeinflussbar) und schreibt idle-<Id>.txt.
    $res   = @{}
    $probe = Join-Path $Dir 'IdleProbe.exe'
    if (-not (Test-Path $probe)) { $script:ProbeNote = 'IdleProbe.exe fehlt'; return $res }
    $files = @{}
    foreach ($s in $list) {
        $f = Join-Path $Dir ('idle-{0}.txt' -f $s.Id)
        try { [IO.File]::Delete($f) } catch { }
        $r = [Wts]::StartInSession($s.Id, ('"{0}" "{1}"' -f $probe, $f))
        if ($r -like 'OK*') { $files[$s.Id] = $f } else { $script:ProbeNote = "Start in Sitzung $($s.Id): $r" }
    }
    $deadline = (Get-Date).AddSeconds(10)
    while ($res.Count -lt $files.Count -and (Get-Date) -lt $deadline) {
        foreach ($id in @($files.Keys)) {
            if (-not $res.ContainsKey($id) -and (Test-Path $files[$id])) {
                try { $res[$id] = [double]::Parse((Get-Content $files[$id] -Raw).Trim(), [Globalization.CultureInfo]::InvariantCulture) } catch { }
            }
        }
        if ($res.Count -lt $files.Count) { Start-Sleep -Milliseconds 200 }
    }
    if ($res.Count -lt $files.Count) { $script:ProbeNote = 'keine Antwort des Hilfsprozesses innerhalb von 10 s' }
    return $res
}
$sessions = @([Wts]::List() | ForEach-Object {
    $p = $_.Split(';')
    [pscustomobject]@{ Id = [int]$p[0]; State = [int]$p[1]; User = $p[2]; WtsIdle = [long]$p[3] }   # WtsIdle ist auf der Konsole immer 0 (keine Eingabezeit) - nur Anzeige, wird nicht zum Zaehlen benutzt
} | Where-Object { $_.User -and $_.Id -ne 0 })
$lockedIds = @(Get-Process LogonUI -ErrorAction SilentlyContinue | ForEach-Object { $_.SessionId })

if ($Diag) {
    "Sitzungen:"; $sessions | Format-Table -AutoSize | Out-String
    "Gesperrt (LogonUI) in Sitzungen: " + ($lockedIds -join ',')
    "Bonus heute: " + (Get-Bonus) + " Min | Limit: " + (Get-LimitMinForToday) + " | Tagesschluessel: " + (Get-DayKey) + " | Freier Tag (kein Limit): " + (Test-FreeDay)
    foreach ($s in $sessions) { "Sitzung {0}: Overlay laeuft = {1}" -f $s.Id, (Test-OverlayRunning $s.Id) }
    foreach ($s in $sessions) {
        $f = Join-Path $Dir ('idle-{0}.txt' -f $s.Id)
        if (Test-Path $f) { "Sitzung {0}: Leerlauf laut Hilfsprozess = {1} s (gemessen vor {2:N0} s)" -f $s.Id, (Get-Content $f -Raw).Trim(), ((Get-Date) - (Get-Item $f).LastWriteTime).TotalSeconds }
        else { "Sitzung {0}: noch keine Leerlauf-Messung vorhanden" -f $s.Id }
    }
    return
}

if ($TestOverlay) {
    if ($SessionId -lt 0) { "SessionId fehlt"; return }
    $cmd = "`"$PsExe`" -NoProfile -ExecutionPolicy Bypass -File `"$Dir\Bildschirm.ps1`" -TestSeconds $Seconds -Shot `"$Shot`""
    "Test-Start: " + [Wts]::StartInSession($SessionId, $cmd)
    return
}

if ($DemoWarnings) {
    # Demo: alle Vorwarnungen nacheinander in EINER Sitzung zeigen (je $Gap Sekunden), ohne den Zaehler anzufassen
    if ($SessionId -lt 0) { "SessionId fehlt"; return }
    $dg = [int]$GraceMin
    foreach ($dt in (@(($dg + 30), ($dg + 15), ($dg + 5), $dg, 5, 1) | Sort-Object -Descending -Unique)) {
        $dw = Get-WarnText $dt $dg
        [Wts]::Message($SessionId, 'NVIDIA Grafiktreiber', $dw.Text, ($Gap + 1), $dw.Style)
        Log ("Demo-Warnung gesendet (Schwelle {0}, Sitzung {1})" -f $dt, $SessionId)
        Start-Sleep -Seconds $Gap
    }
    return
}

# ---------------- normaler Lauf ----------------
$now    = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$dayKey = Get-DayKey
$state  = $null
if (Test-Path $StateFile) { try { $state = Get-Content $StateFile -Raw | ConvertFrom-Json } catch { } }
if (-not $state) {
    $state = [pscustomobject]@{ date = $dayKey; minutes = 0.0; sent = @(); last = $now }
    Log 'Zaehler neu angelegt'
}
if ($state.date -ne $dayKey) {
    # Tageswert des abgelaufenen Tages in den Verlauf schreiben, bevor der Zaehler auf 0 geht
    try {
        $hist = Join-Path $Dir 'verlauf.csv'
        if (-not (Test-Path $hist)) { 'Datum;Minuten;Stunden' | Out-File $hist -Encoding ascii }
        if ($state.date -and [double]$state.minutes -gt 0) {
            ('{0};{1};{2}' -f $state.date, [int]$state.minutes, [Math]::Round([double]$state.minutes / 60, 1)) | Out-File $hist -Append -Encoding ascii
            Log ("Verlauf gespeichert: {0} = {1} Min" -f $state.date, [int]$state.minutes)
        }
    } catch { Log "Verlauf-Fehler: $_" }
    $state = [pscustomobject]@{ date = $dayKey; minutes = 0.0; sent = @(); last = $now }
    Log ('Neuer Tag: Zaehler auf 0' + $(if (Test-FreeDay) { ' (freier Tag, kein Limit)' } else { '' }))
}
if (-not $state.PSObject.Properties['sent']) { $state | Add-Member -NotePropertyName sent -NotePropertyValue @() }
$sent = @($state.sent | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ })

# Zeit seit dem letzten Lauf (maximal 2 Minuten, damit ein ausgeschalteter PC nichts zaehlt)
$delta = [Math]::Min(2.0, [Math]::Max(0.0, ($now - [long]$state.last) / 60.0))
$state.last = $now

$G      = [int]$GraceMin
$lockAt = (Get-LimitMinForToday) + (Get-Bonus) + $G     # ab dieser Minute wird gesperrt (Limit + Bonus + Nachspielzeit)
if (Test-FreeDay) { $lockAt = [double]::PositiveInfinity }   # freier Tag (z. B. Wochenende): kein Limit, keine Warnung, keine Sperre; Minuten zaehlen nur fuer den Verlauf
$lockedNow = ([double]$state.minutes -ge $lockAt) -or (Test-Path (Join-Path $Dir 'force.flag'))   # schon gesperrt: keine Leerlauf-Messung (bis zu 10 s), Sperrbildschirm sofort starten
# Kandidaten: verbundene, nicht gesperrte Sitzungen. Aktiv = letzte Eingabe weniger als IdleMin Minuten her (gemessen IN der Sitzung).
# Ohne Messergebnis (Fehler) zaehlt die Sitzung vorsichtshalber als aktiv - so wie vor der Reparatur.
$cand    = @($sessions | Where-Object { $_.State -eq 0 -and $lockedIds -notcontains $_.Id -and (@($cfg.ExcludeUsers) -notcontains $_.User) })
$idleMap = @{}
$script:ProbeNote = ''
if ($cand.Count -gt 0 -and -not $lockedNow) { $idleMap = Get-SessionIdle $cand }
$active  = @($cand | Where-Object { -not $idleMap.ContainsKey($_.Id) -or $idleMap[$_.Id] -lt ($IdleMin * 60) })
$probeOk = (@($cand | Where-Object { -not $idleMap.ContainsKey($_.Id) }).Count -eq 0)
if (-not $state.PSObject.Properties['probeOk']) { $state | Add-Member -NotePropertyName probeOk -NotePropertyValue $null }
if ($cand.Count -gt 0 -and -not $lockedNow -and $state.probeOk -ne $probeOk) {
    if ($probeOk) { Log 'Leerlauf-Messung funktioniert (Hilfsprozess in der Sitzung)' }
    else { Log ('WARNUNG: Leerlauf-Messung ohne Ergebnis, Sitzung zaehlt vorsichtshalber als aktiv. ' + $script:ProbeNote) }
    $state.probeOk = $probeOk
}

$force = Test-Path (Join-Path $Dir 'force.flag')   # Zero-Befehl: Sperre von Hand ausloesen (Zerooff loescht die Datei)
if ([double]$state.minutes -lt $lockAt -and -not $force) {
    if ($active.Count -gt 0) { $state.minutes = [double]$state.minutes + $delta }
    $rest = $lockAt - [double]$state.minutes

    # Vorwarnungen: 30/15/5 Min vor Ende der Spielzeit, dann Nachspielzeit-Beginn, dann 5 und 1 Min vor der Sperre
    $steps = @(($G + 30), ($G + 15), ($G + 5), $G, 5, 1) | Sort-Object -Descending -Unique
    $sent  = @($sent | Where-Object { $rest -le $_ })                       # Schwellen wieder freigeben (z. B. nach Bonus)
    $due   = @($steps | Where-Object { $rest -le $_ -and $sent -notcontains $_ })
    if ($cfg.WarnSkipDay -eq $dayKey) { $keep = if ($cfg.WarnKeep) { @($cfg.WarnKeep | ForEach-Object { [double]$_ }) } else { @(1.0) }; $due = @($due | Where-Object { $keep -contains [double]$_ }) }   # Nutzerwunsch: an diesem Tag nur die Warnungen aus config WarnKeep (Minuten); ohne WarnKeep nur 1 Min. WarnSkipDay = Tagesschluessel; loeschen = alle Warnungen wieder an
    if ($due.Count -gt 0 -and $active.Count -gt 0) {
        $t = [int](($due | Measure-Object -Minimum).Minimum)                # dringendste faellige Schwelle
        # Die Warnungen tarnen sich als Grafiktreiber-Warnung; "Fehler in t Minuten" = Zeit bis zur Sperre
        if ($t -gt $G) {
            $txt = "GRAFIKTREIBER-WARNUNG`n`nDer NVIDIA-Grafiktreiber (nvlddmkm.sys) meldet Instabilität. Ein Grafikfehler wird in ca. {0} Minuten erwartet.`n`nBitte keine neuen Spiele oder Dateien starten." -f $t
            $sty = 0x30
        } elseif ($t -eq $G) {
            $txt = "WARNUNG: GRAFIKFEHLER IN CA. {0} MINUTEN`n`nDer Grafiktreiber ist instabil. Bitte KEINE Spiele oder Dateien starten, sonst kann der Fehler früher auftreten.`n`nALLE ANWENDUNGEN BEENDEN und nicht gespeicherte Daten sichern." -f $t
            $sty = 0x30
        } elseif ($t -gt 1) {
            $txt = "KRITISCH: GRAFIKFEHLER IN CA. {0} MINUTEN`n`nALLE ANWENDUNGEN JETZT BEENDEN! Nicht gespeicherte Daten gehen verloren." -f $t
            $sty = 0x10
        } else {
            $txt = "KRITISCH: GRAFIKFEHLER IN WENIGER ALS 1 MINUTE`n`nALLE ANWENDUNGEN SOFORT BEENDEN!"
            $sty = 0x10
        }
        foreach ($s in ($sessions | Where-Object { $_.State -eq 0 -and (@($cfg.ExcludeUsers) -notcontains $_.User) })) { [Wts]::Message($s.Id, 'NVIDIA Grafiktreiber', $txt, 60, $sty) }
        $sent = @($sent + $due)
        Log ("Warnung gesendet (Schwelle {0}): {1}" -f $t, ($txt -replace "`n", ' '))
    }
}
$state.sent = $sent
if ([double]$state.minutes -ge $lockAt -or $force) {
    # Limit erreicht: in jeder Sitzung den schwarzen Bildschirm starten (falls noch nicht aktiv)
    foreach ($s in $sessions) {
        if (-not (Test-OverlayRunning $s.Id) -and (@($cfg.ExcludeUsers) -notcontains $s.User)) {
            $cmd = "`"$PsExe`" -NoProfile -ExecutionPolicy Bypass -File `"$Dir\Bildschirm.ps1`""
            Log ("Limit erreicht ({0} Min). Sperrbildschirm fuer Sitzung {1} ({2}): {3}" -f [int]$state.minutes, $s.Id, $s.User, [Wts]::StartInSession($s.Id, $cmd))
        }
    }
}

# Wurde heute eine Bonus-Stunde per PIN vergeben, bleibt bis zum Tageswechsel der Grafikfehler-Modus aktiv (config "PinGlitch": false schaltet ab).
# Auch nach einem Neustart des PCs: der Bonus steht in bonus.txt und gilt nur fuer den aktuellen Tagesschluessel.
if ([double]$state.minutes -lt $lockAt -and -not $force -and $cfg.PinGlitch -ne $false -and (Get-Bonus) -gt 0) {
    foreach ($s in $sessions) {
        if ($s.State -eq 0 -and $lockedIds -notcontains $s.Id -and (@($cfg.ExcludeUsers) -notcontains $s.User) -and -not (Test-OverlayRunning $s.Id)) {
            $cmd = "`"$PsExe`" -NoProfile -ExecutionPolicy Bypass -File `"$Dir\Bildschirm.ps1`" -Glitch"
            Log ("Bonus aktiv: Grafikfehler-Modus fuer Sitzung {0} ({1}): {2}" -f $s.Id, $s.User, [Wts]::StartInSession($s.Id, $cmd))
        }
    }
}
$state | ConvertTo-Json | Out-File $StateFile -Encoding ascii

# Luecke nach Neustart/Anmeldung schliessen: Ist gesperrt, wird bis zu 90 s lang alle 2 s geprueft, ob eine Sitzung ohne Sperrbildschirm dazugekommen
# ist (Anmeldung nach dem Hochfahren) oder ein Sperrbildschirm beendet wurde; dann startet er sofort. Ausgenommene Benutzer nie. Ende bei Zerooff/Tageswechsel.
if ([double]$state.minutes -ge $lockAt -or $force) {
    $watchEnd = (Get-Date).AddSeconds(90)
    $lastLog = @{}
    while ((Get-Date) -lt $watchEnd) {
        Start-Sleep -Seconds 2
        if ($force -and -not (Test-Path (Join-Path $Dir 'force.flag'))) { break }      # Zerooff waehrend der Beobachtung
        if ((Get-DayKey) -ne $dayKey) { break }                                          # Tageswechsel: die naechste Runde entscheidet neu
        $live = @([Wts]::List() | ForEach-Object { $q = $_.Split(';'); [pscustomobject]@{ Id = [int]$q[0]; State = [int]$q[1]; User = $q[2] } } | Where-Object { $_.User -and $_.Id -ne 0 })
        foreach ($s in $live) {
            if ((@($cfg.ExcludeUsers) -contains $s.User) -or (Test-OverlayRunning $s.Id)) { continue }
            $cmd = "`"$PsExe`" -NoProfile -ExecutionPolicy Bypass -File `"$Dir\Bildschirm.ps1`""
            $r = [Wts]::StartInSession($s.Id, $cmd)
            $k = [string]$s.Id
            if ($r -like 'OK*' -or -not $lastLog.ContainsKey($k) -or ((Get-Date) - $lastLog[$k]).TotalSeconds -gt 20) {
                Log ("Sperrbildschirm nachgestartet fuer Sitzung {0} ({1}): {2}" -f $s.Id, $s.User, $r)
                $lastLog[$k] = Get-Date
            }
        }
    }
}
