param(
 [ValidateSet('none','driver_missing','display_missing','policy_blocked','package_mismatch','support_offline')]
 [string]$Fault='none',
 [ValidateSet('en','ro')][string]$Language='en',
 [string]$EvidencePath=''
)
# Read-only personal setup diagnostics. RDP desktop count is not physical display topology.
# EvidencePath is an explicit fixture seam for reproducible tests, never read by the UI.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($EvidencePath){
 $actual=Get-Content -LiteralPath $EvidencePath -Raw -Encoding UTF8 | ConvertFrom-Json
 if([string]$actual.origin -ne 'fixture'){throw 'Only labelled fixture evidence may be supplied through EvidencePath.'}
 $sessionKind=[string]$actual.session_kind
 if($sessionKind -notin @('console','remote')){throw 'Fixture must specify console or remote session_kind.'}
} else {
 $root=Split-Path -Parent $PSScriptRoot
 $actual=(& (Join-Path $root 'Get-DoxaDriverState.ps1') | Out-String) | ConvertFrom-Json
 Add-Type -AssemblyName System.Windows.Forms
 $sessionKind=if([System.Windows.Forms.SystemInformation]::TerminalServerSession){'remote'}else{'console'}
}
$active=[int]$actual.active_windows_desktop_count
$panels=@($actual.doxa_panels_detected)
$missing=@($actual.doxa_panels_missing)
$matchedDevices=0
if($actual.PSObject.Properties.Name -contains 'matched_device_count'){
 $matchedDevices=[int]$actual.matched_device_count
}
# The live inventory verifies SMI770 hardware identity, publisher and signer.
# Software-driver version is NOT driver identity. Unknown signed versions are
# observed (not approved for redistribution) and must not trigger a downgrade.
$driverOk=$false
if($null -ne $actual.driver){
 $driverOk=[bool]$actual.driver.signed -and
  [string]$actual.status -in @('signed_driver_present_monitors_detected','signed_driver_present_monitors_missing')
}
$doxaRoot=Split-Path -Parent $PSScriptRoot
$profile=Get-Content -LiteralPath (Join-Path $doxaRoot 'profiles\smi770-observed.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$observedVersions=@([string]$profile.observed_driver_version)
if($profile.PSObject.Properties.Name -contains 'observed_driver_versions'){
 $observedVersions+=@($profile.observed_driver_versions|ForEach-Object {[string]$_})
}
$driverVersion=if($null -ne $actual.driver){[string]$actual.driver.version}else{''}
$versionReview=if(-not $driverOk){'identity_not_verified'}
 elseif($observedVersions -contains $driverVersion){'observed_baseline'}
 else{'signed_version_unreviewed'}
$hardwareReady=$driverOk -and $missing.Count -eq 0
# A driver package can remain installed in Windows even when Doxa is unplugged.
# Do not confuse a missing *present device* with a removed driver package.
$driverStorePackagePresent=$false
if([string]$actual.origin -eq 'live'){
 try{
  $pnputil=Join-Path $env:WINDIR 'System32\pnputil.exe'
  $driverListing=(& $pnputil /enum-drivers /class Display 2>$null) -join "`n"
  $sections=@($driverListing -split '(?:\r?\n){2,}')
  $driverStorePackagePresent=@($sections|Where-Object {$_ -match '(?i)smiiddx770\.inf' -and $_ -match '(?i)silicon\s?motion'}).Count -gt 0
 }catch{$driverStorePackagePresent=$false}
}
$sessionCanQualifyTopology=($sessionKind -eq 'console')
$topologyObserved=($sessionCanQualifyTopology -and $hardwareReady -and $active -ge 4 -and
 @($actual.active_windows_desktop_names | Select-Object -Unique).Count -eq $active)
$simulation=($Fault -ne 'none')
$code='ready'
$action='none'
if($simulation){
 switch($Fault){
  'driver_missing' {$code='driver_missing';$action='install_verified_driver'}
  'display_missing' {$code='display_missing';$action='recheck_power_cable_and_windows_display_mode'}
  'policy_blocked' {$code='policy_blocked';$action='request_it_approval'}
  'package_mismatch' {$code='package_mismatch';$action='reject_package_and_use_signed_original'}
  'support_offline' {$code='support_offline';$action='use_local_diagnostics'}
 }
} elseif([string]$actual.status -eq 'unsupported_windows'){
 $code='unsupported_windows';$action='request_it_approval'
} elseif([string]$actual.status -eq 'driver_missing'){
 if($panels.Count -eq 0 -and $matchedDevices -eq 0){
  $code='doxa_not_detected';$action='reconnect_power_and_usb_then_check'
 }else{
  $code='driver_missing';$action='install_verified_driver'
 }
} elseif(-not $driverOk){
 $code='driver_untrusted';$action='request_it_approval'
} elseif($missing.Count -gt 0){
 $code='doxa_panels_missing';$action='recheck_power_cable_and_windows_display_mode'
} elseif($sessionKind -eq 'remote'){
 $code='hardware_ready_remote_display_unverified';$action='verify_console_display_when_available'
} elseif(-not $topologyObserved){
 $code='display_topology_unverified';$action='review_windows_extend_mode'
}
$messages=@{
 en=@{
  ready='Doxa hardware, signed driver and four independent Windows desktops are detected in the console session.'
  hardware_ready_remote_display_unverified='The signed Doxa driver and all three panels are present. Remote Desktop shows its own screen layout, so the physical four-screen arrangement cannot be checked here. This is not a missing-screen error.'
  display_topology_unverified='Doxa hardware and signed driver are present, but four independently active desktops have not been established in the console session. Check Windows Extend mode.'
  doxa_panels_missing='Windows cannot currently see all three Doxa panels. Detect Doxa power, USB and monitor connections.'
  driver_missing='Doxa is detected, but the verified display driver is unavailable. Choose the official signed MSI using Install signed driver, then approve the Windows administrator prompt. No automatic restart.'
  doxa_not_detected='Windows does not detect the Doxa hardware or its three panels. Connect Doxa power and USB to this computer, then select Detect Doxa. Do not reinstall a driver until connectivity is checked.'
  display_missing='This TEST simulates a missing Doxa display. Check power, USB and Windows Extend mode.'
  policy_blocked='This TEST simulates an enterprise policy denying installation. Doxa must not bypass that policy.'
  package_mismatch='This TEST simulates a modified/unapproved driver package. Reject it before installation.'
  support_offline='This TEST simulates unavailable cloud support. Local diagnostics remain available.'
  unsupported_windows='The Windows build is outside the verified Doxa support baseline.'
  driver_untrusted='The installed driver does not match the verified signing and driver identity baseline.'
 }
 ro=@{
  ready='Hardware-ul Doxa, driverul semnat si patru ecrane Windows independente sunt detectate in sesiunea locala.'
  hardware_ready_remote_display_unverified='Driverul semnat si cele trei panouri Doxa sunt detectate. Remote Desktop are propria configuratie de ecran; cele patru ecrane fizice nu pot fi confirmate de aici. Nu este o eroare de ecran lipsa.'
  display_topology_unverified='Hardware-ul si driverul Doxa sunt detectate, dar in sesiunea locala nu sunt confirmate patru ecrane Windows independente. Verifica modul Extindere.'
  doxa_panels_missing='Windows nu detecteaza toate cele trei panouri Doxa. Verifica alimentarea, USB si conexiunile ecranelor.'
  driver_missing='Doxa este detectat, dar driverul verificat nu este disponibil. Alege MSI-ul oficial semnat folosind Instalare driver si aproba cererea Windows. Nu se reporneste automat.'
  doxa_not_detected='Windows nu detecteaza dispozitivul Doxa si nici cele trei panouri. Conecteaza alimentarea si cablul USB la calculator, apoi apasa Detecteaza Doxa. Nu reinstala driverul pana nu verifici conexiunile.'
  display_missing='Acest TEST simuleaza un ecran Doxa lipsa. Verifica alimentarea, USB si modul Extindere.'
  policy_blocked='Acest TEST simuleaza blocarea instalarii de catre politica IT. Doxa nu poate ocoli politica.'
  package_mismatch='Acest TEST simuleaza un pachet de driver modificat sau neaprobat. Instalarea trebuie refuzata.'
  support_offline='Acest TEST simuleaza indisponibilitatea asistentei cloud. Diagnoza locala ramane disponibila.'
  unsupported_windows='Versiunea Windows este in afara configuratiei Doxa verificate.'
  driver_untrusted='Driverul instalat nu corespunde identitatii si semnaturii verificate.'
 }
}
[ordered]@{
 schema_version=2
 test_only=$simulation
 injected_fault=$Fault
 code=$code
 suggested_action=$action
 message=([string]$messages[$Language][$code])+$(if(-not $simulation -and $versionReview -eq 'signed_version_unreviewed'){
  if($Language -eq 'ro'){' Aceasta versiune de driver semnat nu este inca verificata pentru compatibilitate Doxa. Daca ecranele functioneaza, nu reinstala si nu reveni automat la o versiune mai veche.'}
  else{' This signed driver version has not yet completed Doxa compatibility review. If the displays work, do not reinstall or downgrade it.'}
 }else{''})
 observed=[ordered]@{
  origin=[string]$actual.origin
  session_kind=$sessionKind
  session_display_topology_observable=$sessionCanQualifyTopology
  hardware_ready=$hardwareReady
  physical_display_topology_verified=$topologyObserved
  windows_build=[int]$actual.windows_build
  active_desktops=$active
  desktop_names=@($actual.active_windows_desktop_names)
  pnp_doxa_panels=$panels
  pnp_doxa_panels_missing=$missing
  driver_version=if($null -ne $actual.driver){[string]$actual.driver.version}else{''}
  driver_inf=if($null -ne $actual.driver){[string]$actual.driver.inf}else{''}
  signed_driver_present=[bool]$driverOk
  driver_version_qualification=$versionReview
  driver_version_review_needed=($versionReview -eq 'signed_version_unreviewed')
  driver_package_in_store=[bool]$driverStorePackagePresent
  doxa_hardware_detected=($matchedDevices -gt 0 -or $panels.Count -gt 0)
  package_approved_for_distribution=$false
 }
 note=if($simulation){'Only the result is simulated; no OS changes.'}else{'Read-only live OS information. Remote display topology is not physical topology.'}
} | ConvertTo-Json -Depth 9
