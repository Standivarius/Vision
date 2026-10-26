param(
 [switch]$PublicOnly,
 [switch]$PrepareEnrollment,
 [string]$SignBody
)
# Customer-ready enrollment preparation: no vendor endpoint mutation.
# Every device maintains its own DPAPI-encrypted RSA private key in the Windows profile.
# A server operator must independently approve the exported PUBLIC identity before AI works.
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
if($PrepareEnrollment){
 if(-not(Test-Path -LiteralPath $keyFile)){NewDeviceKey}
 elseif(-not(Test-Path -LiteralPath $localPublic) -and -not(Test-Path -LiteralPath $legacyPublic)){
  throw 'Key exists but public identity is missing; manual recovery required'
 }
}
if(-not(Test-Path -LiteralPath $keyFile)){
 throw 'Doxa online AI is not enrolled on this Windows profile. Offline setup is available; an operator must approve this device for online assistance.'
}
# Existing Dell remains valid with the original bundle public JWK. New machines
# export a different JWK inside the per-user vault; never overwrite bundled Dell identity.
$keyPath=if(Test-Path -LiteralPath $localPublic){$localPublic}else{$legacyPublic}
if(-not(Test-Path -LiteralPath $keyPath)){throw 'Public identity missing; refusing to sign'}
$jwk=ReadJwk $keyPath
$clientId=DeviceId $jwk
if($PublicOnly -or $PrepareEnrollment){
 [ordered]@{schema_version=1;client_id=$clientId;public_jwk=$jwk;private_key_protection='Windows DPAPI CurrentUser';approved_by_server=$false}|ConvertTo-Json -Depth 4 -Compress
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
 $timestamp=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 $data=[Text.Encoding]::UTF8.GetBytes(([string]$timestamp)+[char]10+$SignBody)
 $signature=$rsa.SignData($data,[Security.Cryptography.SHA256]::Create())
 [ordered]@{client_id=$clientId;timestamp=$timestamp;signature=(Base64Url $signature)}|ConvertTo-Json -Compress
}finally{
 $rsa.Dispose()
 [Array]::Clear($raw,0,$raw.Length)
}
