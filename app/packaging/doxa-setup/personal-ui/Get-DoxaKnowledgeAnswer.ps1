param(
 [Parameter(Mandatory=$true)][string]$Question,
 [ValidateSet('en','ro')][string]$Language='en'
)
# Offline text guidance from reviewed/curated official-source summaries.
# No network requests, command execution, package changes, or LLM calls.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$pack=Join-Path (Split-Path -Parent $PSScriptRoot) 'knowledge\entries.json'
$kb=Get-Content -LiteralPath $pack -Raw -Encoding UTF8 | ConvertFrom-Json
$scopePath=Join-Path (Split-Path -Parent $PSScriptRoot) 'knowledge\scope-policy.json'
$policy=Get-Content -LiteralPath $scopePath -Raw -Encoding UTF8 | ConvertFrom-Json
$normalized=($Question.Normalize([Text.NormalizationForm]::FormD) -replace '\p{Mn}','').ToLowerInvariant()
$excluded=@($policy.out_of_scope_patterns|Where-Object{[regex]::IsMatch($normalized,[string]$_,[Text.RegularExpressions.RegexOptions]::IgnoreCase)}).Count -gt 0
$supported=@($policy.in_scope_patterns|Where-Object{[regex]::IsMatch($normalized,[string]$_,[Text.RegularExpressions.RegexOptions]::IgnoreCase)}).Count -gt 0
if($excluded -or -not $supported){
 [ordered]@{schema_version=1;status='out_of_scope';answer=[string]$policy.refusals.$Language;source_ids=@();network_used=$false;actions_executed=$false}|ConvertTo-Json -Compress
 return
}
$stops=@('how','what','why','the','can','does','and','for','with','that','doxa','driver','please','help','this','from','have','does','installed','windows','when','is','are','you','your','about','could','should','where','support','supports','supported','problem','problems','issue','issues','question')
$matches=[regex]::Matches($Question.ToLowerInvariant(),'[\p{L}\p{N}]{3,}')
$terms=@($matches|ForEach-Object{$_.Value}|Where-Object {$_ -notin $stops}|Select-Object -Unique)
# Targeted RO -> EN hardware terms for the reviewed English-language source catalog.
$aliases=@(
 @{pattern='^ecran';word='screen'},@{pattern='^monitor';word='monitor'},
 @{pattern='^(lips|dispar|apare|aparut)';word='missing'},
 @{pattern='^negr';word='black'},@{pattern='^conect';word='usb'},
 @{pattern='^cabl';word='cable'},@{pattern='^aliment';word='power'},
 @{pattern='^deconect';word='disconnect'},@{pattern='^rezolut';word='resolution'},
 @{pattern='^semnat';word='signed'},@{pattern='^instal';word='install'},
 @{pattern='^extind';word='extend'}
)
$normalizedTerms=@($terms|ForEach-Object{($_.Normalize([Text.NormalizationForm]::FormD) -replace '\p{Mn}','').ToLowerInvariant()})
foreach($word in @($normalizedTerms)){
 foreach($item in $aliases){
  if($word -match $item.pattern){$normalizedTerms+= [string]$item.word}
 }
}
$terms=@($normalizedTerms|Select-Object -Unique)
$rank=@(
 foreach($item in $kb.entries){
  $score=0
  $tags=@($item.tags|ForEach-Object{([string]$_).ToLowerInvariant()})
  $title=([string]$item.title).ToLowerInvariant()
  $body=(([string]$item.summary)+' '+(@($item.safe_steps) -join ' ')).ToLowerInvariant()
  foreach($term in $terms){
   if(@($tags|Where-Object{$_.Contains($term)}).Count -gt 0){$score+=6}
   if($title.Contains($term)){$score+=3}
   if($body.Contains($term)){$score+=1}
  }
  if($score -ge 3){[pscustomobject]@{score=$score;entry=$item}}
 }
)
$rank=@($rank|Sort-Object score -Descending)
if($rank.Count -eq 0){
 $message=if($Language -eq 'ro'){'Nu am suficiente informatii verificate pentru aceasta intrebare. Pot verifica driverul semnat si panourile detectate fara a modifica Windows.'}else{'The curated installation references do not cover this question. I can check the signed driver and detected panels without changing Windows.'}
 [ordered]@{schema_version=1;status='knowledge_gap';answer=$message;source_ids=@();network_used=$false;actions_executed=$false}|ConvertTo-Json -Compress
 return
}
$top=$rank[0].entry
$nextStep=if(@($top.safe_steps).Count){[string]$top.safe_steps[0]}else{''}
$msg=([string]$top.summary)+' '+$nextStep
if($Language -eq 'ro'){$msg='Din sursele tehnice verificate: '+$msg}
[ordered]@{
 schema_version=1
 status='curated_answer'
 answer=$msg.Trim()
 source_ids=@([string]$top.id)
 sources=@($top.sources|ForEach-Object{[ordered]@{publisher=$_.publisher;url=$_.url;section=$_.section}})
 network_used=$false
 actions_executed=$false
} | ConvertTo-Json -Depth 6 -Compress
