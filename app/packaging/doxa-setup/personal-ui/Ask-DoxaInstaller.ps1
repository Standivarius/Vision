param(
 [Parameter(Mandatory=$true)][string]$Question,
 [ValidateSet('en','ro')][string]$Language='en',
 [string]$Endpoint='https://doxa-installer-assistant.marius-moldovan.workers.dev/v1/ask',
 [int]$TimeoutSec=35,
 [switch]$AIConsentGranted
)
# Doxa Setup only (not Vision). Dedicated read-only curated-knowledge AI.
# Provider key and curated retrieval live on Doxa's server. Client never executes AI output.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$approved='https://doxa-installer-assistant.marius-moldovan.workers.dev/v1/ask'
function Result([string]$Status,[string]$Answer){
 [ordered]@{schema_version=1;status=$Status;answer=$Answer;mutating_actions_enabled=$false;source='doxa_setup_only'} | ConvertTo-Json -Compress
}
if($Endpoint -cne $approved){Result 'endpoint_not_approved' '';return}
# Fail closed at the network client, not only in the guided setup UI.
# A caller must explicitly confirm the user selected remote AI after seeing the notice.
if(-not $AIConsentGranted){Result 'consent_required' 'Remote AI is off. Open Doxa guided setup, read the AI notice, and explicitly enable remote AI before sending any question.';return}
$policy=(& (Join-Path $PSScriptRoot 'Get-DoxaCloudAIPolicy.ps1') | Out-String)|ConvertFrom-Json
if(-not [bool]$policy.cloud_ai_allowed){Result 'disabled_by_organization' 'Cloud AI was disabled by organizational policy. Local Doxa troubleshooting is still available.';return}
if([string]::IsNullOrWhiteSpace($Question) -or $Question.Length -gt 1800){Result 'invalid_question' '';return}
# Out-of-scope questions are declined locally: no hardware scan, signing or network call.
$localScope=(& (Join-Path $PSScriptRoot 'Get-DoxaKnowledgeAnswer.ps1') -Question $Question -Language $Language|Out-String)|ConvertFrom-Json
if($localScope.status -eq 'out_of_scope'){Result 'out_of_scope' ([string]$localScope.answer);return}
# Signing identity is created automatically at first launch and kept under this Windows user.
# No user-entered API keys or bearer tokens are required.
$obs=(& (Join-Path $PSScriptRoot 'Get-DoxaSetupExperience.ps1') -Fault none | Out-String|ConvertFrom-Json).observed
$ctx=[ordered]@{
 session_kind=[string]$obs.session_kind
 signed_driver_present=[bool]$obs.signed_driver_present
 driver_package_in_store=[bool]$obs.driver_package_in_store
 doxa_hardware_detected=[bool]$obs.doxa_hardware_detected
 driver_version=[string]$obs.driver_version
 pnp_doxa_panel_count=@($obs.pnp_doxa_panels).Count
 physical_display_topology_verified=[bool]$obs.physical_display_topology_verified
 hardware_ready=[bool]$obs.hardware_ready
 windows_build=[int]$obs.windows_build
 app_control_policy='not_checked'
 package_signature_verified=$false
}
$body=[ordered]@{
 schema_version='1'
 intent='ask_doxa_installer'
 ai_notice_version='development-v0.1'
 user_enabled_optional_ai=[bool]$AIConsentGranted
 language=$Language
 question=$Question.Trim()
 context=$ctx
}|ConvertTo-Json -Depth 6
try{
 $signature=(& (Join-Path $PSScriptRoot 'Get-DoxaDeviceSignature.ps1') -SignBody $body | Out-String)|ConvertFrom-Json
 $headers=@{
  'x-doxa-timestamp'=[string]$signature.timestamp
  'x-doxa-signature'=[string]$signature.signature
 }
 $res=Invoke-RestMethod -Method Post -Uri $approved -Headers $headers -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec ([Math]::Max(1,[Math]::Min($TimeoutSec,40)))
 if([string]$res.status -in @('knowledge_gap','out_of_scope') -and [string]$res.answer){Result ([string]$res.status) ([string]$res.answer);return}
 if([string]$res.mode -ne 'read_only_guidance' -or [string]::IsNullOrWhiteSpace([string]$res.answer)){Result 'unsupported_gateway_response' '';return}
 $answer=[string]$res.answer
 Result 'answered' ($answer.Substring(0,[Math]::Min(3000,$answer.Length)))
}catch{
 # Do not write HTTP error bodies, request headers or secrets into setup UI/logs.
 Result 'offline' ''
}
