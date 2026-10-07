# Parse all scripts and exercise pure persistence/recovery logic without tasks, UI or privileges.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$count = 0
function Assert-True($value, [string]$message) {
    if (-not $value) { throw $message }
    $script:count++
}
foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -Filter '*.ps1') {
    $tokens = $null; $errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    Assert-True ($errors.Count -eq 0) ("Syntax errors in " + $file.Name + ': ' + ($errors -join ', '))
}
. (Join-Path $root 'RuntimeFiles.ps1')
$dir = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($dir)
try {
    $path = Join-Path $dir 'state.json'
    Assert-True ($null -eq (Read-RuntimeState $path)) 'Fresh state should be empty'
    $first = '{"date":"2026-10-07","minutes":17.5,"last":1791331200}'
    $second = '{"date":"2026-10-07","minutes":18.5,"last":1791331260}'
    Write-AtomicText $path $first
    Write-AtomicText $path $second
    Assert-True ((Read-RuntimeState $path).minutes -eq 18.5) 'Latest state not read'
    Assert-True ([IO.File]::ReadAllText($path + '.bak') -eq $first) 'Previous state not retained'
    [IO.File]::WriteAllText($path, '{broken')
    Assert-True ((Read-RuntimeState $path -WarningAction SilentlyContinue).minutes -eq 17.5) 'Backup recovery failed'
    [IO.File]::WriteAllText($path + '.bak', '[]')
    $failed = $false
    try { Read-RuntimeState $path | Out-Null } catch { $failed = $true }
    Assert-True $failed 'Corrupt state must not reset the counter silently'
    Assert-True (@(Get-ChildItem $dir -Filter '*.tmp').Count -eq 0) 'Temporary files remain'

    # Load only the pure arithmetic function from its AST; never execute the SYSTEM engine.
    $tokens = $null; $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'Sperre.ps1'), [ref]$tokens, [ref]$errors)
    $fn = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Update-Regen' }, $true)
    . ([scriptblock]::Create($fn.Extent.Text))
    $state = [pscustomobject]@{minutes=60.0}
    $config = [pscustomobject]@{RegenEnabled=$true;RegenPerHourMin=30;RegenMinPauseMin=10;RegenMaxPerDayMin=20}
    $restored = Update-Regen $state $config 60 $false
    Assert-True ($restored -eq 20 -and $state.minutes -eq 40) 'Daily recovery cap failed'
    Assert-True ((Update-Regen $state $config 60 $true) -eq 0 -and $state.pause -eq 0) 'Recovery repeated beyond cap'

    $rearm = $ast.Find({ param($node) $node -is [Management.Automation.Language.AssignmentStatementAst] -and
        $node.Extent.Text -match '\$sent\s*=.*\$rest -le' }, $true)
    Assert-True ($null -ne $rearm) 'Warning rearm assignment was swallowed by a comment'
    $sent = @(15, 5); $rest = 20
    . ([scriptblock]::Create($rearm.Extent.Text))
    Assert-True ($sent.Count -eq 0) 'A bonus must rearm previously sent warning thresholds'

    $loadConfig = $ast.Find({ param($node) $node -is [Management.Automation.Language.AssignmentStatementAst] -and
        $node.Extent.Text -match '\$cfg\s*=.*Get-Content' }, $true)
    [IO.File]::WriteAllText((Join-Path $dir 'config.json'), '{bad')
    $failed = $false
    try { . ([scriptblock]::Create($loadConfig.Extent.Text)) } catch { $failed = $true }
    Assert-True $failed 'Malformed configuration must stop the engine before it acts'
} finally { [IO.Directory]::Delete($dir, $true) }
Write-Host "$count assertions passed. No installer, task, lock screen or Win32 session call executed."
