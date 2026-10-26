$ErrorActionPreference='Stop'
$client=Join-Path $PSScriptRoot 'Ask-DoxaInstaller.ps1'
$localKb=Join-Path $PSScriptRoot 'Get-DoxaKnowledgeAnswer.ps1'
$identity=Join-Path $PSScriptRoot 'Get-DoxaDeviceSignature.ps1'
$wrong=(& $client -Question 'Why one screen?' -Endpoint 'https://unapproved.example/v1/ask'|Out-String)|ConvertFrom-Json
if($wrong.status -ne 'endpoint_not_approved'){throw 'Unapproved endpoint accepted'}
$noConsent=(& $client -Question 'Why RDP shows one monitor?'|Out-String)|ConvertFrom-Json
if($noConsent.status -ne 'consent_required'){throw 'Direct AI client accepted a question without explicit consent'}
# Explicitly create an ephemeral test identity inside an isolated per-run profile.
$priorAppData=$env:LOCALAPPDATA
$testAppData=Join-Path ([IO.Path]::GetTempPath()) ('doxa-test-signing-'+[Guid]::NewGuid().ToString('N'))
try {
 New-Item -ItemType Directory -Force -Path $testAppData|Out-Null
 $env:LOCALAPPDATA=$testAppData
 $identityResult=(& $identity -PrepareEnrollment|Out-String)|ConvertFrom-Json
 if($identityResult.private_key_protection -ne 'Windows DPAPI CurrentUser' -or -not $identityResult.client_id -or $identityResult.approved_by_server){throw 'Isolated device enrollment preparation failed'}

function Invoke-RestMethod{
 param([string]$Method,[string]$Uri,$Headers,[string]$ContentType,$Body,[int]$TimeoutSec)
 if($Uri -ne 'https://doxa-installer-assistant.marius-moldovan.workers.dev/v1/ask'){throw 'Doxa must not route through Vision'}
 if(-not $Headers['x-doxa-signature'] -or -not $Headers['x-doxa-timestamp'] -or -not $Headers['x-doxa-client-id']){throw 'Missing signed per-device authentication'}
 if($Headers.ContainsKey('Authorization')){throw 'Bearer token is forbidden in Doxa alpha'}
 $payload=[Text.Encoding]::UTF8.GetString($Body)|ConvertFrom-Json
 if($payload.intent -ne 'ask_doxa_installer'){throw 'Unexpected intent'}
 if($payload.ai_notice_version -ne 'development-v0.1' -or $payload.user_enabled_optional_ai -ne $true){throw 'Remote request lacks current AI acknowledgement'}
 if($payload.context.PSObject.Properties.Name -contains 'raw_usb_id'){throw 'Raw identifier leaked'}
 if($payload.context.app_control_policy -ne 'not_checked'){throw 'Policy assertion not observed'}
 return [pscustomobject]@{status='answered';mode='read_only_guidance';answer='Signed Doxa driver and all three physical panels detected.'}
}
$mock=(& $client -Question 'Why RDP shows one monitor?' -AIConsentGranted|Out-String)|ConvertFrom-Json
if($mock.status -ne 'answered'){throw 'Mock signed request failed'}
$power=(& $localKb -Question 'power cable causes display unstable drops'|Out-String)|ConvertFrom-Json
if($power.status -ne 'curated_answer' -or $power.source_ids[0] -ne 'smi-display-unsteady'){throw 'Curated cable troubleshooting failed'}
$unrelated=@('watermelon xylophone noninstaller','What is the weather today?','Write a poem about Doxa driver','How do I install Python on Windows?','Explain how to prepare lasagna, Doxa driver')
foreach($question in $unrelated){
 $unknown=(& $localKb -Question $question|Out-String)|ConvertFrom-Json
 if($unknown.status -ne 'out_of_scope'){throw ('Unrelated question was not refused: '+$question)}
 $clientRefusal=(& $client -Question $question -AIConsentGranted|Out-String)|ConvertFrom-Json
 if($clientRefusal.status -ne 'out_of_scope'){throw ('Client should refuse locally: '+$question)}
}
$romanian=(& $localKb -Question 'Ce vreme este azi?' -Language ro|Out-String)|ConvertFrom-Json
if($romanian.status -ne 'out_of_scope' -or -not $romanian.answer.Contains('instalarea')){throw 'Romanian scope refusal failed'}
$romanianDisplay=(& $localKb -Question 'De ce ecranul Doxa nu apare?' -Language ro|Out-String)|ConvertFrom-Json
if($romanianDisplay.status -ne 'curated_answer'){throw 'Romanian Doxa screen troubleshooting must remain supported'}
}finally{
 $env:LOCALAPPDATA=$priorAppData
 Remove-Item -LiteralPath $testAppData -Recurse -Force -ErrorAction SilentlyContinue
}
'DOXA_SIGNED_CLIENT_AND_CURATED_TESTS=PASS'
'MANUAL_SECRETS_REQUIRED=False'
'VISION_ASSISTANT_DEPENDENCY=False'
