$ErrorActionPreference='Stop'
$policy=Join-Path $PSScriptRoot 'Get-DoxaCloudAIPolicy.ps1'
$path=Join-Path $env:TEMP ('doxa-policy-fixture-'+[Guid]::NewGuid().ToString('N')+'.json')
try {
 @{origin='fixture';disable_cloud_ai=0}|ConvertTo-Json|Set-Content -LiteralPath $path -Encoding UTF8
 $allow=(& $policy -EvidencePath $path|Out-String)|ConvertFrom-Json
 if(-not $allow.cloud_ai_allowed -or -not $allow.user_permission_still_required){throw 'AI grant policy incorrectly bypassed user choice'}
 @{origin='fixture';disable_cloud_ai=1}|ConvertTo-Json|Set-Content -LiteralPath $path -Encoding UTF8
 $deny=(& $policy -EvidencePath $path|Out-String)|ConvertFrom-Json
 if($deny.cloud_ai_allowed -or -not $deny.cloud_ai_blocked_by_it -or $deny.machine_mutation_performed){throw 'Enterprise denial not enforced'}
 $welcome=& (Join-Path $PSScriptRoot 'Start-DoxaGuidedSetup.ps1') -Smoke|Out-String|ConvertFrom-Json
 if(-not $welcome.privacy_details_available -or $welcome.remote_ai_default){throw 'AI privacy notice missing or opt-in default unsafe'}
 'DOXA_AI_POLICY_AND_NOTICE=PASS'
}finally{Remove-Item -LiteralPath $path -ErrorAction SilentlyContinue}
