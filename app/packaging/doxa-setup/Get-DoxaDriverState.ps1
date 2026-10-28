param(
 [string]$ProfilePath = (Join-Path $PSScriptRoot 'profiles\smi770-observed.json'),
 [string]$SnapshotPath = '',
 [string]$OutputPath = ''
)
# Read-only, no display changes, no driver installation.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$profile = Get-Content -LiteralPath $ProfilePath -Raw -Encoding UTF8 | ConvertFrom-Json
# Independent Windows desktop sources are different from PnP monitor devices.
# Only measure the active user-session display list for live observations.
$desktopNames = @()
$desktopCount = 0
$desktopSource = 'not_measured'
if ($SnapshotPath) {
 $snapshot = Get-Content -LiteralPath $SnapshotPath -Raw -Encoding UTF8 | ConvertFrom-Json
 $origin = 'fixture'
} else {
 Add-Type -AssemblyName System.Windows.Forms
 $desktopNames = @([System.Windows.Forms.Screen]::AllScreens | ForEach-Object {[string]$_.DeviceName})
 $desktopCount = $desktopNames.Count
 $desktopSource = 'windows_forms_current_session'
 $os = Get-CimInstance Win32_OperatingSystem
 $drivers = @(Get-CimInstance Win32_PnPSignedDriver |
  Where-Object { [string]$_.DeviceID -like ($profile.hardware_id_prefix + '*') } |
  ForEach-Object {
   [pscustomobject]@{
    device_id=[string]$_.DeviceID; device_name=[string]$_.DeviceName
    provider=[string]$_.DriverProviderName; version=[string]$_.DriverVersion
    inf=[string]$_.InfName; signed=[bool]$_.IsSigned; signer=[string]$_.Signer
   }
  })
 $monitors = @(Get-PnpDevice -Class Monitor -PresentOnly |
  Where-Object Status -eq 'OK' |
  ForEach-Object { [pscustomobject]@{name=[string]$_.FriendlyName} })
 $snapshot = [pscustomobject]@{
  os_build=[int]$os.BuildNumber; drivers=$drivers; monitors=$monitors
 }
 $origin = 'live'
}
$matched = @($snapshot.drivers | Where-Object {
 $null -ne $_ -and [string]$_.device_id -like ($profile.hardware_id_prefix + '*')
})
# Prioritize untrusted third-party binding, then a trusted vendor binding,
# then a generic Microsoft/unbound first-use device. Same table as native host.
function Get-DoxaBindingClass($item) {
 $provider=[string]$item.provider
 if([string]::IsNullOrWhiteSpace($provider) -or $provider -in @('Microsoft','Microsoft Windows')){return 'missing'}
 $normalized=$provider -replace '[^A-Za-z0-9]',''
 if($normalized -match '^(?i)SiliconMotion' -and [bool]$item.signed -and
    [string]$item.signer -eq [string]$profile.expected_driver_signer){return 'trusted'}
 return 'untrusted'
}
$classifications=@($matched|ForEach-Object {Get-DoxaBindingClass $_})
$driver=if($classifications -contains 'untrusted') {
 $matched[[array]::IndexOf($classifications,'untrusted')]
}elseif($classifications -contains 'trusted'){
 $matched[[array]::IndexOf($classifications,'trusted')]
}elseif($matched.Count -gt 0){$matched[0]}else{$null}
$binding=if($classifications -contains 'untrusted'){'untrusted'}elseif($classifications -contains 'trusted'){'trusted'}else{'missing'}
$names = @($snapshot.monitors | ForEach-Object {[string]$_.name})
$present = @($profile.expected_monitor_names | Where-Object {$names -contains $_})
$missing = @($profile.expected_monitor_names | Where-Object {$names -notcontains $_})
$driverOk = ($binding -eq 'trusted')
$status = if ([int]$snapshot.os_build -lt [int]$profile.minimum_windows_build) {
 'unsupported_windows'
 } elseif ($binding -eq 'missing') {
  'driver_missing'
 } elseif (-not $driverOk) {
 'driver_identity_or_signature_mismatch'
} elseif ($missing.Count -gt 0) {
 'signed_driver_present_monitors_missing'
} else {
 'signed_driver_present_monitors_detected'
}
# The physical monitor count is NOT the number of independent Windows sources;
# Windows may use Duplicate mode for separate panels (display 3|4).
$result = [ordered]@{
 schema_version=1; origin=$origin; profile_id=$profile.profile_id
 profile_qualification=$profile.qualification; status=$status
 windows_build=[int]$snapshot.os_build; matched_device_count=$matched.Count
 driver=if ($null -eq $driver) {$null} else {[ordered]@{
  name=$driver.device_name; inf=$driver.inf; version=$driver.version
  provider=$driver.provider; signed=$driver.signed; signer=$driver.signer
 }}
 connected_monitor_count=$names.Count
 doxa_panels_detected=$present; doxa_panels_missing=$missing
 active_windows_desktop_count=$desktopCount
 active_windows_desktop_names=$desktopNames
 active_windows_desktop_source=$desktopSource
 # Do not infer 4 independent sources merely from 4 PnP monitors. Never
 # report true for fixture inputs or without the signed Doxa driver/panels.
 independent_windows_desktops_verified=([bool](
  $origin -eq 'live' -and $driverOk -and $missing.Count -eq 0 -and
  $desktopCount -ge (1 + $profile.expected_monitor_names.Count) -and
  @($desktopNames | Select-Object -Unique).Count -eq $desktopCount
 ))
 package_approved_for_distribution=$false
 next_action=if($status -eq 'signed_driver_present_monitors_detected') {
  if($origin -eq 'live' -and $desktopCount -ge (1 + $profile.expected_monitor_names.Count)) {
   'Four independent Windows sources observed. Qualify the official signed vendor MSI, licensing and enterprise deployment; do not reinstall a working driver.'
  } else {
   'Confirm independent Windows display sources and qualify the signed vendor MSI; do not reinstall a working driver.'
  }
 } else {
  'Resolve the hardware/driver baseline before deploying a package.'
 }
}
$json=$result | ConvertTo-Json -Depth 12
if($OutputPath) {
 [IO.File]::WriteAllText([IO.Path]::GetFullPath($OutputPath),$json,[Text.UTF8Encoding]::new($false))
}
$json
