param(
 [Parameter(Mandatory=$true)][string]$PackagePath
)
# Pure validation: never starts msiexec, pnputil, drivers or an elevated shell.
$ErrorActionPreference='Stop'
$expectedHash='3379B46DA029423748E2D2E64DB2015B50136E310A492E31857CC726719192D4'
$expectedSigner='81956F4C8904963B707B994E42FEA1EDBBFA51C6'
if(-not (Test-Path -LiteralPath $PackagePath -PathType Leaf)){
 [ordered]@{allowed=$false;code='package_missing';reason='No driver package found.'}|ConvertTo-Json
 return
}
$actual=(Get-FileHash -LiteralPath $PackagePath -Algorithm SHA256).Hash
if($actual -ine $expectedHash){
 [ordered]@{allowed=$false;code='package_hash_mismatch';reason='File differs from verified original. Refuse installation.';actual_sha256=$actual}|ConvertTo-Json
 return
}
$sig=Get-AuthenticodeSignature -LiteralPath $PackagePath
if($sig.Status -ne 'Valid' -or -not $sig.SignerCertificate -or $sig.SignerCertificate.Thumbprint -ine $expectedSigner){
 [ordered]@{allowed=$false;code='package_signature_mismatch';reason='Signature or publisher differs from verified original.'}|ConvertTo-Json
 return
}
[ordered]@{allowed=$true;code='verified_source_only';reason='Original MSI hash and signature match; package is still NOT approved for enterprise distribution.';note='Preflight verification is not an installation.'}|ConvertTo-Json
