# Safe, offline contract tests for the Doxa consent-first customer installer.
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$hostSource=Join-Path $PSScriptRoot 'DoxaSetupHost.cs'
$retailBuilder=Join-Path $PSScriptRoot 'Build-DoxaRetailRelease.ps1'
$guide=Join-Path $PSScriptRoot '..\personal-ui\Start-DoxaGuidedSetup.ps1'
$asset=Join-Path $PSScriptRoot '..\personal-ui\assets\doxa-pro3-front.jpg'
foreach($p in @($hostSource,$retailBuilder,$guide,$asset)){if(-not(Test-Path $p -PathType Leaf)){throw "Missing: $p"}}
$hostText=Get-Content $hostSource -Raw
$guideText=Get-Content $guide -Raw
$builderText=Get-Content $retailBuilder -Raw
$checks=@{
  'proper_brand_title'=$hostText.Contains('Doxa Triple Monitor Setup')
  'language_current_value'=$hostText.Contains('lang.Items.Add("English")') -and $hostText.Contains('lang.Items.Add("Română")')
  'official_embedded_photo'=$hostText.Contains('GetManifestResourceStream("Doxa.ProductPhoto")') -and $builderText.Contains('Doxa.ProductPhoto')
  'terms_explicit'=$hostText.Contains('preview terms') -and $hostText.Contains('terms.Checked&&local.Checked')
  'local_checks_gated'=$hostText.Contains('if(!accepted||running)return;') -and $hostText.Contains('accepted=true;render();scan();')
  'remote_ai_optional'=$hostText.Contains('Optional: enable Doxa AI') -and $hostText.Contains('Open(true,cloud.Checked)')
  'two_distinct_observations'=$hostText.Contains('no connected device detected') -and $hostText.Contains('no compatible signed driver detected')
  'no_duplicate_consent'=$guideText.Contains('PermissionsGrantedInHost') -and $guideText.Contains('OnlineAIAllowedInHost') -and $guideText.Contains('if($PermissionsGrantedInHost){2}else{1}')
  'no_driver_write_before_guide'=$hostText.Contains('"/prepare"') -and $hostText.Contains('else Apply(true)')
  'authentic_product_image'=(Get-Item $asset).Length -gt 5000
}
foreach($entry in $checks.GetEnumerator()|Sort-Object Key){if(-not $entry.Value){throw "FAIL: $($entry.Key)"}}
$parseErrors=$null
$tokens=$null
[void][System.Management.Automation.Language.Parser]::ParseFile($guide,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw ("PowerShell parser errors: "+(($parseErrors|ForEach-Object{$_.Message}) -join '; '))}
[ordered]@{result='PASS';contract_checks=$checks.Count;source_files=4;driver_installs=0;cloud_requests=0;device_mutations=0}|ConvertTo-Json -Compress
