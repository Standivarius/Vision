# Safe regression gate for Sonnet remediation. No MSI, UAC, deployment,
# screenshot, remote AI or live monitor mutation.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Split-Path -Parent $PSScriptRoot
$hostSource=Get-Content (Join-Path $root 'full-release\DoxaSetupHost.cs') -Raw -Encoding UTF8
if($hostSource -notmatch 'Apply\(arg=="/prepare"\)' -or
   $hostSource -notmatch 'DriverDeferredUntilConnected' -or
   $hostSource -notmatch 'MayRunVendorMsi\(applicationOnly,plugged,current\)' -or
   $hostSource -notmatch 'Open\(true\)'){
 throw 'Source-only guard: personal setup, offline defer or consent handoff missing'
}
$state=Join-Path $root 'Get-DoxaDriverState.ps1'
$profile=Get-Content (Join-Path $root 'profiles\smi770-observed.json') -Raw -Encoding UTF8|ConvertFrom-Json
$dir=Join-Path $env:TEMP ('doxa-sonnet-fixture-'+[Guid]::NewGuid().ToString('N'))
New-Item $dir -ItemType Directory|Out-Null
try{
 $f=Join-Path $dir 'device-state.json'
 $snap=[ordered]@{
  os_build=26100
  monitors=@($profile.expected_monitor_names|ForEach-Object{@{name=$_}})
  drivers=@()
 }
 $baseline=@{
  device_id=([string]$profile.hardware_id_prefix+'&MI_00\TEST')
  device_name='Doxa fixture USB display'
  provider='SiliconMotion'
  version='4.7.6.8001'
  inf='smiiddx770.inf'
  signed=$true
  signer=[string]$profile.expected_driver_signer
 }
 function Inspect([object]$binding){
  $snap.drivers=if($null -eq $binding){@()}else{@($binding)}
  [IO.File]::WriteAllText($f,($snap|ConvertTo-Json -Depth 10),[Text.UTF8Encoding]::new($false))
  return ((& $state -SnapshotPath $f|Out-String)|ConvertFrom-Json)
 }

 $alias=$baseline.Clone();$alias.provider='Silicon Motion, Inc.'
 $generic=$baseline.Clone();$generic.provider='Microsoft';$generic.signed=$true
 $unknown=$baseline.Clone();$unknown.provider='Foreign Display Vendor';$unknown.signed=$true
 $unsigned=$baseline.Clone();$unsigned.signed=$false
 $tests=@(
  @{name='vendor';value=$baseline;status='signed_driver_present_monitors_detected'},
  @{name='vendor_alias';value=$alias;status='signed_driver_present_monitors_detected'},
  @{name='generic_first_use';value=$generic;status='driver_missing'},
  @{name='unbound';value=$null;status='driver_missing'},
  @{name='foreign';value=$unknown;status='driver_identity_or_signature_mismatch'},
  @{name='vendor_unsigned';value=$unsigned;status='driver_identity_or_signature_mismatch'}
 )
 foreach($case in $tests){
  $actual=Inspect $case.value
  if($actual.status -ne $case.status){
   throw ('Driver binding classification failed for '+$case.name+': expected '+$case.status+' got '+$actual.status)
  }
 }
 # Multiple matches: an untrusted bound device must override a healthy
 # sibling, never silently allow replacing an unknown driver.
 $snap.drivers=@($baseline,$unknown)
 [IO.File]::WriteAllText($f,($snap|ConvertTo-Json -Depth 10),[Text.UTF8Encoding]::new($false))
 $mixed=(& $state -SnapshotPath $f | Out-String)|ConvertFrom-Json
 if($mixed.status -ne 'driver_identity_or_signature_mismatch'){throw 'Mixed driver bindings ignored untrusted device'}
 $policy=Join-Path $root 'personal-ui\Get-DoxaCloudAIPolicy.ps1'
 [IO.File]::WriteAllText($f,'{"origin":"fixture","disable_cloud_ai":1}',[Text.UTF8Encoding]::new($false))
 $blocked=(& $policy -EvidencePath $f|Out-String)|ConvertFrom-Json
 if($blocked.online_ai_selectable -or $blocked.cloud_ai_allowed){throw 'Organization denial does not disable AI enrollment'}
 $localNotice=Get-Content (Join-Path $root 'personal-ui\AI-PRIVACY-NOTICE.txt') -Raw -Encoding UTF8
 if($localNotice -notmatch 'x-doxa-client-id' -or $localNotice -notmatch 'persistent'){throw 'Persistent online identifier privacy disclosure missing'}
 $lab=Join-Path $root 'fault-lab\Invoke-DoxaFaultLab.ps1'
 $exe=Join-Path (Join-Path (Resolve-Path (Join-Path $root '..\..\..')).Path 'artifacts\fault-lab') 'DoxaDisplayPath.exe'
 if(-not(Test-Path $exe)){throw 'Read-only native Lab helper not built; run Test-DoxaFaultLab.ps1'}
 $guard=(& $exe --guard-test|Out-String)
 if($LASTEXITCODE -ne 0 -or $guard -notmatch 'PASS'){throw 'Display overlap guard did not reject pending trial'}
 [pscustomobject]@{
  status='PASS'
  fixture_driver_bindings=$tests.Count
  mixed_vendor_binding='REJECTED'
  enterprise_policy_deny='PASS'
  identifier_disclosure='PASS'
  display_overlap_marker='PASS'
  personal_msi_gate='SOURCE_ONLY_NOT_LIVE_TESTED'
  physical_changes=0
  online_requests=0
 }|ConvertTo-Json -Compress
}finally{
 Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
}
