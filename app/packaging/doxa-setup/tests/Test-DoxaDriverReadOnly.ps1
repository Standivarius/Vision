# Deterministic read-only regression tests for live Doxa hardware adapter.
# Does not modify Windows, invoke MSI, install drivers or alter display topology.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Split-Path -Parent $PSScriptRoot
$getter=Join-Path $root 'Get-DoxaDriverState.ps1'
$deploy=Join-Path $root 'Deploy-DoxaDriverPackage.ps1'
$cases=@(
 @{name='signed-complete'; expected='signed_driver_present_monitors_detected'},
 @{name='unsigned-rejected'; expected='driver_identity_or_signature_mismatch'},
 @{name='missing-driver'; expected='driver_missing'},
 @{name='missing-doxa-panel'; expected='signed_driver_present_monitors_missing'}
)
foreach($case in $cases){
 $input=Join-Path $PSScriptRoot ($case.name+'.json')
 $json = & $getter -SnapshotPath $input | Out-String
 $state=$json|ConvertFrom-Json
 if($state.status -ne $case.expected){
  throw "$($case.name): expected $($case.expected) but got $($state.status)"
 }
 if($state.origin -ne 'fixture' -or $state.independent_windows_desktops_verified -ne $false){
  throw "$($case.name): simulated data must never be claimed as verified live topology"
 }
 Write-Output ("PASS {0}" -f $case.name)
}
$assess = & $deploy | Out-String | ConvertFrom-Json
# Live Windows source enumeration must be reported, not hard-coded to false
# (unlike fixture-based monitor lists which cannot prove independence).
Add-Type -AssemblyName System.Windows.Forms
$actualSources = @([System.Windows.Forms.Screen]::AllScreens).Count
if ($assess.active_windows_desktop_count -ne $actualSources) {
 throw 'Live driver audit source count disagrees with current Windows display session'
}
$expectedIndependence = ($assess.status -eq 'signed_driver_present_monitors_detected' -and
 $actualSources -ge 4)
if ([bool]$assess.independent_windows_desktops_verified -ne [bool]$expectedIndependence) {
 throw 'Live independent-desktop evidence must agree with current Windows active sources'
}
Write-Output ("PASS live_desktop_source_count ({0})" -f $actualSources)
if($assess.origin -ne 'live' -or $assess.profile_qualification -ne 'observed_not_oem_approved' -or
 $assess.package_approved_for_distribution -ne $false){
 throw 'Deploy dry run must report live machine and not claim OEM package approval'
}
Write-Output 'PASS live_deploy_dry_run'
Write-Output 'PASS 6 read-only Doxa driver tests'
