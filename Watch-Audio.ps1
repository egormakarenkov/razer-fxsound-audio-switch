$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$mutex = New-Object Threading.Mutex($false, 'Local\RazerFxAudioSwitch')
$ownsMutex = $false
try {
    try { $ownsMutex = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $ownsMutex = $true }
    if (-not $ownsMutex) { exit }
    $stateRoot = Join-Path $env:LOCALAPPDATA 'RazerFxAudioSwitch'
    New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null
    $logPath = Join-Path $stateRoot 'switch.log'
    function Write-SwitchLog([string]$Message) {
        if ((Test-Path -LiteralPath $logPath) -and (Get-Item -LiteralPath $logPath).Length -gt 262144) {
            Move-Item -LiteralPath $logPath -Destination ($logPath + '.previous') -Force
        }
        Add-Content -LiteralPath $logPath -Value ('{0:o} {1}' -f (Get-Date), $Message)
    }
    $PID | Set-Content -LiteralPath (Join-Path $stateRoot 'watcher.pid')
    $config = Get-Content -LiteralPath (Join-Path $root 'config.json') -Raw | ConvertFrom-Json
    . (Join-Path $root 'State.ps1')
    Add-Type -Path (Join-Path $root 'AudioInterop.cs')
    Add-Type -Path (Join-Path $root 'WindowInterop.cs')
    $deviceReg = $config.DeviceRegistry
    $modeKey = Join-Path $deviceReg 'default_device_mode'
    $pinKey = Join-Path $deviceReg 'user_selected_playback'
    New-Item -Path $modeKey -Force | Out-Null
    Set-Item -LiteralPath $modeKey -Value 'off'
    $previousMode = $null
    $trackedIds = @()
    $windowStates = @{}
    $failureCount = 0
    $lastMessage = ''
    $lastAttempt = [datetime]::MinValue
    Write-SwitchLog 'Started v2. X exits Razer; minus hides to its existing tray icon and keeps surround active.'
    while ($true) {
        try {
            $processes = @(Get-Process -Name rzappengine -ErrorAction SilentlyContinue | Where-Object {
                $_.SessionId -eq [Diagnostics.Process]::GetCurrentProcess().SessionId -and
                $_.Path -eq $config.RazerPath
            })
            # Enumerating native window state requires no mouse, keyboard, screenshots or focus changes.
            # Match the exact surround window and retain its identity while it is hidden.
            $liveIds = @($processes | ForEach-Object { $_.Id })
            foreach ($oldId in @($windowStates.Keys)) {
                if ($oldId -notin $liveIds) { $windowStates.Remove($oldId) }
            }
            foreach ($process in $processes) {
                $processId = $process.Id
                if (-not $windowStates.ContainsKey($processId)) {
                    $native = [RazerFx.Windows]::Find($processId)
                    if (-not $native.Exists) { continue }
                    $windowStates[$processId] = @{Handle=$native.Handle;Armed=$false;InTray=$false}
                }
                $windowState = $windowStates[$processId]
                $native = [RazerFx.Windows]::Read($windowState.Handle,$processId)
                if ($native.Visible -and -not $native.Minimized) { $windowState.Armed = $true }
                $windowDecision = Get-RazerWindowDecision $native.Exists $native.Visible $native.Minimized $windowState.Armed $windowState.InTray
                switch ($windowDecision.Action) {
                    'Tray' {
                        [RazerFx.Windows]::Hide($native.Handle)
                        $windowState.InTray = $true
                        $windowState.Armed = $true
                        Write-SwitchLog ('Minus: hid Razer window to tray; PID=' + $processId)
                    }
                    'Restore' {
                        $windowState.InTray = $false
                        Write-SwitchLog ('Restored Razer from tray; PID=' + $processId)
                    }
                    'Exit' {
                        # WM_CLOSE is already handled by Razer as hide-to-tray. End only the
                        # verified surround application process to give X its requested meaning.
                        Stop-Process -Id $processId -ErrorAction Stop
                        $windowStates.Remove($processId)
                        $liveIds = @($liveIds | Where-Object { $_ -ne $processId })
                        Write-SwitchLog ('X: exited Razer application; PID=' + $processId)
                    }
                }
            }
            $trackedIds = @($trackedIds | Where-Object { $_ -in $liveIds })
            $trackedIds = @(@($trackedIds) + @($windowStates.Keys) | Select-Object -Unique)
            $running = $trackedIds.Count -gt 0
            # Endpoint enumeration is only needed while a mode transition is pending.
            $desiredMode = if ($running) { 'surround' } else { 'normal' }
            if ($desiredMode -eq $previousMode) { Start-Sleep -Milliseconds 250; continue }
            $active = @([RazerFx.Audio]::List() | ForEach-Object { $_.Id })
            $decision = Get-AudioModeDecision $running $previousMode $active $config
            if ($decision.Action -eq 'Wait') {
                $message = 'Waiting for active endpoints for ' + $decision.Mode + '; default left unchanged.'
                if ($message -ne $lastMessage) { Write-SwitchLog $message; $lastMessage = $message }
            }
            elseif ($decision.Action -eq 'Switch' -and
                ((Get-Date) - $lastAttempt).TotalSeconds -ge ([Math]::Min(30, [Math]::Pow(2, $failureCount)))) {
                $lastAttempt = Get-Date
                # Pin the physical downstream endpoint before any default change.
                # Otherwise FxSound treats Razer itself as a new downstream target.
                New-Item -Path $pinKey -Force | Out-Null
                Set-Item -LiteralPath $pinKey -Value $config.PhysicalId
                if ($running) {
                    $razerSettings = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Razer\Surround\Settings\HP'
                    if ($razerSettings.HPVirtAudDeviceId -ne $config.FxId) {
                        throw 'Razer output is no longer FxSound. Restore FxSound in the Razer output selector.'
                    }
                    if (-not (Get-Process -Name FxSound -ErrorAction SilentlyContinue)) {
                        Start-Process -FilePath $config.FxPath -ArgumentList '--run_minimized'
                        Start-Sleep -Seconds 2
                    }
                }
                [RazerFx.Audio]::SetDefault($decision.TargetId)
                Start-Sleep -Milliseconds 1200
                if ([RazerFx.Audio]::Default(1) -ne $decision.TargetId) {
                    throw 'Windows did not retain the requested default output.'
                }
                if (-not $running) {
                    # Normal FxSound output selection remains available when Razer is closed.
                    Set-Item -LiteralPath $pinKey -Value ''
                }
                $previousMode = $decision.Mode
                $failureCount = 0
                $lastMessage = ''
                Write-SwitchLog ('Mode={0}; default={1}; RazerPids={2}' -f $previousMode,$decision.TargetId,($trackedIds -join ','))
                @{ Mode=$previousMode; DefaultId=$decision.TargetId; UpdatedAt=(Get-Date -Format o); PID=$PID } |
                    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stateRoot 'state.json')
            }
        }
        catch {
            $failureCount = [Math]::Min(5, $failureCount + 1)
            $message = $_.Exception.Message
            if ($message -ne $lastMessage) { Write-SwitchLog ('ERROR: ' + $message); $lastMessage = $message }
        }
        Start-Sleep -Milliseconds 250
    }
}
finally {
    if ($ownsMutex) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
