$ErrorActionPreference = 'Stop'
$stateRoot = Join-Path $env:LOCALAPPDATA 'RazerFxAudioSwitch'
$pidFile = Join-Path $stateRoot 'watcher.pid'
if (Test-Path -LiteralPath $pidFile) {
    $watcherId = [int](Get-Content -LiteralPath $pidFile)
    $watcher = Get-CimInstance Win32_Process -Filter "ProcessId=$watcherId"
    if ($watcher -and $watcher.CommandLine -like '*RazerFxAudioSwitch*Watch-Audio.ps1*') {
        Stop-Process -Id $watcherId -ErrorAction SilentlyContinue
    }
}
Remove-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name RazerFxAudioSwitch -ErrorAction SilentlyContinue
Add-Type -Path (Join-Path $stateRoot 'AudioInterop.cs')
$config = Get-Content -LiteralPath (Join-Path $stateRoot 'config.json') -Raw | ConvertFrom-Json
# Leave a working normal audio route before restoring the former takeover behavior.
if (Get-Process -Name FxSound -ErrorAction SilentlyContinue) { Stop-Process -Name FxSound }
$backup = Join-Path $stateRoot 'backup'
$before = Get-Content -LiteralPath (Join-Path $backup 'before.json') -Raw | ConvertFrom-Json
Copy-Item -LiteralPath (Join-Path $backup 'FxSound.settings') -Destination (Join-Path $env:APPDATA 'FxSound\FxSound.settings') -Force
foreach ($newKey in @('default_device_mode','user_selected_playback')) {
    # These two keys were absent in the original backup for this installation.
    Remove-Item -LiteralPath (Join-Path $config.DeviceRegistry $newKey) -ErrorAction SilentlyContinue
}
& reg.exe import (Join-Path $backup 'DFX-devices.reg') | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not restore the saved FxSound registry settings.' }
if ($before.RazerStartup) {
    New-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name RzAppEngine -Value $before.RazerStartup -PropertyType String -Force | Out-Null
}
[RazerFx.Audio]::SetDefault($config.FxId)
Start-Process -FilePath $config.FxPath -ArgumentList '--run_minimized'
Write-Output 'Automatic switching removed. FxSound settings and the Razer startup registration restored. Backup and helper files retained.'
