param(
 [Parameter(Mandatory=$true)][string]$ReviewBuildDirectory,
 [Parameter(Mandatory=$true)][string]$SignedPersonalExe,
 [Parameter(Mandatory=$true)][string]$SignedManagedExe,
 [Parameter(Mandatory=$true)][string]$ExpectedPublisherSubject,
 [Parameter(Mandatory=$true)][string]$OutputDirectory,
 [string]$ContentPrepTool='C:\dev\Vision\tools\intune-win32-content-prep-v1.8.7\IntuneWinAppUtil.exe'
)
# Packaging-only post-signing stage. NO source rebuild, no endpoint or driver changes.
# Recomputes every archive and checksum because Windows signing changes PE bytes.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(Test-Path $OutputDirectory){throw 'Refusing to overwrite a release'}
foreach($f in @($SignedPersonalExe,$SignedManagedExe)){
 if(-not(Test-Path $f -PathType Leaf)){throw 'Missing signed executable'}
 $s=Get-AuthenticodeSignature $f
 if($s.Status -ne 'Valid' -or -not $s.SignerCertificate){throw 'Publisher signature not valid'}
 if($s.SignerCertificate.Subject -notmatch [regex]::Escape($ExpectedPublisherSubject)){throw 'Wrong publisher identity'}
}
$toolSig=Get-AuthenticodeSignature $ContentPrepTool
if($toolSig.Status -ne 'Valid' -or $toolSig.SignerCertificate.Subject -notmatch 'Microsoft Corporation'){throw 'Microsoft utility signature not valid'}
$old=Get-Content (Join-Path $ReviewBuildDirectory 'RELEASE-MANIFEST.json') -Raw|ConvertFrom-Json
if($old.product -ne 'Standivarius Doxa Setup' -or -not $old.validated_standalone){throw 'Review baseline not verified'}
$personal=Join-Path $OutputDirectory 'Personal'
$managed=Join-Path $OutputDirectory 'ManageEngine'
$intune=Join-Path $OutputDirectory 'Intune'
$evidence=Join-Path $OutputDirectory 'Evidence'
New-Item $personal,$managed,$intune,$evidence -ItemType Directory -Force | Out-Null
Copy-Item $SignedPersonalExe (Join-Path $personal 'DoxaSetup.exe')
Copy-Item $SignedManagedExe (Join-Path $managed 'DoxaDeploy.exe')
$test=(& (Join-Path $managed 'DoxaDeploy.exe') '/selftest'|Out-String).Trim()
if($LASTEXITCODE -ne 0 -or $test -notmatch '^PASS:'){throw 'Signed release embedded content failed integrity check'}
$managedZip=Join-Path $managed 'Doxa-Managed-Windows.zip'
Compress-Archive -LiteralPath (Join-Path $managed 'DoxaDeploy.exe') -DestinationPath $managedZip -CompressionLevel Optimal
$stage=Join-Path $env:TEMP ('DoxaSignedIntune-'+[guid]::NewGuid().ToString('N'))
try{
 New-Item $stage -ItemType Directory|Out-Null
 Copy-Item $SignedManagedExe (Join-Path $stage 'DoxaDeploy.exe')
 & $ContentPrepTool -c $stage -s DoxaDeploy.exe -o $intune -q *> (Join-Path $evidence 'intune-packaging.log')
 if($LASTEXITCODE){throw 'Signed Win32 package build failed'}
}finally{Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue}
$intunePackages=@(Get-ChildItem $intune -Filter '*.intunewin' -File)
if($intunePackages.Count -ne 1){throw 'Expected one signed Intune package'}
Copy-Item (Join-Path $ReviewBuildDirectory 'README-FIRST.txt') (Join-Path $OutputDirectory 'README-FIRST.txt')
$proof=[ordered]@{
 status='SIGNED_PACKAGING_PASS_PENDING_PHYSICAL_AND_MANAGED_QUALIFICATION'
 publisher_subject=$ExpectedPublisherSubject
 personal_signature=(Get-AuthenticodeSignature (Join-Path $personal 'DoxaSetup.exe')).Status.ToString()
 managed_signature=(Get-AuthenticodeSignature (Join-Path $managed 'DoxaDeploy.exe')).Status.ToString()
 embedded_test=$test
 endpoint_deployments_performed=$false
 source_changes_for_signing=$false
}
$proof|ConvertTo-Json|Set-Content (Join-Path $evidence 'signed-packaging-test.json')
$files=@(Get-ChildItem $OutputDirectory -File -Recurse|Sort-Object FullName|ForEach-Object {
 [ordered]@{relative=$_.FullName.Substring($OutputDirectory.Length+1).Replace('\','/');sha256=(Get-FileHash $_.FullName -Algorithm SHA256).Hash;bytes=$_.Length}
})
[ordered]@{product='Standivarius Doxa Setup';status=$proof.status;signing=$proof;files=$files}|ConvertTo-Json -Depth 8|Set-Content (Join-Path $OutputDirectory 'RELEASE-MANIFEST.json')
$proof|ConvertTo-Json -Depth 4
