# Guided Windows setup; installs copies of runtime scripts and registers a disabled-by-config SYSTEM task.
# Existing installations are never overwritten. Paired with Uninstall.ps1 and docs/INSTALLER.md.
#Requires -Version 5.1
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT' -or -not [Environment]::Is64BitProcess) { throw 'Use 64-bit Windows PowerShell as administrator.' }
$root = $PSScriptRoot
$dir = 'C:\ProgramData\Kindersperre'
$nv = 'C:\ProgramData\NVIDIA Corporation\NvContainer'
$taskName = 'Kindersperre'
$taskDescription = 'Windows Screen Time Manager - guided installer'
$compiler = Join-Path $env:windir 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { throw '.NET Framework C# compiler not found.' }
$psExe = "$env:windir\System32\WindowsPowerShell\v1.0\powershell.exe"

function Assert-SafePath([string]$Path) {
    $item = $Path
    while ($item) {
        if (Test-Path -LiteralPath $item) {
            if ((Get-Item -LiteralPath $item -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Linked path is not supported: $item" }
        }
        $item = Split-Path -Parent $item
    }
}
function Set-ProtectedAcl([string]$Path, [bool]$UserRead) {
    $acl = New-Object Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true, $false)
    $acl.SetOwner((New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')))
    foreach ($sid in 'S-1-5-18','S-1-5-32-544') {
        $rule = New-Object Security.AccessControl.FileSystemAccessRule((New-Object Security.Principal.SecurityIdentifier($sid)), 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
        $acl.AddAccessRule($rule)
    }
    if ($UserRead) {
        $rule = New-Object Security.AccessControl.FileSystemAccessRule((New-Object Security.Principal.SecurityIdentifier('S-1-5-32-545')), 'ReadAndExecute', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
        $acl.AddAccessRule($rule)
    }
    Set-Acl -LiteralPath $Path -AclObject $acl
}
function Read-Minutes([string]$Label, [int]$Default) {
    while ($true) {
        $answer = Read-Host "$Label [$Default]"
        if (-not $answer) { return $Default }
        $value = 0
        if ([int]::TryParse($answer, [ref]$value) -and $value -ge 1 -and $value -le 1440) { return $value }
        Write-Host 'Enter a number from 1 to 1440.'
    }
}
function Get-SecretHash([string]$Label) {
    while ($true) {
        $first = Read-Host "$Label (at least 6 characters)" -AsSecureString
        $second = Read-Host 'Repeat' -AsSecureString
        $a = [IntPtr]::Zero; $b = [IntPtr]::Zero
        try {
            $a = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($first)
            $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($second)
            $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($a)
            if ($plain.Length -lt 6 -or $plain -cne [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b)) { Write-Host 'Too short or entries differ.'; continue }
            $salt = New-Object byte[] 16
            $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
            try { $rng.GetBytes($salt) } finally { $rng.Dispose() }
            $derive = New-Object Security.Cryptography.Rfc2898DeriveBytes($plain, $salt, 100000)
            try { return @{ salt = [Convert]::ToBase64String($salt); hash = [Convert]::ToBase64String($derive.GetBytes(32)) } } finally { $derive.Dispose() }
        } finally {
            if ($a -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($a) }
            if ($b -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) }
            $plain = $null; $first.Dispose(); $second.Dispose()
        }
    }
}

Write-Host 'Windows Screen Time Manager - guided setup'
Write-Host 'Creates protected folders and a SYSTEM scheduled task. Monitoring starts OFF.'
Assert-SafePath $dir; Assert-SafePath $nv
if ((Test-Path -LiteralPath $dir) -or (Test-Path -LiteralPath $nv) -or (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)) { throw 'Existing folder/task found. Nothing changed. Use a fresh test PC; no upgrades are performed.' }
$files = @('Sperre.ps1','RuntimeFiles.ps1','Bildschirm.ps1','KsAdmin.ps1','Zero.ps1','Zerooff.ps1','Zerotest.ps1','IdleProbe.cs','assets\winlogo.png','NvContainer\NvBar.ps1','Uninstall.ps1','shot-bsod.png','shot-logo.png','shot-repair.png','shot-terminal.png')
foreach ($file in $files) { if (-not (Test-Path -LiteralPath (Join-Path $root $file) -PathType Leaf)) { throw "Missing file: $file. Extract the full repository ZIP first." } }
$userName = Read-Host 'Existing local administrator account name (not DOMAIN\name)'
if ($userName -notmatch '^[\p{L}\p{N}_.-]+$') { throw 'Use a local account name without spaces or special shell characters.' }
$user = Get-LocalUser -Name $userName
if (-not $user.Enabled) { throw 'The selected account is disabled.' }
$admins = @(Get-LocalGroupMember -SID 'S-1-5-32-544')
if ($admins.SID.Value -notcontains $user.SID.Value) { throw 'Select a direct member of the local Administrators group.' }
$weekday = Read-Minutes 'Weekday limit in minutes' 360
$weekend = Read-Minutes 'Weekend limit in minutes' 480
Write-Host 'All other signed-in accounts are monitored. No Windows passwords or accounts are changed.'
Write-Host "Administrator: $($user.Name); limits: $weekday / $weekend minutes"
$pin = Get-SecretHash 'Bonus/support PIN'
$toolPin = Get-SecretHash 'Administration tool password'
if ((Read-Host 'Create this installation? Type INSTALL') -cne 'INSTALL') { Write-Host 'Cancelled. Nothing changed.'; return }
# Recheck immediately before writing; never take ownership of an existing installation.
Assert-SafePath $dir; Assert-SafePath $nv
if ((Test-Path -LiteralPath $dir) -or (Test-Path -LiteralPath $nv) -or (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)) { throw 'Destination changed. Nothing changed.' }
$madeDir = $false; $madeNv = $false; $madeTask = $false
try {
    New-Item -ItemType Directory -Path $dir | Out-Null; $madeDir = $true
    Set-ProtectedAcl $dir $false
    New-Item -ItemType Directory -Path $nv -Force | Out-Null; $madeNv = $true
    Set-ProtectedAcl $nv $true
    New-Item -ItemType Directory -Path "$dir\assets","$dir\preview" | Out-Null
    foreach ($file in 'Sperre.ps1','RuntimeFiles.ps1','Bildschirm.ps1','KsAdmin.ps1','Zero.ps1','Zerooff.ps1','Zerotest.ps1','IdleProbe.cs','Uninstall.ps1') { Copy-Item -LiteralPath (Join-Path $root $file) -Destination $dir }
    & $compiler /nologo /target:exe /out:"$dir\IdleProbe.exe" "$dir\IdleProbe.cs"
    if ($LASTEXITCODE -ne 0) { throw 'IdleProbe compilation failed.' }
    Copy-Item -LiteralPath "$root\assets\winlogo.png" -Destination "$dir\assets"
    foreach ($file in 'shot-bsod.png','shot-logo.png','shot-repair.png','shot-terminal.png') { Copy-Item -LiteralPath (Join-Path $root $file) -Destination "$dir\preview" }
    Copy-Item -LiteralPath "$root\NvContainer\NvBar.ps1" -Destination $nv
    # Only installed copies are adapted; repository runtime files remain unchanged.
    foreach ($file in 'KsAdmin.ps1','Zerotest.ps1') {
        $path = Join-Path $dir $file
        $text = [IO.File]::ReadAllText($path).Replace("'Verwalter'", "'$($user.Name)'")
        [IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding($true)))
    }
    $cfg = @{ WeekdayLimitMin=$weekday; WeekendLimitMin=$weekend; ResetHour=6; IdleMin=5; GraceMin=15; BonusMin=60; FreeDays=@(); ExcludeUsers=@($user.Name); Enabled=$false }
    [IO.File]::WriteAllText("$dir\config.json", ($cfg | ConvertTo-Json), (New-Object Text.UTF8Encoding($true)))
    foreach ($entry in @(@{Name='pin.json';Data=$pin},@{Name='tool-pin.json';Data=$toolPin})) { $entry.Data | ConvertTo-Json -Compress | Out-File (Join-Path $dir $entry.Name) -Encoding ascii }
    @{ Installer='WindowsScreenTimeManager'; Version=1; AdminAccount=$user.Name } | ConvertTo-Json | Out-File "$dir\installer.json" -Encoding ascii
    $action = New-ScheduledTaskAction -Execute $psExe -Argument '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\ProgramData\Kindersperre\Sperre.ps1"'
    $triggers = @((New-ScheduledTaskTrigger -AtStartup),(New-ScheduledTaskTrigger -AtLogOn),(New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration (New-TimeSpan -Days 3650)))
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 2) -MultipleInstances IgnoreNew -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName $taskName -Description $taskDescription -Action $action -Trigger $triggers -Principal $principal -Settings $settings | Out-Null
    $madeTask = $true
    Write-Host 'Installed. Monitoring is OFF. Open settings from an elevated PowerShell:'
    Write-Host 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\ProgramData\Kindersperre\KsAdmin.ps1'
    Write-Host 'Review settings and preview on a test account before enabling monitoring.'
    Write-Host 'Uninstall: powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\ProgramData\Kindersperre\Uninstall.ps1'
} catch {
    if ($madeTask) { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue }
    if ($madeNv) { Remove-Item -LiteralPath $nv -Recurse -Force -ErrorAction SilentlyContinue }
    if ($madeDir) { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
    throw
} finally { $pin = $null; $toolPin = $null }
