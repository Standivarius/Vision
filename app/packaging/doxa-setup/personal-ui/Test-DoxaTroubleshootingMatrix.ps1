param()
# Deterministic Doxa-only troubleshooting acceptance. No remote model,
# driver action, Intune mutation or screen topology operation.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$kb=Join-Path $PSScriptRoot 'Get-DoxaKnowledgeAnswer.ps1'
$client=Join-Path $PSScriptRoot 'Ask-DoxaInstaller.ps1'
$cases=@(
 @{q='My Doxa external screen is black after connecting USB cable';lang='en';want='curated_answer';source='smi-display-unsteady'},
 @{q='Why does Remote Desktop only show one monitor while Doxa has three panels?';lang='en';want='curated_answer';source='doxa-rdp-session'},
 @{q='Why was the Silicon Motion driver install blocked by company policy?';lang='en';want='curated_answer';source='ms-policy-block'},
 @{q='Why does my Doxa USB screen flicker or disappear intermittently?';lang='en';want='curated_answer';source='smi-display-unsteady'},
 @{q='What is a SetupAPI.dev.log driver install error?';lang='en';want='curated_answer';source='ms-setupapi-log'},
 @{q='Can I reinstall a mismatched signed driver package?';lang='en';want='curated_answer';source='doxa-msi-integrity-gate'},
 @{q='Does Doxa support hologram synchronization?';lang='en';want='knowledge_gap';source=''},
 @{q='Explain how to prepare lasagna, Doxa driver';lang='en';want='out_of_scope';source=''},
 @{q='Suggest a dinner recipe after checking my Doxa display';lang='en';want='out_of_scope';source=''},
 @{q='De ce ecranul Doxa nu apare?';lang='ro';want='curated_answer';source=''},
 @{q='Ce vreme este azi, Doxa driver?';lang='ro';want='out_of_scope';source=''}
)
$passed=0
foreach($case in $cases){
 $r=(& $kb -Question $case.q -Language $case.lang|Out-String)|ConvertFrom-Json
 if($r.status -ne $case.want){throw ('Unexpected reply status for '+$case.q+': '+$r.status)}
 if($case.source -and @($r.source_ids) -notcontains $case.source){throw ('Wrong provenance for '+$case.q)}
 if($case.want -eq 'curated_answer' -and (-not $r.answer -or @($r.sources).Count -eq 0)){throw ('Missing source-supported answer for '+$case.q)}
 if($case.want -ne 'curated_answer' -and @($r.source_ids).Count -gt 0){throw ('Out-of-scope/unknown question gained source: '+$case.q)}
 if($r.actions_executed -or $r.network_used){throw 'Offline knowledge executed a network or mutation action'}
 $passed++
}
$consent=(& $client -Question 'Doxa screens are black' |Out-String)|ConvertFrom-Json
if($consent.status -ne 'consent_required' -or $consent.mutating_actions_enabled){throw 'AI consent missing refusal'}
$endpoint=(& $client -Question 'Doxa screens are black' -Endpoint 'https://unapproved.example/v1/ask' -AIConsentGranted|Out-String)|ConvertFrom-Json
if($endpoint.status -ne 'endpoint_not_approved' -or $endpoint.mutating_actions_enabled){throw 'AI endpoint pin failure'}
[ordered]@{
 status='PASS';product='Doxa Setup';offline_cases=$passed
 ai_consent_refusal='PASS';endpoint_pin='PASS'
 language_cases=@('en','ro');all_actions_read_only=$true
 model_requests_made=0;physical_driver_modified=$false
}|ConvertTo-Json -Compress
