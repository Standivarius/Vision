param(
 [switch]$PublicOnly,
 [switch]$PrepareEnrollment,
 [string]$SignBody,
 [long]$TimestampOverride=0
)
# Automatic first-use identity: no vendor endpoint mutation and no manual approval.
# Every installation maintains its own DPAPI-encrypted private signing key in
# the Windows profile; only the public JWK may be transmitted to the AI service.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Security
$vault=Join-Path $env:LOCALAPPDATA 'Standivarius\DeveloperAccess\DoxaSetup'
$keyFile=Join-Path $vault 'client-rsa-key.dpapi'
$localPublic=Join-Path $vault 'client-public-key.json'
$legacyPublic=Join-Path (Split-Path -Parent $PSScriptRoot) 'assistant\client-public-key.json'
function Base64Url([byte[]]$data){[Convert]::ToBase64String($data).TrimEnd('=').Replace('+','-').Replace('/','_')}
function ReadJwk([string]$file){
 $key=Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json
 if($key.kty -ne 'RSA' -or $key.alg -ne 'RS256' -or $key.n -notmatch '^[A-Za-z0-9_-]{320,400}$' -or $key.e -notmatch '^[A-Za-z0-9_-]{2,8}$'){
  throw 'Unrecognized Doxa public key material'
 }
 return $key
}
function DeviceId($jwk){
 $bytes=[Text.Encoding]::ASCII.GetBytes([string]$jwk.n)
 $sha=[Security.Cryptography.SHA256]::Create()
 try {return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').Substring(0,24).ToLowerInvariant()}
 finally {$sha.Dispose()}
}
function NewDeviceKey {
 if(Test-Path -LiteralPath $keyFile){throw 'Existing private identity cannot be replaced automatically'}
 if(-not(Test-Path -LiteralPath $vault)){New-Item -ItemType Directory -Path $vault -Force|Out-Null}
 $rsa=New-Object Security.Cryptography.RSACryptoServiceProvider(2048)
 try{
  $rsa.PersistKeyInCsp=$false
  $raw=$rsa.ExportCspBlob($true)
  $pub=$rsa.ExportParameters($false)
  $public=[ordered]@{kty='RSA';alg='RS256';n=(Base64Url $pub.Modulus);e=(Base64Url $pub.Exponent);ext=$true}
  $encrypted=[Security.Cryptography.ProtectedData]::Protect($raw,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
  [IO.File]::WriteAllBytes($keyFile,$encrypted)
  [IO.File]::WriteAllText($localPublic,($public | ConvertTo-Json -Compress),[Text.UTF8Encoding]::new($false))
  [Array]::Clear($raw,0,$raw.Length)
 }finally{$rsa.Dispose()}
}
# Previous installer builds could leave an encrypted private key without its
# matching public-key file. Recreate ONLY the public component from that key;
# never substitute the bundled Dell public key or erase a private identity.
function RestoreLocalPublicKey {
 if(-not(Test-Path -LiteralPath $keyFile)){throw 'No signing key exists to recover'}
 $encrypted=[IO.File]::ReadAllBytes($keyFile)
 $plain=[Security.Cryptography.ProtectedData]::Unprotect($encrypted,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
 $rsa=New-Object Security.Cryptography.RSACryptoServiceProvider
 try{
  $rsa.PersistKeyInCsp=$false
  $rsa.ImportCspBlob($plain)
  $parameters=$rsa.ExportParameters($false)
  $jwk=[ordered]@{kty='RSA';alg='RS256';n=(Base64Url $parameters.Modulus);e=(Base64Url $parameters.Exponent);ext=$true}
  $temporary=$localPublic+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
  try{
   [IO.File]::WriteAllText($temporary,($jwk|ConvertTo-Json -Compress),[Text.UTF8Encoding]::new($false))
   if(-not(Test-Path -LiteralPath $localPublic)){[IO.File]::Move($temporary,$localPublic)}
  }finally{if(Test-Path -LiteralPath $temporary){Remove-Item -LiteralPath $temporary -Force}}
 }finally{$rsa.Dispose();[Array]::Clear($plain,0,$plain.Length)}
}
if($PrepareEnrollment -and -not(Test-Path -LiteralPath $keyFile)){NewDeviceKey}
if(Test-Path -LiteralPath $keyFile){
 if(-not(Test-Path -LiteralPath $localPublic)){RestoreLocalPublicKey}
}
if(-not(Test-Path -LiteralPath $keyFile)){
 throw 'No Online AI identity exists in this Windows profile. Start Doxa Setup and select Online AI Help to create one automatically.'
}
$keyPath=$localPublic
if(-not(Test-Path -LiteralPath $keyPath)){throw 'Online AI public identity could not be recovered'}
$jwk=ReadJwk $keyPath
$clientId=DeviceId $jwk
if($PublicOnly -or $PrepareEnrollment){
 [ordered]@{schema_version=2;client_id=$clientId;public_jwk=$jwk;private_key_protection='Windows DPAPI CurrentUser';manual_approval_required=$false;automatic_enrolment=$true}|ConvertTo-Json -Depth 4 -Compress
 return
}
if([string]::IsNullOrWhiteSpace($SignBody)){throw 'No request body to sign'}
$encrypted=[IO.File]::ReadAllBytes($keyFile)
$raw=[Security.Cryptography.ProtectedData]::Unprotect($encrypted,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
$rsa=New-Object Security.Cryptography.RSACryptoServiceProvider
try{
 $rsa.PersistKeyInCsp=$false
 $rsa.ImportCspBlob($raw)
 # Fail closed if the private key is inconsistent with the persisted public identity.
 $pub=$rsa.ExportParameters($false)
 if((Base64Url $pub.Modulus) -cne [string]$jwk.n){throw 'Stored Doxa private/public key mismatch'}
 $timestamp=if($TimestampOverride -gt 0){$TimestampOverride}else{[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()}
 $data=[Text.Encoding]::UTF8.GetBytes(([string]$timestamp)+[char]10+$SignBody)
 $signature=$rsa.SignData($data,[Security.Cryptography.SHA256]::Create())
 [ordered]@{client_id=$clientId;timestamp=$timestamp;signature=(Base64Url $signature)}|ConvertTo-Json -Compress
}finally{
 $rsa.Dispose()
 [Array]::Clear($raw,0,$raw.Length)
}
