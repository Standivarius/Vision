param(
 [Parameter(Mandatory=$true)][string]$PackagePath,
 [switch]$Apply,
 [string]$LogDirectory=''
)
# Standivarius Doxa-only personal installer. Pinned official vendor MSI.
# No downloads, shell scripts from the model, policy changes, firmware operations or reboot.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$script:msiStarted=$false
function Finish([string]$Code,[string]$Message,[int]$ExitCode=0){
 [ordered]@{schema_version=1;code=$Code;message=$Message;applied=[bool]$script:msiStarted;reboot_started=$false;exit_code=$ExitCode}|ConvertTo-Json -Compress
}
$gate=(& (Join-Path $PSScriptRoot 'Test-DoxaPackageGate.ps1') -PackagePath $PackagePath | Out-String)|ConvertFrom-Json
if(-not [bool]$gate.allowed){Finish ([string]$gate.code) ([string]$gate.reason) 20;return}
$live=(& (Join-Path $PSScriptRoot 'Get-DoxaSetupExperience.ps1') -Fault none | Out-String)|ConvertFrom-Json
if($live.observed.signed_driver_present){
 Finish 'already_installed' 'The verified signed Doxa driver is already installed; no reinstall is needed.'
 return
}
if($live.code -eq 'doxa_not_detected'){
 if($live.observed.driver_package_in_store){
  Finish 'package_staged_connect_doxa' 'The verified driver package is already stored in Windows. Connect Doxa power and USB before testing its screens.'
 }else{
  Finish 'preconnection_install_unqualified' 'This vendor MSI has hardware-dependent install actions. Pre-connection installation is not yet qualified; connect Doxa before applying it.' 26
 }
 return
}
if($live.code -eq 'driver_untrusted'){
 Finish 'existing_driver_requires_review' 'A different driver is present. Setup will not overwrite it automatically.' 22
 return
}
if(-not $Apply){Finish 'ready_to_install' 'Verified original Silicon Motion MSI. Installation requires explicit approval and Windows administrator permission.';return}
$id=[Security.Principal.WindowsIdentity]::GetCurrent()
$principal=[Security.Principal.WindowsPrincipal]::new($id)
if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
 Finish 'uac_required' 'Run this signed-package installation with Windows administrator approval.' 23
 return
}
if(-not $LogDirectory){
 $LogDirectory=Join-Path $env:ProgramData 'Standivarius\DoxaSetup\Logs'
}
if(-not(Test-Path -LiteralPath $LogDirectory)){
 try{New-Item -ItemType Directory -Force -Path $LogDirectory|Out-Null}catch{Finish 'log_directory_denied' 'Windows could not prepare the installation log directory.' 24;return}
}
$log=Join-Path $LogDirectory ('doxa-driver-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.log')
# Use Windows Installer only; packaged vendor MSI is not modified.
$arguments='/i "'+[IO.Path]::GetFullPath($PackagePath)+'" /passive /norestart /L*v "'+$log+'"'
try{
 $process=Start-Process -FilePath (Join-Path $env:WINDIR 'System32\msiexec.exe') -ArgumentList $arguments -PassThru -Wait
 $script:msiStarted=$true
 $code=[int]$process.ExitCode
}catch{
 Finish 'windows_installer_launch_failed' 'Windows Installer could not start. No security settings were changed.' 25
 return
}
if($code -notin @(0,3010)){
 Finish 'vendor_msi_error' ("Official driver installer returned Windows Installer code "+$code+". Review the local installation log.") $code
 return
}
$after=(& (Join-Path $PSScriptRoot 'Get-DoxaSetupExperience.ps1') -Fault none | Out-String)|ConvertFrom-Json
if(-not $after.observed.signed_driver_present){
 Finish 'verification_pending' 'Windows Installer finished but the signed driver is not yet confirmed. Check Device Manager and SetupAPI logs.' $code
 return
}
if($code -eq 3010){
 Finish 'restart_required' 'Windows Installer completed and reported that a restart is required. No restart was started.' $code
 return
}
Finish 'installed_verified' 'The original signed Silicon Motion driver is installed; verify external panels after connecting Doxa.'
