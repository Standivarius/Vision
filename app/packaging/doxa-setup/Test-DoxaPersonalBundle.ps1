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
 if($manifest.product -ne 'Standivarius Doxa Setup'){throw 'Wrong product'}
 if($manifest.signing_status -notmatch '^UNSIGNED preview'){throw 'Unexpected signing status'}
 if(@($manifest.files).Count -ne 16){throw 'Unexpected packaged file count'}
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
 if($all.Count -ne 19){throw 'Unexpected extra content in personal bundle'}
 $wizard=Join-Path $testRoot 'app\packaging\doxa-setup\personal-ui\Start-DoxaGuidedSetup.ps1'
 $welcome=(& $wizard -JourneyTest | Out-String)|ConvertFrom-Json
 if($welcome.journey -ne 'PASS' -or $welcome.hardware_scans_before_consent -ne 0){throw 'Packaged consent wizard failed'}
 $welcomeRo=(& $wizard -JourneyTest -Language ro -TestConnectionChoice without_doxa | Out-String)|ConvertFrom-Json
 if($welcomeRo.journey -ne 'PASS' -or $welcomeRo.language -ne 'ro' -or $welcomeRo.localized_step -notmatch 'Pasul 2' -or $welcomeRo.hardware_scans_before_consent -ne 0 -or $welcomeRo.remote_requests -ne 0){throw 'Packaged Romanian consent journey failed'}
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
 [ordered]@{status='PASS';file_integrity_verified=$checked;archive_total_files=$all.Count;driver_payload_bundled=$false;credentials_bundled=$false;extracted_away_from_repository=$true;journey=$result.journey;simulated_fault_did_not_call_ai=$result.fault_did_not_call_ai;driver_install_prevented_safely=$true;installation_button_result=$result.install_button;cloud_ai=$aiStatus;bilingual_ui_verified=$true;consent_before_diagnostics=$true}|ConvertTo-Json -Compress
}finally{
 Set-Location -LiteralPath $before
 if(Test-Path -LiteralPath $testRoot){Remove-Item -LiteralPath $testRoot -Recurse -Force}
}
