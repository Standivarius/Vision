param(
 [ValidateSet('connected','without_doxa')][string]$ConnectionChoice='without_doxa',
 [ValidateSet('en','ro')][string]$Language='en',
 [string]$EvidencePath=''
)
# Read-only qualification. Port shape and exact Doxa compatibility require a physical connection.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$profile=Get-Content (Join-Path (Split-Path -Parent $PSScriptRoot) 'profiles\smi770-observed.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if($EvidencePath){
 $e=Get-Content -LiteralPath $EvidencePath -Raw -Encoding UTF8|ConvertFrom-Json
 if($e.origin -ne 'fixture'){throw 'Only an explicitly labelled fixture is allowed.'}
 $build=[int]$e.windows_build
 $architecture=[string]$e.architecture
 $usbCount=[int]$e.usb_host_controller_count
 $usb3=[bool]$e.usb3_controller_detected
 $state=$e.doxa_state
}else{
 $os=Get-CimInstance Win32_OperatingSystem
 $build=[int]$os.BuildNumber
 $architecture=[string]$os.OSArchitecture
 $controllers=@(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue|Where-Object {
  $_.Class -eq 'USB' -and $_.FriendlyName -match 'Host Controller|xHCI|eXtensible Host'
 })
 $usbCount=$controllers.Count
 $usb3=@($controllers|Where-Object {$_.FriendlyName -match '3\.|xHCI|eXtensible'}).Count -gt 0
 $state=(& (Join-Path $PSScriptRoot 'Get-DoxaSetupExperience.ps1') -Fault none -Language $Language|Out-String)|ConvertFrom-Json
}
$windowsOk=$build -ge [int]$profile.minimum_windows_build
$packagePresent=[bool]$state.observed.driver_package_in_store
$connected=[bool]$state.observed.doxa_hardware_detected
$panels=@($state.observed.pnp_doxa_panels).Count
$driverSigned=[bool]$state.observed.signed_driver_present
$displayVerification=$connected -and $panels -eq 3 -and [bool]$state.observed.physical_display_topology_verified
$items=@(
 [ordered]@{id='windows';status=$(if($windowsOk){'compatible'}else{'needs_attention'});text="Windows build $build; minimum qualified baseline $($profile.minimum_windows_build)."},
 [ordered]@{id='usb';status=$(if($usbCount -gt 0){'detected_unverified'}else{'not_verified'});text="USB host controllers detected: $usbCount. USB 3.x indication: $usb3. Physical USB-C port, cable speed and power delivery cannot be established reliably by this scan."},
 [ordered]@{id='driver';status=$(if($driverSigned){'verified_connected'}elseif($packagePresent){'stored_not_verified_connected'}else{'not_detected'});text=$(if($packagePresent){'Silicon Motion SM770 package appears in the Windows Driver Store.'}else{'No matching SM770 package verified in the Windows Driver Store.'})},
 [ordered]@{id='doxa';status=$(if($connected){'connected'}else{'not_connected'});text=$(if($connected){"Doxa detected; panels currently enumerated: $panels."}else{'Doxa hardware is not currently detected; external panels cannot be tested.'})},
 [ordered]@{id='display';status=$(if($displayVerification){'verified'}else{'pending_hardware_verification'});text='Actual Doxa display extension, negotiated link speed, signal quality and power cannot be guaranteed without the connected hardware and Windows console.'}
)
$recommendation=if(-not $windowsOk){'This Windows build is outside the qualified baseline. Driver installation is not recommended.'}
elseif($packagePresent -and -not $connected){'The driver package is already staged in Windows. Connect Doxa power and USB to verify detection; no reinstall is indicated.'}
elseif(-not $connected){'Windows and USB checks can proceed without Doxa. The original MSI pre-connection install path has not yet been qualified; do not apply it automatically.'}
elseif($driverSigned -and $panels -eq 3){'All three Doxa panels and the signed driver are detected. Verify Windows Extend mode on the physical console.'}
else{'Doxa is detected but needs additional connection or signed-driver checks before installation.'}
[ordered]@{
 schema_version=1;product='Standivarius Doxa Setup';read_only=$true
 connection_choice=$ConnectionChoice;windows_supported=$windowsOk
 usb_controller_count=$usbCount;usb3_controller_indicated=$usb3
 usb_c_port_physically_verified=$false; usb_data_link_negotiated=$false
 driver_package_in_store=$packagePresent;doxa_detected=$connected
 signed_driver_verified=$driverSigned;doxa_panel_count=$panels
 needs_hardware_for_final_verification=$true
 prestage_msi_qualified=$false;automatic_driver_installation_permitted=$false
 checks=$items;recommendation=$recommendation
}|ConvertTo-Json -Depth 7 -Compress
