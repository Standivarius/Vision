$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$state=Join-Path $root 'Get-DoxaSetupExperience.ps1'
$ui=Join-Path $root 'Start-DoxaSetup.ps1'
$original=& $state -Fault none | Out-String | ConvertFrom-Json
if($original.test_only){throw 'Live observation was mislabelled simulated'}
$map=@{
 driver_missing='install_verified_driver'
 display_missing='recheck_power_cable_and_windows_display_mode'
 policy_blocked='request_it_approval'
 package_mismatch='reject_package_and_use_signed_original'
 support_offline='use_local_diagnostics'
}
foreach($key in $map.Keys) {
 $row=& $state -Fault $key -Language en | Out-String | ConvertFrom-Json
 if(-not $row.test_only -or $row.code -ne $key -or $row.suggested_action -ne $map[$key]) {throw ('Fault guard failed: '+$key)}
 if($row.observed.driver_version -ne $original.observed.driver_version) {throw ('Fault overwrote live driver baseline: '+$key)}
 if($row.observed.active_desktops -ne $original.observed.active_desktops) {throw ('Fault overwrote live desktop count: '+$key)}
}
$romanian=& $state -Language ro -Fault display_missing | Out-String | ConvertFrom-Json
if(-not $romanian.test_only -or $romanian.message -notmatch 'Verifica'){throw 'Romanian response failed'}
$smoke=& $ui -Smoke | Out-String | ConvertFrom-Json
if($smoke.smoke -ne 'PASS' -or $smoke.fault_count -ne 5 -or $smoke.driver_changes_without_user_action){throw 'UI smoke failed'}
if($smoke.developer_controls_visible -or $smoke.advanced_visible -or $smoke.reset_visible){throw 'Developer controls exposed in the user interface'}
if($smoke.chat_height -lt 290){throw 'Chat panel was not expanded for regular users'}
# Model the desktop seen through RDP independently of physically detected panels.
# This is a diagnostic test seam, not an alternate production data source.
$temp=Join-Path ([IO.Path]::GetTempPath()) ('doxa-evidence-'+[Guid]::NewGuid().ToString('N')+'.json')
function Read-Fixture([string]$session,[int]$desktops,[bool]$panelsMissing=$false){
 $names=@()
 for($n=0;$n -lt $desktops;$n++){$names+=('\\.\DISPLAY'+($n+1))}
 $fixture=[ordered]@{
  origin='fixture';session_kind=$session;status='signed_driver_present_monitors_detected'
  windows_build=26300; active_windows_desktop_count=$desktops
  active_windows_desktop_names=$names;doxa_panels_detected=@('Generic Monitor (L)','Generic Monitor (T)','Generic Monitor (R)')
  doxa_panels_missing=@()
  driver=[ordered]@{version='4.7.6.0';inf='oem101.inf';signed=$true}
 }
 if($panelsMissing){
  $fixture.status='signed_driver_present_monitors_missing'
  $fixture.doxa_panels_detected=@('Generic Monitor (L)','Generic Monitor (T)')
  $fixture.doxa_panels_missing=@('Generic Monitor (R)')
 }
 [IO.File]::WriteAllText($temp,($fixture | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
 return (& $state -EvidencePath $temp | Out-String | ConvertFrom-Json)
}
try{
 $remote=Read-Fixture 'remote' 1
 if($remote.code -ne 'hardware_ready_remote_display_unverified' -or -not $remote.observed.hardware_ready -or $remote.observed.physical_display_topology_verified){throw 'RDP incorrectly classified missing screen / console verified'}
 $enterprise=& (Join-Path $root 'Get-DoxaEnterprisePreflight.ps1') -EvidencePath $temp | Out-String | ConvertFrom-Json
 if($enterprise.decision_code -ne 'verified_signed_driver_and_hardware' -or $enterprise.machine_mutation_performed){throw 'Enterprise wrongly treats RDP as hardware failure'}
 $console=Read-Fixture 'console' 4
 if($console.code -ne 'ready' -or -not $console.observed.physical_display_topology_verified){throw 'Console four-source positive fixture rejected'}
 # A future signed driver must not be treated as untrusted or trigger reinstall.
 $future=Get-Content -LiteralPath $temp -Raw -Encoding UTF8|ConvertFrom-Json
 $future.driver.version='4.7.7.2000'
 [IO.File]::WriteAllText($temp,($future|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
 $nextSigned=(& $state -EvidencePath $temp|Out-String)|ConvertFrom-Json
 if($nextSigned.code -ne 'ready' -or -not $nextSigned.observed.signed_driver_present -or
    $nextSigned.observed.driver_version_qualification -ne 'signed_version_unreviewed' -or
    -not $nextSigned.observed.driver_version_review_needed){throw 'Future signed version incorrectly blocked or auto-approved'}
 $nextEnterprise=(& (Join-Path $root 'Get-DoxaEnterprisePreflight.ps1') -EvidencePath $temp |Out-String)|ConvertFrom-Json
 if($nextEnterprise.decision_code -ne 'verified_signed_driver_and_hardware' -or
    -not $nextEnterprise.driver_version_review_needed -or
    $nextEnterprise.signed_package_approval -ne 'not_granted'){throw 'Enterprise version qualification broken'}
 $future.driver.signed=$false
 [IO.File]::WriteAllText($temp,($future|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
 $untrusted=(& $state -EvidencePath $temp|Out-String)|ConvertFrom-Json
 if($untrusted.code -ne 'driver_untrusted' -or $untrusted.observed.signed_driver_present){throw 'Unsigned driver accepted'}
 $consoleShort=Read-Fixture 'console' 1
 if($consoleShort.code -ne 'display_topology_unverified' -or -not $consoleShort.observed.hardware_ready){throw 'Console display mismatch not isolated from hardware'}
 $remoteMissing=Read-Fixture 'remote' 1 $true
 if($remoteMissing.code -ne 'doxa_panels_missing'){throw 'Actual missing PnP panel overlooked in remote session'}
 $enterpriseMissing=& (Join-Path $root 'Get-DoxaEnterprisePreflight.ps1') -EvidencePath $temp | Out-String | ConvertFrom-Json
 if($enterpriseMissing.decision_code -ne 'driver_present_some_panels_unavailable'){throw 'Enterprise would reinstall despite signed driver and partial hardware'}
} finally {Remove-Item -LiteralPath $temp -ErrorAction SilentlyContinue}
$after=& $state -Fault none | Out-String | ConvertFrom-Json
if($after.observed.driver_version -ne $original.observed.driver_version){throw 'Live driver version changed during tests'}
'PERSONAL_SETUP_READONLY_TESTS=PASS'
'OBSERVED_SESSION='+$after.observed.session_kind
'OBSERVED_STATUS='+$after.code
'OBSERVED_DRIVER='+$after.observed.driver_version
'FAULT_OVERLAYS_PASSED='+$map.Count
'SESSION_FIXTURES_PASSED=4'
'ENTERPRISE_READONLY_FIXTURES_PASSED=2'
'NO_DRIVER_OR_DISPLAY_CHANGES=True'
