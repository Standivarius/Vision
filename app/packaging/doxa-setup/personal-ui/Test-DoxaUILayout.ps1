# Deterministic, offline layout/keyboard/consent/UI gate. Does not modify
# vendor drivers, launch network AI, or install/uninstall software.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$main=Join-Path $PSScriptRoot 'Start-DoxaSetup.ps1'
$welcome=Join-Path $PSScriptRoot 'Start-DoxaGuidedSetup.ps1'
$passed=0
foreach($language in @('en','ro')){
 $first=(& $welcome -Smoke -Language $language|Out-String)|ConvertFrom-Json
 if($first.smoke -ne 'PASS' -or
    $first.local_consent_default -or $first.remote_ai_default -or
    $first.local_checks_before_consent -or $first.cloud_ai_before_consent -or
    -not $first.privacy_details_available -or -not $first.local_check_details_available -or -not $first.accept_button_set -or
    $first.language_count -ne 2 -or @($first.tab_order).Count -lt 8){
  throw "Welcome privacy, keyboard or language contract failed ($language)"
 }
 $sameWindow=(& $welcome -SeamlessTest -Language $language -TestConnectionChoice connected|Out-String)|ConvertFrom-Json
 if($sameWindow.seamless -ne 'PASS' -or -not $sameWindow.window_handle_preserved -or -not $sameWindow.detect_doxa_works -or $sameWindow.driver_changes){
  throw "Welcome-to-main form continuity contract failed ($language)"
 }
 $passed++
 foreach($width in @(0,440,480,522)){
  $argsForUi=@{Smoke=$true;Language=$language}
  if($width -ne 0){$argsForUi.CompactTestWidth=$width}
  $x=(& $main @argsForUi|Out-String)|ConvertFrom-Json
  if($x.smoke -ne 'PASS' -or $x.developer_controls_visible -or
     $x.driver_changes_without_user_action -or $x.cloud_ai_connected -or
     -not $x.device_illustration_accessible -or
     -not $x.side_within_horizontal_bounds -or
     -not $x.connection_steps_wired -or -not $x.resize_supported -or $x.language_dropdown_count -ne 2 -or ($x.short_laptop_layout -and -not $x.critical_buttons_visible) -or
     $x.exact_detect_button_text -ne $(if($language -eq 'en'){'Detect Doxa'}else{'Detecteaza Doxa'})){
   throw "Main customer UI contract failed ($language, $width)"
  }
  if($width -ne 0){
   if($x.layout_mode -ne 'compact_stacked' -or
      $x.reinstall_button_width -lt 280 -or
      $x.compact_scrollbar_margin -lt 17){
    throw "Compact UI clipped a critical control ($language, $width)"
   }
  }

  if($width -eq 0 -and $x.short_laptop_layout -and -not $x.window_fits_work_area){throw 'Real-height laptop window clips its bottom'}
  $passed++
 }
}
[ordered]@{
 status='PASS';cases=$passed;languages=@('en','ro')
 simulated_compact_widths=@(440,480,522)
 read_only=$true;remote_ai_calls=0;driver_changes=0;local_check_privacy_link=$true;detect_doxa_exact=$true;one_window_transition=$true
}|ConvertTo-Json -Compress
