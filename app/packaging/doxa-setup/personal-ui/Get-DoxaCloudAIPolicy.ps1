param([string]$EvidencePath='')
# Read-only organizational policy. Registry key can only DENY cloud AI.
# End-user consent is ALWAYS a separate requirement, even when policy allows.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$blocked=$false
$source='registry_or_unset'
if($EvidencePath){
 $e=Get-Content -LiteralPath $EvidencePath -Raw -Encoding UTF8|ConvertFrom-Json
 if([string]$e.origin -ne 'fixture'){throw 'Only labelled test fixtures are supported'}
 $source='fixture'
 $blocked=([int]$e.disable_cloud_ai -eq 1)
}else{
 try{
  $reg=Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Standivarius\DoxaSetup' -Name 'DisableCloudAI' -ErrorAction Stop
  $blocked=([int]$reg.DisableCloudAI -eq 1)
 }catch [System.Management.Automation.ItemNotFoundException]{
  $blocked=$false
 }catch{
  # Fail closed if a configured machine policy cannot be read reliably.
  $source='policy_read_error'
  $blocked=$true
 }
}
[ordered]@{
 schema_version=1
 policy_source=$source
 cloud_ai_allowed=(-not $blocked)
 cloud_ai_blocked_by_it=$blocked
 user_permission_still_required=$true
 machine_mutation_performed=$false
 policy_registry_key='HKLM\SOFTWARE\Policies\Standivarius\DoxaSetup\DisableCloudAI'
}|ConvertTo-Json -Compress
