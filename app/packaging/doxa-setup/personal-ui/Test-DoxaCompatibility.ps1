$ErrorActionPreference='Stop'
$subject=Join-Path $PSScriptRoot 'Get-DoxaCompatibility.ps1'
$dir=Join-Path $env:TEMP ('doxa-compat-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $dir|Out-Null
try{
 $fixture=[ordered]@{
  origin='fixture';windows_build=26300;architecture='64-bit'
  usb_host_controller_count=1;usb3_controller_detected=$true
  doxa_state=[ordered]@{observed=[ordered]@{driver_package_in_store=$true;doxa_hardware_detected=$false;pnp_doxa_panels=@();signed_driver_present=$false;physical_display_topology_verified=$false}}
 }
 $file=Join-Path $dir 'state.json'
 function WriteFixture{[IO.File]::WriteAllText($file,($fixture|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))}
 WriteFixture
 $without=(& $subject -ConnectionChoice without_doxa -EvidencePath $file|Out-String)|ConvertFrom-Json
 if(-not $without.windows_supported -or -not $without.driver_package_in_store -or $without.doxa_detected){throw 'Disconnected driver-store case failed'}
 if($without.usb_c_port_physically_verified -or $without.automatic_driver_installation_permitted -or $without.prestage_msi_qualified){throw 'Compatibility overclaim in unplugged path'}
 $fixture.doxa_state.observed.doxa_hardware_detected=$true
 $fixture.doxa_state.observed.signed_driver_present=$true
 $fixture.doxa_state.observed.pnp_doxa_panels=@('L','T','R')
 $fixture.doxa_state.observed.physical_display_topology_verified=$true
 WriteFixture
 $connected=(& $subject -ConnectionChoice connected -EvidencePath $file|Out-String)|ConvertFrom-Json
 if(-not $connected.doxa_detected -or -not $connected.signed_driver_verified -or $connected.doxa_panel_count -ne 3){throw 'Connected path failed'}
 $fixture.windows_build=10000
 $fixture.usb_host_controller_count=0
 $fixture.usb3_controller_detected=$false
 WriteFixture
 $old=(& $subject -ConnectionChoice connected -EvidencePath $file|Out-String)|ConvertFrom-Json
 if($old.windows_supported -or $old.usb_controller_count -ne 0){throw 'Unsupported PC flagged compatible'}
 $wizard=Join-Path $PSScriptRoot 'Start-DoxaGuidedSetup.ps1'
 $a=(& $wizard -JourneyTest|Out-String)|ConvertFrom-Json
 if($a.journey -ne 'PASS' -or $a.hardware_scans_before_consent -ne 0 -or $a.ai_consent){throw 'Consent-first wizard failed'}
 $b=(& $wizard -JourneyTest -TestConnectionChoice connected -TestAIAllowed|Out-String)|ConvertFrom-Json
 if($b.journey -ne 'PASS' -or $b.connection_choice -ne 'connected' -or -not $b.ai_consent){throw 'Connected and opted-in wizard failed'}
 'DOXA_COMPAT_CONNECTED_DISCONNECTED_UNSUPPORTED_AND_CONSENT=PASS'
}finally{Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue}
