param([switch]$SelfTest)
# Internal diagnostic experiment. No Windows display, driver, service or registry writes.
# Developer or IT explicitly provides a per-session SHA-256 of an unlock phrase
# as DOXA_RECOVERY_LAB_SHA256 in the current process environment.
$ErrorActionPreference='Stop'
function Get-DoxaRecoveryLabEnabled {
 return [bool]($env:DOXA_RECOVERY_LAB_SHA256 -cmatch '^[a-fA-F0-9]{64}$')
}
function Test-DoxaRecoveryLabUnlock([string]$entered) {
 if(-not (Get-DoxaRecoveryLabEnabled) -or $entered.Length -lt 10 -or $entered.Length -gt 128){return $false}
 $digest=[Security.Cryptography.SHA256]::Create()
 try{
  $hash=([BitConverter]::ToString($digest.ComputeHash([Text.Encoding]::UTF8.GetBytes($entered)))).Replace('-','')
  $expected=$env:DOXA_RECOVERY_LAB_SHA256.ToUpperInvariant()
  $diff=0
  for($i=0;$i -lt 64;$i++){$diff=$diff -bor ([int][char]$hash[$i] -bxor [int][char]$expected[$i])}
  return ($diff -eq 0)
 }finally{$digest.Dispose()}
}
if($SelfTest){
 $original=$env:DOXA_RECOVERY_LAB_SHA256
 try{
  Remove-Item Env:DOXA_RECOVERY_LAB_SHA256 -ErrorAction SilentlyContinue
  if(Get-DoxaRecoveryLabEnabled){throw 'Recovery lab enabled without code hash'}
  if(Test-DoxaRecoveryLabUnlock 'any code'){throw 'Recovery lab accepted without configuration'}
  $secret='local only example recovery phrase 2026'
  $hash=[Security.Cryptography.SHA256]::Create()
  try{$env:DOXA_RECOVERY_LAB_SHA256=([BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($secret)))).Replace('-','')}
  finally{$hash.Dispose()}
  if(-not (Get-DoxaRecoveryLabEnabled)){throw 'Recovery lab configuration ignored'}
  if(-not (Test-DoxaRecoveryLabUnlock $secret)){throw 'Valid local phrase rejected'}
  if(Test-DoxaRecoveryLabUnlock 'not the right secret'){throw 'Incorrect phrase accepted'}
  'PASS: local code-gated fault lab; no display change or cloud request'
 }finally{
  if($null -eq $original){Remove-Item Env:DOXA_RECOVERY_LAB_SHA256 -ErrorAction SilentlyContinue}
  else{$env:DOXA_RECOVERY_LAB_SHA256=$original}
 }
}
