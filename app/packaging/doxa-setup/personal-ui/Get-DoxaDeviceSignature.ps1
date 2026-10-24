param([switch]$PublicOnly,[string]$SignBody)
# Developer-only Dell device enrolment for Doxa Setup.
# The private key is Windows DPAPI-protected under the current user and NEVER sent to the cloud.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Security
$vault=Join-Path $env:LOCALAPPDATA 'Standivarius\DeveloperAccess\DoxaSetup'
$keyFile=Join-Path $vault 'client-rsa-key.dpapi'
$publicFile=Join-Path (Split-Path -Parent $PSScriptRoot) 'assistant\client-public-key.json'
function UrlBase64([byte[]]$data){
 [Convert]::ToBase64String($data).TrimEnd('=').Replace('+','-').Replace('/','_')
}
if(-not(Test-Path -LiteralPath $keyFile)){
 # The enrolled Dell private key never travels in the portable ZIP.
 # On other Windows users the installer still works with curated offline help.
 if(Test-Path -LiteralPath $publicFile){
  throw 'Online Doxa assistance is enrolled for the original Dell user only. Offline help remains available on this PC.'
 }
 $rsa=New-Object Security.Cryptography.RSACryptoServiceProvider(2048)
 try{
  $private=$rsa.ExportCspBlob($true)
  $pub=$rsa.ExportParameters($false)
  $public=[ordered]@{kty='RSA';alg='RS256';n=(UrlBase64 $pub.Modulus);e=(UrlBase64 $pub.Exponent);ext=$true}
  if(-not(Test-Path $vault)){New-Item -ItemType Directory -Path $vault -Force|Out-Null}
  $protected=[Security.Cryptography.ProtectedData]::Protect($private,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
  [IO.File]::WriteAllBytes($keyFile,$protected)
  if(Test-Path -LiteralPath $publicFile){throw 'Public key exists without private identity. Refusing to silently rotate.'}
  [IO.File]::WriteAllText($publicFile,($public|ConvertTo-Json -Compress),[Text.UTF8Encoding]::new($false))
  [Array]::Clear($private,0,$private.Length)
 }finally{$rsa.Dispose()}
}
if(-not(Test-Path -LiteralPath $publicFile)){throw 'Public identity file missing; refusing to sign.'}
if($PublicOnly){
 $p=Get-Content -LiteralPath $publicFile -Raw -Encoding UTF8|ConvertFrom-Json
 'DEVICE_PRIVATE_KEY=WINDOWS_DPAPI'
 'DEVICE_PUBLIC_KEY=READY'
 'RSA_BITS=2048'
 return
}
if([string]::IsNullOrEmpty($SignBody)){throw 'No request payload to sign.'}
$encrypted=[IO.File]::ReadAllBytes($keyFile)
$private=[Security.Cryptography.ProtectedData]::Unprotect($encrypted,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
$rsa=New-Object Security.Cryptography.RSACryptoServiceProvider
try{
 $rsa.ImportCspBlob($private)
 $timestamp=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 $bytes=[Text.Encoding]::UTF8.GetBytes(([string]$timestamp)+[char]10+$SignBody)
 $signature=$rsa.SignData($bytes,[Security.Cryptography.SHA256]::Create())
 [ordered]@{timestamp=$timestamp;signature=(UrlBase64 $signature)}|ConvertTo-Json -Compress
}finally{
 $rsa.Dispose()
 [Array]::Clear($private,0,$private.Length)
}
