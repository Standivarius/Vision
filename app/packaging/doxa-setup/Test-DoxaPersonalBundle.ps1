param(
 [Parameter(Mandatory=$true)][string]$BundlePath,
 [switch]$LiveAI
)
# Exercises the actual extracted portable bundle: no vendor MSI, no installer apply/reboot.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(-not(Test-Path -LiteralPath $BundlePath -PathType Leaf)){throw 'ZIP not found'}
$testRoot=Join-Path $env:TEMP ('DoxaBundleValidation-'+[Guid]::NewGuid().ToString('N'))
$before=(Get-Location).Path
try{
 New-Item -ItemType Directory -Path $testRoot -Force|Out-Null
 Expand-Archive -LiteralPath $BundlePath -DestinationPath $testRoot -Force
 $manifest=Get-Content -LiteralPath (Join-Path $testRoot 'manifest.json') -Raw -Encoding UTF8|ConvertFrom-Json
 if($manifest.product -ne 'Standivarius Doxa Setup' -or $manifest.preview_version -ne '0.4.0-preview.12'){throw 'Wrong product/version'}
 if($manifest.signing_status -notmatch '^UNSIGNED preview'){throw 'Unexpected signing status'}
 if(@($manifest.files).Count -ne 20){throw 'Unexpected packaged file count'}
 $checked=0
 foreach($item in $manifest.files){
  $path=Join-Path $testRoot ($item.file.Replace('/','\'))
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Missing bundled file $($item.file)"}
  if((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ine $item.sha256){throw "Changed bundled file $($item.file)"}
  $checked++
 }
 $generated=@($manifest.generated_files)
 if($generated.Count -ne 2){throw 'Missing hashed launcher/readme entries'}
 foreach($item in $generated){
  if([string]$item.file -notin @('Open Doxa Setup.cmd','README-FIRST.txt')){throw 'Unexpected generated file'}
  $path=Join-Path $testRoot ([string]$item.file)
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw 'Missing generated file'}
  if((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ine [string]$item.sha256){throw 'Changed generated file'}
 }
 $all=@(Get-ChildItem -LiteralPath $testRoot -Recurse -File)
 $forbidden=@($all|Where-Object {$_.Name -like '*.env' -or $_.Extension -in @('.msi','.dll','.cat','.sys','.dpapi','.pfx','.pem','.key') -or $_.Name -match '(token|secret|private.?key)'})
 if($forbidden.Count){throw 'Forbidden driver or credential content in ZIP'}
 if($all.Count -ne 23){throw 'Unexpected extra content in personal bundle'}
 $logo=Join-Path $testRoot 'app\packaging\doxa-setup\personal-ui\assets\standivarius-official-logo.png'
 if(-not(Test-Path -LiteralPath $logo)){throw 'Official Standivarius logo missing from bundle'}
 $mainBrand=Join-Path $testRoot 'app\packaging\doxa-setup\personal-ui\Start-DoxaSetup.ps1'
 $brandCheck=(& $mainBrand -BrandTest | Out-String)|ConvertFrom-Json
 if($brandCheck.status -ne 'PASS' -or -not $brandCheck.single_form -or $brandCheck.upper_port -ne 'power' -or $brandCheck.lower_port -ne 'data'){throw 'Packaged brand/tab contract failed'}
 $wizard=Join-Path $testRoot 'app\packaging\doxa-setup\personal-ui\Start-DoxaGuidedSetup.ps1'
 $sameWindow=(& $wizard -SeamlessTest -Language en -TestConnectionChoice connected|Out-String)|ConvertFrom-Json
 if($sameWindow.seamless -ne 'PASS' -or -not $sameWindow.window_handle_preserved -or -not $sameWindow.detect_doxa_works -or
    -not $sameWindow.main_controls_reuse_form -or $sameWindow.driver_changes -or $sameWindow.new_form_opened){throw 'Packaged Doxa one-window journey failed'}
 $sameWindowRo=(& $wizard -SeamlessTest -Language ro -TestConnectionChoice without_doxa|Out-String)|ConvertFrom-Json
 if($sameWindowRo.seamless -ne 'PASS' -or -not $sameWindowRo.window_handle_preserved -or -not $sameWindowRo.detect_doxa_works){throw 'Packaged Romanian one-window journey failed'}
 $welcome=(& $wizard -JourneyTest | Out-String)|ConvertFrom-Json
 if($welcome.journey -ne 'PASS' -or $welcome.hardware_scans_before_consent -ne 0){throw 'Packaged consent wizard failed'}
 $notice=Join-Path $testRoot 'app\packaging\doxa-setup\personal-ui\LOCAL-CHECK-NOTICE.txt'
 if(-not(Test-Path $notice) -or (Get-Content $notice -Raw) -notmatch 'What it inspects'){throw 'Missing local-data inspection notice'}
 $guide=Join-Path $testRoot 'app\packaging\doxa-setup\personal-ui\Show-DoxaConnectionGuide.ps1'
 $guideSmoke=(& $guide -Smoke|Out-String)|ConvertFrom-Json
 if($guideSmoke.status -ne 'PASS' -or $guideSmoke.tabs -ne 2 -or $guideSmoke.settings_uri -ne 'ms-settings:display' -or -not $guideSmoke.no_topology_changes){throw 'Extracted screen connection guide failed'}
 # End-to-end same-form transition in the extracted *customer* files.
 # Test without a visible window, driver writes, topology changes or network AI.
 foreach($language in @('en','ro')){
  $one=(& $wizard -SeamlessTest -Language $language -TestConnectionChoice connected | Out-String)|ConvertFrom-Json
  if($one.seamless -ne 'PASS' -or -not $one.window_handle_preserved -or
     -not $one.main_controls_reuse_form -or -not $one.detect_doxa_works -or
     $one.new_form_opened -or $one.driver_changes -or
     $one.initial_hardware_scans_before_consent -ne 0){
   throw ('Packaged single-window flow FAILED: '+$language)
  }
 }
 $welcomeRo=(& $wizard -JourneyTest -Language ro -TestConnectionChoice without_doxa | Out-String)|ConvertFrom-Json
 if($welcomeRo.journey -ne 'PASS' -or $welcomeRo.language -ne 'ro' -or $welcomeRo.localized_step -notmatch 'Pasul 2' -or $welcomeRo.hardware_scans_before_consent -ne 0 -or $welcomeRo.remote_requests -ne 0){throw 'Packaged Romanian consent journey failed'}
 # Customer must advance consent -> connection -> Detect Doxa in the SAME form;
 # no second PowerShell/WinForms window may replace the original HWND.
 foreach($lang in @('en','ro')){
  $choice=if($lang -eq 'en'){'connected'}else{'without_doxa'}
  $seamless=(& $wizard -SeamlessTest -Language $lang -TestConnectionChoice $choice | Out-String)|ConvertFrom-Json
  if($seamless.seamless -ne 'PASS' -or -not $seamless.window_handle_preserved -or
     -not $seamless.main_controls_reuse_form -or -not $seamless.detect_doxa_works -or
     $seamless.initial_hardware_scans_before_consent -ne 0 -or
     $seamless.cloud_ai_requests -ne 0 -or $seamless.driver_changes -or $seamless.new_form_opened){
   throw "Packaged single-window customer transition failed ($lang)"
  }
 }

 $runner=Join-Path $testRoot 'app\packaging\doxa-setup\personal-ui\Start-DoxaSetup.ps1'
 $old=(Get-Location).Path
 Set-Location -LiteralPath $env:TEMP
 try{
  $result=(& $runner -JourneyTest|Out-String)|ConvertFrom-Json
  if($result.journey -ne 'PASS'){throw 'Extracted installer journey failed'}
  if($result.fault_did_not_call_ai -ne $true){throw 'Simulation safety regression'}
  if($result.install_button -notin @('correct_driver_noop','connect_doxa_first')){throw 'Unsafe driver installation decision on this PC'}
  $mainRo=(& $runner -JourneyTest -Language ro | Out-String)|ConvertFrom-Json
  if($mainRo.journey -ne 'PASS' -or $mainRo.language -ne 'ro' -or $mainRo.localized_intro -notmatch 'Pregateste' -or $mainRo.driver_changes -or $mainRo.fault_did_not_call_ai -ne $true){throw 'Packaged Romanian main UI journey failed'}
 }finally{Set-Location -LiteralPath $old}
 $localHelp=Join-Path $testRoot 'app\packaging\doxa-setup\personal-ui\Get-DoxaKnowledgeAnswer.ps1'
 $scopeOut=(& $localHelp -Question 'What is the weather today? Doxa driver'|Out-String)|ConvertFrom-Json
 if($scopeOut.status -ne 'out_of_scope'){throw 'Extracted offline help answered outside Doxa scope'}
 $scopeRo=(& $localHelp -Question 'De ce ecranul Doxa nu apare?' -Language ro|Out-String)|ConvertFrom-Json
 if($scopeRo.status -ne 'curated_answer'){throw 'Extracted Romanian setup question rejected'}
 # Exercise per-user Doxa RSA identity preparation in an isolated test profile.
 # No private key or test approval is placed in the package or sent to Cloudflare.
 $signer=Join-Path $testRoot 'app\packaging\doxa-setup\personal-ui\Get-DoxaDeviceSignature.ps1'
 $oldAppData=$env:LOCALAPPDATA
 $tempAppData=Join-Path $testRoot 'enrollment-fixture'
 try {
  New-Item -ItemType Directory -Path $tempAppData -Force | Out-Null
  $env:LOCALAPPDATA=$tempAppData
  $identity=(& $signer -PrepareEnrollment|Out-String)|ConvertFrom-Json
  if($identity.approved_by_server -or $identity.private_key_protection -ne 'Windows DPAPI CurrentUser' -or $identity.client_id -notmatch '^[a-f0-9]{24}$' -or $identity.public_jwk.kty -ne 'RSA'){throw 'Test identity enrollment not isolated'}
  $signature=(& $signer -SignBody '{"offline":true}' | Out-String)|ConvertFrom-Json
  if($signature.client_id -ne $identity.client_id -or $signature.signature.Length -lt 300){throw 'Offline test identity cannot sign'}
 }finally{$env:LOCALAPPDATA=$oldAppData}
 $compatScript=Join-Path $testRoot 'app\packaging\doxa-setup\personal-ui\Get-DoxaCompatibility.ps1'
 $compat=(& $compatScript -ConnectionChoice without_doxa|Out-String)|ConvertFrom-Json
 if(-not $compat.read_only -or $compat.prestage_msi_qualified -or $compat.usb_c_port_physically_verified){throw 'Portable PC precheck overclaimed compatibility'}
 $aiStatus='not_requested'
 if($LiveAI){
  $client=Join-Path $testRoot 'app\packaging\doxa-setup\personal-ui\Ask-DoxaInstaller.ps1'
  $reply=(& $client -Question 'Why does RDP show one screen when the signed driver and all Doxa panels are detected?' -TimeoutSec 40 -AIConsentGranted|Out-String)|ConvertFrom-Json
  $aiStatus=[string]$reply.status
  if($aiStatus -ne 'answered'){throw ('Extracted client did not reach live Doxa AI: '+$aiStatus)}
 }
 [ordered]@{status='PASS';file_integrity_verified=$checked;archive_total_files=$all.Count;driver_payload_bundled=$false;credentials_bundled=$false;extracted_away_from_repository=$true;journey=$result.journey;simulated_fault_did_not_call_ai=$result.fault_did_not_call_ai;driver_install_prevented_safely=$true;installation_button_result=$result.install_button;cloud_ai=$aiStatus;multidevice_identity_tested=$true;bilingual_ui_verified=$true;consent_before_diagnostics=$true;same_window_navigation_passed=$true;single_window_transition=$true;single_window_transition_verified=$true}|ConvertTo-Json -Compress
}finally{
 Set-Location -LiteralPath $before
 if(Test-Path -LiteralPath $testRoot){Remove-Item -LiteralPath $testRoot -Recurse -Force}
}
