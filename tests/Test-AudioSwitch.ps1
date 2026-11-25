$ErrorActionPreference='Stop'
. "$PSScriptRoot/../State.ps1"
$config=[pscustomobject]@{SurroundId='surround';FxId='fx';PhysicalId='usb'}
$ids=@('surround','fx','usb')
function Assert-Equal($Actual,$Expected,$Label) {
 if($Actual -cne $Expected){throw "FAIL $Label : expected '$Expected', got '$Actual'"}
 Write-Output "PASS $Label"
}
$d=Get-AudioModeDecision $true 'normal' $ids $config
Assert-Equal $d.TargetId 'surround' 'opening Razer selects surround'
Assert-Equal $d.Action 'Switch' 'opening triggers one transition'
$d=Get-AudioModeDecision $true 'surround' $ids $config
Assert-Equal $d.Action 'None' 'minimizing leaves running process active without reapplying defaults'
$d=Get-AudioModeDecision $false 'surround' $ids $config
Assert-Equal $d.TargetId 'fx' 'exiting restores FxSound'
$d=Get-AudioModeDecision $false 'normal' $ids $config
Assert-Equal $d.Action 'None' 'normal idle permits manual output choices'
$d=Get-AudioModeDecision $true 'normal' @('fx','surround') $config
Assert-Equal $d.Action 'Wait' 'missing headset prevents invalid surround chain'
$d=Get-AudioModeDecision $false 'surround' @('fx') $config
Assert-Equal $d.Action 'Switch' 'exit can restore FxSound even when headset disconnected'
$d=Get-AudioModeDecision $false $null $ids $config
Assert-Equal $d.TargetId 'fx' 'sign-in starts in normal mode without launching Razer'
Write-Output '8 behavioral checks passed.'
