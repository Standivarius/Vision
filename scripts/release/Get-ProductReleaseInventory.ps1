[CmdletBinding()]
param(
 [switch]$Offline,
 [string]$DoxaReleaseDirectory = ''
)
# Read-only evidence inventory. Does not deploy, sign, delete, install or restart.
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$worktrees=@(& git -C $repo worktree list --porcelain | Where-Object {$_ -match '^worktree '})
$records=@()
if(-not $Offline){
 $gh=Get-Command gh -ErrorAction SilentlyContinue
 if($gh){
  $json=& gh release list --repo Standivarius/Vision --limit 100 --json tagName,name,isDraft,isPrerelease,publishedAt,createdAt
  if($LASTEXITCODE -eq 0 -and $json){$records=ConvertFrom-Json -InputObject ($json -join "`n")}
 }
}
$visionPublished=@($records|Where-Object{ $_.tagName -match '^v\d' -and -not $_.isDraft }|Sort-Object publishedAt -Descending)
$doxaDrafts=@($records|Where-Object{ $_.tagName -like 'doxa-*' -and $_.isDraft }|Sort-Object createdAt -Descending)
$releaseCheck=[ordered]@{supplied=([bool]$DoxaReleaseDirectory);status='NOT_CHECKED';manifest_sha256='';unsigned_exes=@();files_verified=0}
if($DoxaReleaseDirectory){
 $dir=[IO.Path]::GetFullPath($DoxaReleaseDirectory)
 $manifestPath=Join-Path $dir 'RELEASE-MANIFEST.json'
 if(-not(Test-Path $manifestPath -PathType Leaf)){throw 'Missing Doxa release manifest; do not publish'}
 $manifest=Get-Content $manifestPath -Raw|ConvertFrom-Json
 if($manifest.product -ne 'Standivarius Doxa Setup'){throw 'Wrong release product'}
 $releaseCheck.manifest_sha256=(Get-FileHash $manifestPath -Algorithm SHA256).Hash
 foreach($f in @($manifest.files)){
  $relative=[string]$f.path
  if([IO.Path]::IsPathRooted($relative) -or $relative -match '(^|[\\/])\.\.([\\/]|$)'){throw "Unsafe release path $relative"}
  $target=Join-Path $dir $relative
  if(-not(Test-Path $target -PathType Leaf)){throw "Release file absent: $relative"}
  if((Get-FileHash $target -Algorithm SHA256).Hash -ine [string]$f.sha256){throw "Release file checksum mismatch: $relative"}
  if((Get-Item $target).Length -ne [long]$f.bytes){throw "Release size mismatch: $relative"}
  $releaseCheck.files_verified++
 }
 foreach($exe in @('Personal\DoxaSetup.exe','ManageEngine\DoxaDeploy.exe')){
  $path=Join-Path $dir $exe
  if(-not(Test-Path $path)){throw "Doxa executable missing: $exe"}
  if((Get-AuthenticodeSignature $path).Status -ne 'Valid'){$releaseCheck.unsigned_exes+= $exe}
 }
 $releaseCheck.status=if($releaseCheck.unsigned_exes.Count){'OWNER_TEST_ONLY_UNSIGNED'}else{'SIGNED_BYTES_PRESENT_VERIFY_QUALIFICATIONS'}
}
$report=[ordered]@{
 generated_utc=[DateTime]::UtcNow.ToString('o')
 repository='Standivarius/Vision'
 worktree_count=$worktrees.Count
 products=@(
  [ordered]@{name='Doxa Setup';source_branch='release/doxa-unified-20261106';current_owner_test_tag='doxa-universal-online-live-validated-20261105-owner-test';commercial_release='NOT_ACCEPTED';github_draft_count=$doxaDrafts.Count;release_checks=$releaseCheck;requires=@('signed and timestamped Standivarius/DMR publisher EXEs','OEM MSI distribution permission','approved personal/Intune/ManageEngine physical acceptance','final GDPR notice')},
  [ordered]@{name='Vision';source_branch='master';published_alpha=if($visionPublished.Count){$visionPublished[0].tagName}else{'NOT_QUERIED'};software_release_channel='Velopack alpha';requires=@('new source build tests','physical display + accessibility qualification','provenance and update smoke')}
 )
 no_mutation_performed=$true
}
$report | ConvertTo-Json -Depth 9