param([string]$OutputDirectory='', [switch]$Reproducible)
# Vendor-neutral managed deployment preview; app-only, unsigned.
# The same DoxaPilot.ps1 and source-built personal payload are used by Intune.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
if(-not $OutputDirectory){$OutputDirectory=Join-Path $repo 'artifacts\releases\managed'}
$output=[IO.Path]::GetFullPath($OutputDirectory)
$stage=Join-Path $env:TEMP ('DoxaManagedBuild-'+[Guid]::NewGuid().ToString('N'))
$bundleOut=Join-Path $stage 'personal'
$src=Join-Path $stage 'package'
$extract=Join-Path $stage 'verify'
try{
 New-Item -Path $bundleOut,$src,$extract -ItemType Directory -Force|Out-Null
 $created=(& (Join-Path $PSScriptRoot 'Build-DoxaPersonalBundle.ps1') -OutputDirectory $bundleOut -Reproducible:$Reproducible|Out-String)|ConvertFrom-Json
 if($created.status -ne 'created' -or $created.vendor_msi_included -or $created.credentials_included){throw 'Personal app-only builder refused'}
 $verified=(& (Join-Path $PSScriptRoot 'Test-DoxaPersonalBundle.ps1') -BundlePath $created.path|Out-String)|ConvertFrom-Json
 if($verified.status -ne 'PASS' -or $verified.archive_total_files -ne 19){throw 'Extracted personal payload failed verification'}
 Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'enterprise-intune-pilot\DoxaPilot.ps1') -Destination (Join-Path $src 'DoxaPilot.ps1')
 Copy-Item -LiteralPath ([string]$created.path) -Destination (Join-Path $src 'DoxaSetupPayload.zip')
 $py=Get-Command python.exe -ErrorAction Stop
 $test=(& $py.Source (Join-Path $PSScriptRoot 'enterprise-intune-pilot\Test-DoxaPilot.py') --payload (Join-Path $src 'DoxaSetupPayload.zip')|Out-String)|ConvertFrom-Json
 if($test.status -ne 'PASS' -or $test.driver_installation){throw 'Silent app-only lifecycle validation failed'}
 # Do not place manifests or additional executables inside the deployment directory.
 $fileNames=@((Get-ChildItem -LiteralPath $src -File).Name)
 if($fileNames.Count -ne 2 -or $fileNames -notcontains 'DoxaPilot.ps1' -or $fileNames -notcontains 'DoxaSetupPayload.zip'){throw 'Unexpected managed package contents'}
 if(-not(Test-Path -LiteralPath $output)){New-Item -ItemType Directory -Path $output -Force|Out-Null}
 $name='Doxa-Managed-AppOnly-Pilot-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.zip'
 $outFile=Join-Path $output $name
 if(Test-Path -LiteralPath $outFile){throw 'Refusing to overwrite managed pilot artifact'}
 if($Reproducible){
  & python (Join-Path $PSScriptRoot 'Build-DoxaStableZip.py') $src $outFile | Out-Null
  if($LASTEXITCODE -ne 0){throw 'Reproducible managed ZIP failed'}
 }else{
 Compress-Archive -LiteralPath (Join-Path $src 'DoxaPilot.ps1'),(Join-Path $src 'DoxaSetupPayload.zip') -DestinationPath $outFile -CompressionLevel Optimal
 }
 Expand-Archive -LiteralPath $outFile -DestinationPath $extract
 $actual=@(Get-ChildItem -LiteralPath $extract -File -Recurse)
 if($actual.Count -ne 2){throw 'Managed ZIP contains unexpected files'}
 foreach($file in $actual){
  if((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath (Join-Path $src $file.Name) -Algorithm SHA256).Hash){throw 'Managed archive round-trip mismatch'}
 }
 [ordered]@{
  status='LOCAL_PASS'
  package_type='DOXA_MANAGED_APP_ONLY_UNSIGNED_PILOT'
  artifact=$outFile
  sha256=(Get-FileHash -LiteralPath $outFile -Algorithm SHA256).Hash
  application_payload_sha256=(Get-FileHash -LiteralPath (Join-Path $src 'DoxaSetupPayload.zip') -Algorithm SHA256).Hash
  source_file_count=16
  archive_file_count=19
  distribution_files=2
  local_lifecycle_cases=@($test.steps).Count
  vendor_driver_included=$false
  remote_ai_enabled_by_install=$false
  managed_deployment='NOT_PERFORMED'
  signed_release=$false
 }|ConvertTo-Json -Depth 5
}finally{
 if(Test-Path -LiteralPath $stage){Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue}
}
