$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/../State.ps1"
function Assert-Action($Expected,$Exists,$Visible,$Minimized,$Armed,$InTray,$Label) {
 $result = Get-RazerWindowDecision $Exists $Visible $Minimized $Armed $InTray
 if ($result.Action -ne $Expected) { throw "FAIL $Label expected $Expected got $($result.Action)" }
 Write-Output "PASS $Label"
}
Assert-Action 'Tray' $true $true $true $true $false 'minus hides the minimized window to tray'
Assert-Action 'Keep' $true $false $true $true $true 'helper-hidden minimized window stays alive'
Assert-Action 'Exit' $true $false $false $true $false 'X hiding the normal window fully exits'
Assert-Action 'Exit' $false $false $false $true $false 'X destroying the window fully exits'
Assert-Action 'Keep' $true $false $false $false $false 'initial hidden startup is not mistaken for X'
Assert-Action 'Restore' $true $true $false $true $true 'tray restore resets the tray marker'
Assert-Action 'Exit' $true $false $false $true $false 'X after tray restore exits'
Assert-Action 'Keep' $true $true $false $true $false 'ordinary visible window remains untouched'
Write-Output '8 window behavior checks passed.'
