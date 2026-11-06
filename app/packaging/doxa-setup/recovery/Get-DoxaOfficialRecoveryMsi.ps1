param(
 [string]$OutputDirectory='',
 [string]$ArchivePath='',
 [switch]$Download
)
# Vendor-direct local preparation ONLY. Never runs MSI, changes PnP state or deploys software.
# Only one exact official archive and one expected MSI name are accepted. No credentials.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$uri='https://www.siliconmotion.com/downloads/SMI-USB-Display-SW-MSI-for-Windows-4.7-R06.zip'
$zipName='SMI-USB-Display-SW-MSI-for-Windows-4.7-R06.zip'
$zipHash='DD41326F9641D6E43DC2F2A42AC515902F497F7A376E77F9FB5D22DB6DD8C383'
$msiName='SMIUSBDisplaySW770.msi'
$expectedMsiHash='3379B46DA029423748E2D2E64DB2015B50136E310A492E31857CC726719192D4'
$expectedThumb='81956F4C8904963B707B994E42FEA1EDBBFA51C6'
$msiLength=6816256L
if(-not $OutputDirectory){$OutputDirectory=Join-Path $env:LOCALAPPDATA 'Standivarius\DoxaRecovery\vendor'}
if($ArchivePath -and $Download){throw 'Choose exactly one source: ArchivePath or Download'}
if(-not $ArchivePath -and -not $Download){
 [ordered]@{operation='describe_official_source';vendor_url=$uri;expected_archive_sha256=$zipHash;expected_msi_sha256=$expectedMsiHash;downloads_started=$false;installation_started=$false}|ConvertTo-Json -Compress
 return
}
$dir=[IO.Path]::GetFullPath($OutputDirectory)
if(-not(Test-Path -LiteralPath $dir)){New-Item -ItemType Directory -Path $dir -Force|Out-Null}
$msi=Join-Path $dir $msiName
if(Test-Path -LiteralPath $msi){
 $existing=(Get-FileHash -LiteralPath $msi -Algorithm SHA256).Hash
 if($existing -ine $expectedMsiHash){throw 'Existing MSI has a different hash; will not replace or install it'}
 $sign=Get-AuthenticodeSignature -LiteralPath $msi
 if($sign.Status -ne 'Valid' -or $sign.SignerCertificate.Thumbprint -ine $expectedThumb){throw 'Existing MSI signer invalid'}
 [ordered]@{operation='verify_existing_official_msi';file=$msi;code='verified_source_only';sha256=$existing;ready_for_separate_installer_gate=$true;installation_started=$false}|ConvertTo-Json -Compress
 return
}
$zip=$null
$temporary=$null
$candidate=$null
try{
 if($Download){
  # Do not follow redirects across different hosts or protocols.
  $request=[System.Net.HttpWebRequest][System.Net.WebRequest]::Create($uri)
  $request.AllowAutoRedirect=$false
  $request.Timeout=30000
  $request.ReadWriteTimeout=30000
  $response=$request.GetResponse()
  try{
   if([int]$response.StatusCode -ne 200){throw 'Unexpected vendor download response; redirects not accepted'}
   if($response.ContentLength -gt 7500000){throw 'Unexpectedly large vendor archive'}
   $temporary=Join-Path $dir ($zipName+'.partial')
   if(Test-Path -LiteralPath $temporary){throw 'Existing partial download: remove it manually before retrying'}
   $in=$response.GetResponseStream()
   $out=[IO.File]::Create($temporary)
   try{$in.CopyTo($out)}finally{$out.Dispose();$in.Dispose()}
  }finally{$response.Dispose()}
  $zip=$temporary
 }else{
  if(-not(Test-Path -LiteralPath $ArchivePath -PathType Leaf)){throw 'Vendor archive not found'}
  $zip=[IO.Path]::GetFullPath($ArchivePath)
 }
 $actualZipHash=(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
 if($actualZipHash -ine $zipHash){throw 'Vendor ZIP hash did not match pinned official baseline'}
 Add-Type -AssemblyName System.IO.Compression.FileSystem
 $archive=[IO.Compression.ZipFile]::OpenRead($zip)
 try{
  $entries=@($archive.Entries)
  if($entries.Count -ne 1 -or $entries[0].FullName -cne $msiName -or $entries[0].Length -ne $msiLength){throw 'Vendor ZIP contents differ from pinned MSI'}
  $candidate=Join-Path $dir ($msiName+'.partial')
  if(Test-Path -LiteralPath $candidate){throw 'MSI partial file already exists; refuse overwrite'}
  $entryStream=$entries[0].Open()
  $fileStream=[IO.File]::Create($candidate)
  try{$entryStream.CopyTo($fileStream)}finally{$fileStream.Dispose();$entryStream.Dispose()}
 }finally{$archive.Dispose()}
 $hash=(Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash
 if($hash -ine $expectedMsiHash){throw 'Extracted MSI SHA256 does not match pinned official baseline'}
 $signature=Get-AuthenticodeSignature -LiteralPath $candidate
 if($signature.Status -ne 'Valid' -or -not $signature.SignerCertificate -or $signature.SignerCertificate.Thumbprint -ine $expectedThumb){
  throw 'Extracted vendor MSI publisher signature not verified'
 }
 Move-Item -LiteralPath $candidate -Destination $msi
 [ordered]@{operation='stage_vendor_original_for_local_use';file=$msi;code='verified_source_only';sha256=$hash;signer='Silicon Motion, Inc.';ready_for_separate_installer_gate=$true;installation_started=$false;driver_changes=$false}|ConvertTo-Json -Compress
}finally{
 if($temporary -and (Test-Path -LiteralPath $temporary)){Remove-Item -LiteralPath $temporary -Force}
 if($candidate -and (Test-Path -LiteralPath $candidate)){Remove-Item -LiteralPath $candidate -Force}
}
