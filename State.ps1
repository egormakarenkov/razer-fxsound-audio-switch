function Get-RazerWindowDecision {
    param([bool]$Exists,[bool]$Visible,[bool]$Minimized,[bool]$Armed,[bool]$InTray)
    $action = 'Keep'
    if ($Exists -and $Visible -and -not $Minimized -and $InTray) { $action = 'Restore' }
    elseif ($Exists -and $Minimized -and -not $InTray) { $action = 'Tray' }
    elseif ($Armed -and -not $InTray -and (-not $Exists -or (-not $Visible -and -not $Minimized))) { $action = 'Exit' }
    [pscustomobject]@{Action=$action}
}

function Get-AudioModeDecision {
    param([bool]$RazerRunning, [AllowNull()][string]$PreviousMode, [string[]]$ActiveIds, $Config)
    $mode = if ($RazerRunning) { 'surround' } else { 'normal' }
    $target = if ($RazerRunning) { $Config.SurroundId } else { $Config.FxId }
    $action = 'Switch'
    if ($mode -eq $PreviousMode) { $action = 'None' }
    elseif ($target -notin $ActiveIds -or ($RazerRunning -and
        ($Config.FxId -notin $ActiveIds -or $Config.PhysicalId -notin $ActiveIds))) { $action = 'Wait' }
    [pscustomobject]@{ Mode=$mode; TargetId=$target; Action=$action }
}
