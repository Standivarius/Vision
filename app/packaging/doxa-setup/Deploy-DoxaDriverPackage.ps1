param(
 [string]$PackagePath = '',
 [string]$ApprovalManifest = '',
 [string]$EvidenceDirectory = '',
 [switch]$Apply
)
# Enterprise-friendly *driver package* deployment gate; not a new graphics driver.
# Dry run by default. No network, driver download, policy modification or reboot.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest

function Result([string]$Code,[string]$Message,[int]$ExitCode=0) {
 $o=[ordered]@{schema_version=1;code=$Code;message=$Message;apply_requested=[bool]$Apply;reboot_started=$false}
 $o|ConvertTo-Json -Depth 6
 if($ExitCode -ne 0){exit $ExitCode}
}

$profilePath=Join-Path $PSScriptRoot 'profiles\smi770-observed.json'
$profile=Get-Content $profilePath -Raw -Encoding UTF8|ConvertFrom-Json
$inventory = & (Join-Path $PSScriptRoot 'Get-DoxaDriverState.ps1') | Out-String | ConvertFrom-Json

if(-not $PackagePath -or -not $ApprovalManifest) {
 if($Apply){Result 'approval_required' 'No driver installation without a pinned approved package manifest and package path.' 20}
 $inventory|ConvertTo-Json -Depth 10
 return
}

if(-not (Test-Path -LiteralPath $ApprovalManifest -PathType Leaf)){
 Result 'approval_manifest_missing' 'Approved package manifest not found.' 21
}
$approval=Get-Content -LiteralPath $ApprovalManifest -Raw -Encoding UTF8|ConvertFrom-Json
$package = [IO.Path]::GetFullPath($PackagePath)

if ([string]$approval.approval_status -ne 'approved') {
 Result 'package_not_approved' 'Package has not been qualified for Doxa enterprise distribution.' 22
}
if([string]$approval.profile_id -ne [string]$profile.profile_id -or
 [string]$approval.hardware_id_prefix -ne [string]$profile.hardware_id_prefix){
 Result 'hardware_profile_mismatch' 'Approval does not match the verified Doxa hardware profile.' 23
}
if (-not (Test-Path -LiteralPath $package -PathType Leaf) -or
 [IO.Path]::GetExtension($package).ToLowerInvariant() -ne '.msi'){
 Result 'vendor_msi_missing' 'An existing local vendor MSI package is required.' 24
}
if(-not [regex]::IsMatch([string]$approval.sha256,'^[A-Fa-f0-9]{64}$') -or
 -not [regex]::IsMatch([string]$approval.signer_thumbprint,'^[A-Fa-f0-9]{40,64}$')){
 Result 'approval_incomplete' 'SHA-256 and signer thumbprint must be pinned after package qualification.' 25
}
$hash=(Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash
if($hash -ine [string]$approval.sha256){
 Result 'hash_mismatch' 'Vendor driver MSI is not the exact package approved by Doxa IT.' 26
}
$signature=Get-AuthenticodeSignature -LiteralPath $package
if($signature.Status -ne 'Valid' -or $null -eq $signature.SignerCertificate -or
 [string]$signature.SignerCertificate.Thumbprint -ine [string]$approval.signer_thumbprint){
 Result 'signature_mismatch' 'Driver MSI signature/publisher differs from the approved signer.' 27
}
# A valid signed SMI770 driver already driving the hardware must not be
# replaced solely because the pinned MSI is older or has a different version.
# IT can qualify a separate explicit upgrade procedure; this gate is install-only.
if ($inventory.status -in @('signed_driver_present_monitors_detected','signed_driver_present_monitors_missing')) {
 Result 'already_installed' 'Genuine signed Silicon Motion driver already present. Do not replace or downgrade it automatically; check panels and approve any upgrade separately.'
 return
}
if($inventory.status -eq 'driver_identity_or_signature_mismatch'){
 Result 'driver_signature_requires_it_review' 'Existing driver identity differs from approved profile; do not overwrite silently.' 28
}
if($inventory.status -eq 'unsupported_windows'){
 Result 'unsupported_windows' 'This Windows build is outside the observed Doxa baseline.' 29
}
if($inventory.matched_device_count -lt 1 -and -not [bool]$approval.allow_prestage_without_device){
 Result 'hardware_not_present' 'Doxa hardware absent and the package is not approved for pre-staging.' 30
}
if(-not $Apply){
 Result 'approved_package_ready' 'Package hash and signature checked; IT may deploy explicitly. No installation performed.'
}
$id=[Security.Principal.WindowsIdentity]::GetCurrent()
$principal=[Security.Principal.WindowsPrincipal]::new($id)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
 Result 'it_elevation_required' 'Deploy under authorised IT/SYSTEM context; do not request end-user credentials.' 31
}
if(-not $EvidenceDirectory){
 Result 'evidence_directory_required' 'Supply an IT-controlled log directory for signed MSI deployment.' 32
}
if(-not (Test-Path -LiteralPath $EvidenceDirectory -PathType Container)){
 Result 'evidence_directory_missing' 'Pre-create the IT-controlled log directory; no silent path or privilege changes.' 33
}
$logPath=Join-Path ([IO.Path]::GetFullPath($EvidenceDirectory)) 'doxa-driver-msi.log'
# Shell execution is fixed (msiexec only), no arbitrary supplied commands.
$arguments='/i "'+$package+'" /qn /norestart /L*v "'+$logPath+'"'
$proc=Start-Process -FilePath (Join-Path $env:windir 'System32\msiexec.exe') -ArgumentList $arguments -Wait -PassThru
$exitCode=[int]$proc.ExitCode
if($exitCode -eq 0){
 Result 'msi_installed_verify_health' 'Windows Installer completed. Re-run hardware/monitor health before declaring Doxa ready.'
 return
}
if($exitCode -eq 3010){
 Result 'reboot_required_by_it' 'MSI completed; IT must coordinate reboot; no reboot was started.' 0
 return
}
Result 'msi_error' "Windows Installer returned code $exitCode; see IT deployment log." 34
