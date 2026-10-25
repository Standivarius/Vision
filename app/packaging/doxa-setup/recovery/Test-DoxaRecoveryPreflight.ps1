param(
 [string]$VendorMsiPath='',
 [switch]$OwnerAtKeyboard,
 [switch]$LaptopDisplayIndependentlyUsable,
 [string]$EvidencePath=''
)
# This script is STRICTLY READ ONLY. It never stops services, disables PnP devices,
# uninstalls driver packages, starts Windows Installer, deploys software or reboots.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$experienceScript=Join-Path $PSScriptRoot '..\personal-ui\Get-DoxaSetupExperience.ps1'
$gateScript=Join-Path $PSScriptRoot '..\personal-ui\Test-DoxaPackageGate.ps1'
if($EvidencePath){
 $fixture=Get-Content -LiteralPath $EvidencePath -Raw -Encoding UTF8|ConvertFrom-Json
 if([string]$fixture.origin -ne 'fixture'){throw 'Refuse unlabelled test evidence'}
 $observed=(& $experienceScript -EvidencePath $EvidencePath -Fault none -Language en|Out-String)|ConvertFrom-Json
}else{
 $observed=(& $experienceScript -Fault none -Language en|Out-String)|ConvertFrom-Json
}
$device=$observed.observed
$console=[string]$device.session_kind -eq 'console'
$doxaReady=([bool]$device.hardware_ready -and [bool]$device.signed_driver_present -and
 @($device.pnp_doxa_panels).Count -eq 3)
$fourDesktops=([bool]$device.physical_display_topology_verified -and
 [int]$device.active_desktops -ge 4)
$msiResult=[ordered]@{allowed=$false;code='msi_not_provided';reason='Provide local official signed MSI; never fetch, deploy or apply from this check.'}
if($VendorMsiPath){
 $msiResult=(& $gateScript -PackagePath $VendorMsiPath|Out-String)|ConvertFrom-Json
}
$reasons=@()
if($env:COMPUTERNAME -ine 'MARIUS-DELL'){$reasons+='target_not_dell'}
if($EvidencePath){$reasons+='test_fixture_not_live_hardware'}
if(-not $console){$reasons+='not_local_windows_console'}
if(-not $doxaReady){$reasons+='three_doxa_panels_and_signed_driver_not_verified'}
if(-not $fourDesktops){$reasons+='four_independent_local_desktops_not_verified'}
if(-not $OwnerAtKeyboard){$reasons+='owner_not_physically_present'}
if(-not $LaptopDisplayIndependentlyUsable){$reasons+='laptop_recovery_display_not_confirmed'}
if(-not [bool]$msiResult.allowed){$reasons+='verified_recovery_msi_unavailable'}
$ready=($reasons.Count -eq 0)
[ordered]@{
 schema_version=1
 operation='read_only_preflight'
 target_host=$env:COMPUTERNAME
 observed_session=[string]$device.session_kind
 data_source=if($EvidencePath){'labelled_fixture'}else{'live_read_only_windows'}
 physical_doxa_panels_reported=@($device.pnp_doxa_panels).Count
 signed_smi_driver_reported=[bool]$device.signed_driver_present
 physical_desktop_topology_verified=$fourDesktops
 owner_physically_present_asserted=[bool]$OwnerAtKeyboard
 independent_laptop_recovery_display_asserted=[bool]$LaptopDisplayIndependentlyUsable
 recovery_msi_gate=[string]$msiResult.code
 recovery_msi_approved=[bool]$msiResult.allowed
 may_begin_attended_recovery_rehearsal=$ready
 blocking_reasons=$reasons
 actions_executed=@()
 driver_changes=$false
 reboot_initiated=$false
 software_deployed=$false
 note='Even with PASS this does not authorize uninstall or any device mutation. Attended run needs a separate explicit go, driver-store backup, rollback and monitoring of the laptop screen.'
}|ConvertTo-Json -Depth 7 -Compress
