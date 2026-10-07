# Shared file persistence for Sperre.ps1 and KsAdmin.ps1; no Windows UI or task side effects.
function Write-AtomicText([string]$Path, [string]$Text) {
    $temp = $Path + '.' + [Guid]::NewGuid().ToString('N') + '.tmp'
    try {
        [IO.File]::WriteAllText($temp, $Text, (New-Object Text.UTF8Encoding($true)))
        if ([IO.File]::Exists($Path)) {
            [IO.File]::Replace($temp, $Path, $Path + '.bak')
        } else {
            [IO.File]::Move($temp, $Path)
        }
    } finally {
        if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) }
    }
}

function Read-RuntimeState([string]$Path) {
    if (-not [IO.File]::Exists($Path) -and -not [IO.File]::Exists($Path + '.bak')) { return $null }
    foreach ($candidate in @($Path, ($Path + '.bak'))) {
        if (-not [IO.File]::Exists($candidate)) { continue }
        try {
            $raw = [IO.File]::ReadAllText($candidate)
            if (-not $raw.TrimStart().StartsWith('{')) { throw 'State root must be an object' }
            $state = $raw | ConvertFrom-Json -ErrorAction Stop
            $number = 0.0
            $last = 0L
            if (-not $state -or $state.date -notmatch '^\d{4}-\d{2}-\d{2}$' -or
                -not [double]::TryParse([string]$state.minutes, [Globalization.NumberStyles]::Float,
                    [Globalization.CultureInfo]::InvariantCulture, [ref]$number) -or
                [double]::IsNaN($number) -or [double]::IsInfinity($number) -or
                -not [long]::TryParse([string]$state.last, [ref]$last) -or $last -lt 0) { throw 'Invalid state shape' }
            [void][datetime]::ParseExact($state.date, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
            if ($candidate -ne $Path) { Write-Warning 'Usage state damaged; using the previous saved state.' }
            return $state
        } catch { }
    }
    throw 'Usage state and backup are unreadable. Restore a saved state; the counter was not reset.'
}
