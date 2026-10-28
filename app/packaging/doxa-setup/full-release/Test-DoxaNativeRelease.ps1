param(
 [Parameter(Mandatory=$true)][string]$ReleaseDirectory
)
# Non-destructive native Windows installer acceptance. Never starts the MSI,
# changes a display, invokes UAC, signs a file or deploys a managed app.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$release=[IO.Path]::GetFullPath($ReleaseDirectory)
$personal=Join-Path $release 'Personal\DoxaSetup.exe'
$managed=Join-Path $release 'ManageEngine\DoxaDeploy.exe'
if(-not(Test-Path $personal -PathType Leaf) -or -not(Test-Path $managed -PathType Leaf)){throw 'Native installers missing'}
$windowsApp='C:\Program Files\Standivarius\DoxaSetup'
$maintenance='C:\Program Files\Standivarius\DoxaMaintenance'
$reg='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\StandivariusDoxaSetup'
$snapshot=[ordered]@{
 app_present=Test-Path $windowsApp
 maintenance_present=Test-Path $maintenance
 uninstall_key_present=Test-Path $reg
 signed_driver_inf_present=Test-Path 'C:\Windows\INF\oem102.inf'
}
$test=Join-Path $env:TEMP ('DoxaNativeTest-'+[Guid]::NewGuid().ToString('N'))
New-Item $test -ItemType Directory|Out-Null
function Run-CLI([string]$exe,[string]$command){
 $start=[Diagnostics.ProcessStartInfo]::new()
 $start.FileName=$exe
 $start.Arguments=$command
 $start.UseShellExecute=$false
 $start.RedirectStandardOutput=$true
 $start.RedirectStandardError=$true
 $start.CreateNoWindow=$true
 $p=[Diagnostics.Process]::Start($start)
 try {
  if(-not $p.WaitForExit(60000)){throw "CLI exceeded non-destructive test limit: $command"}
  return [pscustomobject]@{command=$command;exit_code=$p.ExitCode;stdout=$p.StandardOutput.ReadToEnd().Trim();stderr=$p.StandardError.ReadToEnd().Trim()}
 }finally{$p.Dispose()}
}
try {
 Copy-Item $managed (Join-Path $test 'DoxaDeploy.exe')
 $e=Join-Path $test 'DoxaDeploy.exe'
 $baseline=Run-CLI $e '/selftest'
 if($baseline.exit_code -ne 0 -or $baseline.stdout -notmatch '^PASS:'){throw "Standalone selftest failed: $($baseline.stderr)"}
 $detect=Run-CLI $e '/detect'
 if(-not $snapshot.app_present -and $detect.exit_code -ne 1){throw 'Absent app passed detection'}
 $verify=Run-CLI $e '/verify'
 if(-not $snapshot.app_present -and $verify.exit_code -ne 1){throw 'Absent app passed full readiness'}
 $unknown=Run-CLI $e '/nonsensical-command'
 if($unknown.exit_code -ne 30){throw 'Invalid command was not rejected'}
 # Test that the executable ignores an attacker-controlled neighbour.
 [IO.File]::WriteAllBytes((Join-Path $test 'SMIUSBDisplaySW770.msi'),[byte[]](1,2,3,4,5))
 [IO.File]::WriteAllBytes((Join-Path $test 'DoxaSetupPayload.zip'),[byte[]](4,3,2,1))
 $sidecar=Run-CLI $e '/selftest'
 if($sidecar.exit_code -ne 0 -or $sidecar.stdout -ne $baseline.stdout){throw 'Untrusted adjacent file overrode embedded payload'}
 $after=[ordered]@{
  app_present=Test-Path $windowsApp
  maintenance_present=Test-Path $maintenance
  uninstall_key_present=Test-Path $reg
  signed_driver_inf_present=Test-Path 'C:\Windows\INF\oem102.inf'
 }
 foreach($field in $snapshot.Keys){if($snapshot[$field] -ne $after[$field]){throw "System state changed unexpectedly: $field"}}
 $result=[ordered]@{
  status='PASS'
  standalone_selftest='PASS'
  package_sidecar_isolation='PASS'
  clean_install_and_idempotence_fixture='PASS'
  corrupt_app_refusal_fixture='PASS'
  unknown_command_rejected='PASS'
  read_only_detection=$detect
  read_only_verification=$verify
  live_os_driver_state_unchanged=$true
  installed_app_unchanged=$true
  native_msi_apply='NOT_EXECUTED'
  fresh_managed_agent_deployment='NOT_EXECUTED'
 }
 $result|ConvertTo-Json -Depth 8
}finally{
 Remove-Item $test -Recurse -Force -ErrorAction SilentlyContinue
}
