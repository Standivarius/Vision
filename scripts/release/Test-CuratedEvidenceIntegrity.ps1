[CmdletBinding()]
param([string]$Manifest = '')
# Verify curated evidence only; no network, test application, driver or file mutation.
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if(-not $Manifest){$Manifest=Join-Path $repo 'docs\project\programme\2026-11-06__doxa_vision_curated_evidence_manifest_v1.0.json'}
if(-not(Test-Path $Manifest -PathType Leaf)){throw 'Evidence manifest missing'}
$entry=Get-Content $Manifest -Raw|ConvertFrom-Json
if($entry.schema_version -ne 1 -or @($entry.records).Count -ne 9){throw 'Unexpected curated manifest schema or record count'}
$checked=0
foreach($record in @($entry.records)){
 $rel=[string]$record.path
 if([IO.Path]::IsPathRooted($rel) -or $rel -match '(^|[\\/])\.\.([\\/]|$)') {throw 'Unsafe evidence path'}
 $absolute=Join-Path $repo $rel
 if(-not(Test-Path $absolute -PathType Leaf)){throw ('Missing curated report: '+$rel)}
 $f=Get-Item -LiteralPath $absolute
 if($f.Length -ne [long]$record.bytes){throw ('Evidence length mismatch: '+$rel)}
 if((Get-FileHash $absolute -Algorithm SHA256).Hash -ine [string]$record.sha256){throw ('Evidence digest mismatch: '+$rel)}
 $checked++
}
[ordered]@{status='PASS';verified_records=$checked;source='MARIUS-DELL originals';raw_captures_embedded=$false;network_calls=0;file_mutations=0}|ConvertTo-Json -Compress