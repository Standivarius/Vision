# Verify first useful troubleshooting answer is local, source-supported, and
# appears in the GUI before optional slow cloud AI starts. No network/model calls.
$ErrorActionPreference='Stop'
$source=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Start-DoxaSetup.ps1') -Raw -Encoding UTF8
$quick=$source.IndexOf("Say (T 'Doxa - quick offline guidance'")
$async=$source.IndexOf('$script:aiJob=Start-Job')
if($quick -lt 0 -or $async -lt 0 -or $quick -gt $async){throw 'Instant local answer no longer precedes remote AI job'}
if(-not $source.Contains('if($script:quickAdviceShown)')){throw 'AI failure lost offline preview awareness'}
$sw=[Diagnostics.Stopwatch]::StartNew()
$kb=(& (Join-Path $PSScriptRoot 'Get-DoxaKnowledgeAnswer.ps1') -Question 'Why is my Doxa USB screen black after connecting the cable?' -Language en|Out-String)|ConvertFrom-Json
$sw.Stop()
if($kb.status -ne 'curated_answer' -or @($kb.source_ids).Count -lt 1 -or -not $kb.answer){throw 'Quick advice missing curated knowledge'}
if($sw.Elapsed.TotalSeconds -gt 12){throw 'Offline first guidance is slower than the generous CI threshold'}
[ordered]@{status='PASS';local_guidance_before_ai=$true;first_answer_seconds=[math]::Round($sw.Elapsed.TotalSeconds,2);sources=@($kb.source_ids);ai_network_calls=0;system_mutations=0}|ConvertTo-Json -Compress
