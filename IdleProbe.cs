// IdleProbe - Hilfsprogramm der Kindersperre.
// Wird von Sperre.ps1 jede Minute als SYSTEM IN der Benutzersitzung gestartet und schreibt die Sekunden seit der
// letzten Tastatur-/Mauseingabe DIESER Sitzung (GetLastInputInfo) in die als Argument uebergebene Datei.
// Hintergrund: Die WTS-API liefert fuer die Konsolen-Sitzung keine Eingabezeit (LastInputTime = 0), deshalb war der
// Leerlauf-Schutz vorher wirkungslos.
// Bauen: C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /target:winexe /out:IdleProbe.exe IdleProbe.cs
using System;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;

static class IdleProbe
{
    [StructLayout(LayoutKind.Sequential)]
    struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }

    [DllImport("user32.dll")]
    static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

    static int Main(string[] args)
    {
        if (args.Length < 1) return 2;
        var li = new LASTINPUTINFO();
        li.cbSize = (uint)Marshal.SizeOf(typeof(LASTINPUTINFO));
        if (!GetLastInputInfo(ref li)) return 3;
        double idle = unchecked((uint)Environment.TickCount - li.dwTime) / 1000.0;
        string tmp = args[0] + ".tmp";
        File.WriteAllText(tmp, idle.ToString("0.0", CultureInfo.InvariantCulture));
        if (File.Exists(args[0])) File.Delete(args[0]);
        File.Move(tmp, args[0]);   // erst fertig schreiben, dann umbenennen: Sperre.ps1 liest nie eine halbe Datei
        return 0;
    }
}
