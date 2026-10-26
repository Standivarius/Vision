$ErrorActionPreference='Stop'
$script=Join-Path $PSScriptRoot 'Test-DoxaRecoveryPreflight.ps1'
$temp=Join-Path $env:TEMP ('DoxaRecoveryFixtures-'+[guid]::NewGuid().ToString('N'))
try{
 New-Item -ItemType Directory -Path $temp|Out-Null
 $fixture=[ordered]@{
  origin='fixture';status='signed_driver_present_monitors_detected'
  session_kind='console';active_windows_desktop_count=4
  active_windows_desktop_names=@('Laptop','Doxa Left','Doxa Middle','Doxa Right')
  matched_device_count=1;doxa_panels_detected=@('L','T','R');doxa_panels_missing=@()
  windows_build=26100;driver=[ordered]@{signed=$true;version='4.7.6.0';inf='oem101.inf'}
 }
 $fixturePath=Join-Path $temp 'console.json'
 $fixture|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $fixturePath -Encoding UTF8
 $yes=(& $script -EvidencePath $fixturePath -OwnerAtKeyboard -LaptopDisplayIndependentlyUsable | Out-String)|ConvertFrom-Json
 if($yes.may_begin_attended_recovery_rehearsal -or $yes.data_source -ne 'labelled_fixture' -or $yes.blocking_reasons -notcontains 'test_fixture_not_live_hardware'){throw 'Labelled fixture bypassed live preflight'}
 if($yes.actions_executed.Count -gt 0 -or $yes.driver_changes -or $yes.reboot_initiated){throw 'Fixture preflight mutated Windows'}
 $fixture.session_kind='remote'
 $fixture|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $fixturePath -Encoding UTF8
 $remote=(& $script -EvidencePath $fixturePath -OwnerAtKeyboard -LaptopDisplayIndependentlyUsable|Out-String)|ConvertFrom-Json
 if($remote.blocking_reasons -notcontains 'not_local_windows_console'){throw 'RDP topology not blocked'}
 $noApproval=(& $script -EvidencePath $fixturePath|Out-String)|ConvertFrom-Json
 if($noApproval.blocking_reasons -notcontains 'owner_not_physically_present' -or $noApproval.blocking_reasons -notcontains 'laptop_recovery_display_not_confirmed'){throw 'Recovery assurance gates missing'}
 $missing=(& $script -EvidencePath $fixturePath -VendorMsiPath (Join-Path $temp 'missing.msi') |Out-String)|ConvertFrom-Json
 if($missing.recovery_msi_gate -ne 'package_missing' -or $missing.may_begin_attended_recovery_rehearsal){throw 'MSI gate not enforced'}
 $fetcher=Join-Path $PSScriptRoot 'Get-DoxaOfficialRecoveryMsi.ps1'
 $source=(& $fetcher|Out-String)|ConvertFrom-Json
 if($source.installation_started -or $source.downloads_started -or $source.expected_msi_sha256 -ne '3379B46DA029423748E2D2E64DB2015B50136E310A492E31857CC726719192D4'){throw 'Official vendor source metadata invalid'}
 $badArchive=Join-Path $temp 'bad.zip'
 [IO.File]::WriteAllText($badArchive,'not a vendor ZIP')
 $badDir=Join-Path $temp 'bad-output'
 $rejected=$false
 try{& $fetcher -ArchivePath $badArchive -OutputDirectory $badDir | Out-Null}catch{$rejected=$true}
 if(-not $rejected -or (Test-Path (Join-Path $badDir 'SMIUSBDisplaySW770.msi'))){throw 'Tampered vendor archive was not rejected'}
 $live=(& $script|Out-String)|ConvertFrom-Json
 if($live.operation -ne 'read_only_preflight' -or $live.driver_changes -or $live.software_deployed -or $live.reboot_initiated -or $live.may_begin_attended_recovery_rehearsal){throw 'ASUS live preflight failed closed'}
 'DOXA_RECOVERY_PREFLIGHT_RDP_FIXTURE_MSI_LAPTOP_AND_LIVE_GATES_PASS'
}finally{if(Test-Path $temp){Remove-Item -LiteralPath $temp -Recurse -Force}}
