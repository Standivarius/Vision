# Offline, current-path consent and installer contract test.
# Never installs a driver, opens an online session or changes the desktop.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$hostFile=Join-Path $PSScriptRoot 'DoxaSetupHost.cs'
$guide=Join-Path $root 'personal-ui\Start-DoxaGuidedSetup.ps1'
$main=Join-Path $root 'personal-ui\Start-DoxaSetup.ps1'
$policy=Join-Path $root 'personal-ui\Get-DoxaCloudAIPolicy.ps1'
$terms=Join-Path $root 'personal-ui\DOXA-SETUP-TERMS.txt'
foreach($f in @($hostFile,$guide,$main,$policy,$terms)){if(-not(Test-Path $f -PathType Leaf)){throw "Missing live consent dependency: $f"}}
$hostText=[IO.File]::ReadAllText($hostFile)
$guideText=[IO.File]::ReadAllText($guide)
$mainText=[IO.File]::ReadAllText($main)
$termsText=[IO.File]::ReadAllText($terms)
$checks=[ordered]@{
 'one_window_default'=($hostText.Contains('if(arg==""){return OpenSingleWindow();}') -and -not $hostText.Contains('static void UI(){'))
 'no_dead_native_consent'=(-not $hostText.Contains('static void Open(bool ') -and -not $hostText.Contains('Doxa.ProductPhoto'))
 'no_driver_write_on_window_open'=($hostText.Contains('ExtractApplication(payload,extracted)') -and $hostText.Contains('"/prepare"'))
 'terms_checkbox_required'=($guideText.Contains('$terms.Checked') -and $guideText.Contains('$local.Checked') -and $guideText.Contains('DOXA-SETUP-TERMS.txt'))
 'three_distinct_permissions'=($guideText.Contains('$termsLabel') -and $guideText.Contains('$localLabel') -and $guideText.Contains('$cloudLabel'))
 'online_ai_optional'=($guideText.Contains('OnlineAIAllowedInHost') -and $guideText.Contains('$cloud.Checked') -and $mainText.Contains('Online AI selected'))
 'formatted_terms_read_only'=($guideText.Contains('Windows.Forms.RichTextBox') -and $guideText.Contains('$copy.ReadOnly=$true') -and $guideText.Contains('Windows.Forms.TableLayoutPanel') -and $guideText.Contains('RowStyles.Add') -and $guideText.Contains('Controls.Add($copy,0,0)') -and $guideText.Contains('Controls.Add($footer,0,1)') -and $guideText.Contains('$copy.DetectUrls=$false'))
 'signature_neutral_terms'=($termsText.Contains('pre-release version') -and -not $termsText.Contains('current unsigned build'))
 'preview_version_unique'=($hostText.Contains('0.4.0-preview.13') -and -not $hostText.Contains('0.4.0-preview.12'))
}
foreach($name in $checks.Keys){if(-not $checks[$name]){throw "Consent contract FAIL: $name"}}
$parseErrors=$null;$tokens=$null
[void][Management.Automation.Language.Parser]::ParseFile($guide,[ref]$tokens,[ref]$parseErrors)
if(@($parseErrors).Count){throw ('Guided UI parser failure: '+($parseErrors|Out-String))}
$smoke=(& $guide -Smoke|Out-String)|ConvertFrom-Json
if(-not $smoke.checkbox_alignment_pass -or -not $smoke.terms_of_use_available){throw 'Live guided welcome smoke failed'}
[ordered]@{status='PASS';checks=$checks.Count;native_UI='SINGLE_WINDOW';terms_visible='CHECKED_SOURCE_ONLY';local_checks_opt_in='PASS';remote_ai_opt_in='PASS';driver_installs=0;cloud_requests=0}|ConvertTo-Json -Compress
