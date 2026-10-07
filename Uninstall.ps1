# Removes only a guided installation after explicit terminal confirmation; can retain private data.
#Requires -Version 5.1
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'Windows only.' }
$dir = 'C:\ProgramData\Kindersperre'
$nv = 'C:\ProgramData\NVIDIA Corporation\NvContainer'
foreach ($path in $dir,$nv) {
    $current = $path
    while ($current) {
        if ((Test-Path -LiteralPath $current) -and ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Linked path not supported: $current" }
        $current = Split-Path -Parent $current
    }
    if (Test-Path -LiteralPath $path) {
        if (Get-ChildItem -LiteralPath $path -Recurse -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }) { throw 'Linked files found. Removal aborted.' }
    }
}
if (Get-ScheduledTask -TaskName 'KS-Einmaltest' -ErrorAction SilentlyContinue) { throw 'Finish the preview/test task before uninstalling.' }
$manifest = Get-Content "$dir\installer.json" -Raw | ConvertFrom-Json
if ($manifest.Installer -ne 'WindowsScreenTimeManager' -or $manifest.Version -ne 1) { throw 'Not an installation created by this installer.' }
$task = Get-ScheduledTask -TaskName Kindersperre -ErrorAction SilentlyContinue
if ($task -and ($task.Description -ne 'Windows Screen Time Manager - guided installer' -or $task.Actions.Arguments -notlike '*C:\ProgramData\Kindersperre\Sperre.ps1*')) { throw 'Task has changed; removal aborted.' }
Write-Host 'Removes the scheduled task and installed application files. Windows accounts/passwords are untouched.'
if ((Read-Host 'Type UNINSTALL to continue') -cne 'UNINSTALL') { return }
$removeData = (Read-Host 'Also erase PIN hashes, settings and usage history? Type DELETE; Enter keeps them') -ceq 'DELETE'
if ($task) { Disable-ScheduledTask -TaskName Kindersperre | Out-Null; Stop-ScheduledTask -TaskName Kindersperre -ErrorAction SilentlyContinue; Unregister-ScheduledTask -TaskName Kindersperre -Confirm:$false }
# Match only processes whose explicit script argument belongs to the fixed installation paths.
$targets = @("$dir\Sperre.ps1","$dir\Bildschirm.ps1","$dir\KsAdmin.ps1","$dir\Zerotest.ps1","$dir\Zero.ps1","$dir\Zerooff.ps1","$nv\NvBar.ps1")
foreach ($process in Get-CimInstance Win32_Process) {
    if ($process.ProcessId -eq $PID -or $process.Name -notin 'powershell.exe','IdleProbe.exe') { continue }
    $owned = $process.ExecutablePath -eq "$dir\IdleProbe.exe"
    foreach ($target in $targets) {
        if ($process.CommandLine -match ('(?i)-File\s+(?:"' + [regex]::Escape($target) + '"|' + [regex]::Escape($target) + '(?=\s|$))')) { $owned = $true }
    }
    if ($owned) { Stop-Process -Id $process.ProcessId -Force -ErrorAction Stop }
}
if ($removeData) {
    Remove-Item -LiteralPath $dir -Recurse -Force
    if (Test-Path -LiteralPath $nv) { Remove-Item -LiteralPath $nv -Recurse -Force }
} else {
    foreach ($file in 'Sperre.ps1','RuntimeFiles.ps1','Bildschirm.ps1','KsAdmin.ps1','Zero.ps1','Zerooff.ps1','Zerotest.ps1','IdleProbe.cs','IdleProbe.exe') { Remove-Item -LiteralPath (Join-Path $dir $file) -Force -ErrorAction SilentlyContinue }
    foreach ($folder in 'assets','preview') { Remove-Item -LiteralPath (Join-Path $dir $folder) -Recurse -Force -ErrorAction SilentlyContinue }
    Remove-Item -LiteralPath "$nv\NvBar.ps1" -Force -ErrorAction SilentlyContinue
    Write-Host 'Private data and this uninstaller remain in the protected folder. Reinstallation refuses existing folders.'
}
Write-Host 'Uninstallation finished.'
