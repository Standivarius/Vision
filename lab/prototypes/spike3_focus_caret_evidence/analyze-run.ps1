param([Parameter(Mandatory=$true)][string]$RunDir)
$ErrorActionPreference='Stop'

$telemetryPath=Join-Path $RunDir 'focus_caret_telemetry.jsonl'
$scenarioPath=Join-Path $RunDir 'scenario_events.jsonl'
$manifestPath=Join-Path $RunDir 'manifest.json'
foreach($p in @($telemetryPath,$scenarioPath,$manifestPath)){if(-not(Test-Path $p)){throw "Missing required file: $p"}}

$samples=@(Get-Content $telemetryPath | Where-Object {$_.Trim()} | ForEach-Object {$_|ConvertFrom-Json})
$events=@(Get-Content $scenarioPath | Where-Object {$_.Trim()} | ForEach-Object {$_|ConvertFrom-Json})
$manifest=Get-Content -Raw $manifestPath|ConvertFrom-Json
if(-not $samples.Count -or -not $events.Count){throw 'Missing samples/events'}
$targetPid=[int]$manifest.stimulus_pid

function Percent([int]$n,[int]$d){if($d-le 0){0.0}else{[math]::Round(100.0*$n/$d,1)}}
function PhaseStats($name,$rows){
  $r=@($rows); $n=$r.Count
  $m=[ordered]@{
    phase=$name; samples=$n
    win32_focus_samples=@($r|?{$_.win32.focus_hwnd-ne'0x0'}).Count
    win32_caret_samples=@($r|?{$null-ne$_.win32.caret_screen_rect}).Count
    uia_focus_samples=@($r|?{$_.uia.focused-eq$true}).Count
    text2_present_samples=@($r|?{$_.uia.text2_present-eq$true}).Count
    text2_caret_range_samples=@($r|?{$_.uia.caret_range_present-eq$true}).Count
    text2_raw_rect_samples=@($r|?{[int]$_.uia.caret_rect_count-gt 0}).Count
    text2_char_rect_samples=@($r|?{[int]$_.uia.caret_char_context_rect_count-gt 0}).Count
    text_present_samples=@($r|?{$_.uia.text_present-eq$true}).Count
    selection_range_samples=@($r|?{$_.uia.selection_range_present-eq$true}).Count
    selection_degenerate_samples=@($r|?{$_.uia.selection_degenerate_known-eq$true -and $_.uia.selection_degenerate-eq$true}).Count
    selection_raw_rect_samples=@($r|?{[int]$_.uia.selection_rect_count-gt 0}).Count
    selection_char_rect_samples=@($r|?{[int]$_.uia.selection_char_context_rect_count-gt 0}).Count
  }
  foreach($k in @('win32_caret','uia_focus','text2_present','text2_caret_range','text2_raw_rect','text2_char_rect','text_present','selection_range','selection_degenerate','selection_raw_rect','selection_char_rect')){
    $key="${k}_samples"; $m["${k}_percent"]=Percent ([int]$m[$key]) $n
  }
  [pscustomobject]$m
}

$targetSamples=@($samples|?{[int]$_.foreground.pid-eq$targetPid})
$targetCoverage=Percent $targetSamples.Count $samples.Count
$phaseStats=@(); $phaseRows=@{}
for($i=0;$i-lt$events.Count;$i++){
  $name=[string]$events[$i].event;if($name-eq'complete'){continue}
  $start=[int64]$events[$i].qpc;$end=if($i+1-lt$events.Count){[int64]$events[$i+1].qpc}else{[int64]::MaxValue}
  $rows=@($targetSamples|?{[int64]$_.qpc-ge$start-and[int64]$_.qpc-lt$end});$phaseRows[$name]=$rows
  $phaseStats+=PhaseStats $name $rows
}
$editNames=@('single_start','single_middle','single_end','multi_start','multi_line1_end','multi_line2','multi_line3','single_return')
$focusNames=@('button_focus','checkbox_focus')
$editRows=@();foreach($n in $editNames){$editRows+=@($phaseRows[$n])}
$focusRows=@();foreach($n in $focusNames){$focusRows+=@($phaseRows[$n])}
$editStats=PhaseStats 'edit_phases' $editRows
$focusStats=PhaseStats 'focus_only_phases' $focusRows

$winVsText2=@();$winVsSelectionChar=@()
foreach($s in $targetSamples){
  if($null-ne$s.win32.caret_screen_rect -and $null-ne$s.uia.caret_rect_first){
    $dx=[double]$s.uia.caret_rect_first.left-[double]$s.win32.caret_screen_rect.left;$dy=[double]$s.uia.caret_rect_first.top-[double]$s.win32.caret_screen_rect.top
    $winVsText2+=[math]::Sqrt($dx*$dx+$dy*$dy)
  }
  if($null-ne$s.win32.caret_screen_rect -and $null-ne$s.uia.selection_char_context_rect_first -and $s.uia.selection_degenerate-eq$true){
    $dx=[double]$s.uia.selection_char_context_rect_first.left-[double]$s.win32.caret_screen_rect.left;$dy=[double]$s.uia.selection_char_context_rect_first.top-[double]$s.win32.caret_screen_rect.top
    $winVsSelectionChar+=[math]::Sqrt($dx*$dx+$dy*$dy)
  }
}
function DistSummary($a){$v=@($a);[ordered]@{samples=$v.Count;mean_px=if($v.Count){[math]::Round((($v|Measure-Object -Average).Average),3)}else{$null};max_px=if($v.Count){[math]::Round((($v|Measure-Object -Maximum).Maximum),3)}else{$null}}}

$analysis=[ordered]@{
  run_dir=$RunDir;target_pid=$targetPid;sample_count=$samples.Count;target_foreground_sample_count=$targetSamples.Count;target_foreground_coverage_percent=$targetCoverage
  edit_phases=$editStats;focus_only_phases=$focusStats;phases=$phaseStats
  win32_vs_text2_raw_caret=DistSummary $winVsText2
  win32_vs_textpattern_character_context=DistSummary $winVsSelectionChar
  uia_frameworks_on_target=@($targetSamples|%{[string]$_.uia.framework}|?{$_}|Sort-Object -Unique)
  uia_control_types_on_target=@($targetSamples|%{[int]$_.uia.control_type}|?{$_-ne 0}|Sort-Object -Unique)
}
$analysis|ConvertTo-Json -Depth 10|Set-Content -Encoding UTF8 (Join-Path $RunDir 'analysis.json')

$summary=@(
'# Spike 3 native baseline summary','',
"- Samples: $($samples.Count)",
"- Stimulus foreground: $($targetSamples.Count) ($targetCoverage%)",
"- Edit Win32 caret: $($editStats.win32_caret_percent)%",
"- Edit UIA focus: $($editStats.uia_focus_percent)%",
"- Edit TextPattern2 interface present: $($editStats.text2_present_percent)%",
"- Edit TextPattern2 caret range present: $($editStats.text2_caret_range_percent)%",
"- Edit TextPattern interface present: $($editStats.text_present_percent)%",
"- Edit TextPattern selection/insertion range present: $($editStats.selection_range_percent)%",
"- Edit TextPattern degenerate insertion range: $($editStats.selection_degenerate_percent)%",
"- Edit TextPattern character-context rectangle: $($editStats.selection_char_rect_percent)%",
"- Focus-only UIA focus: $($focusStats.uia_focus_percent)%",'',
'## Phase matrix','',
'| Phase | N | Win32 caret | UIA focus | Text2 iface | Text2 caret | Text iface | Selection range | Degenerate | Selection char rect |',
'|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|'
)
foreach($p in $phaseStats){$summary+="| $($p.phase) | $($p.samples) | $($p.win32_caret_percent)% | $($p.uia_focus_percent)% | $($p.text2_present_percent)% | $($p.text2_caret_range_percent)% | $($p.text_present_percent)% | $($p.selection_range_percent)% | $($p.selection_degenerate_percent)% | $($p.selection_char_rect_percent)% |"}
$summary+=''
if($targetCoverage-lt90){$summary+='**Harness warning:** stimulus foreground coverage is below 90%; provider percentages use only target-foreground samples.';$summary+=''}
$summary+='This is a deterministic native-control baseline only; real application coverage remains to be measured.'
$summary -join "`r`n"|Set-Content -Encoding UTF8 (Join-Path $RunDir 'SUMMARY.md')
Write-Host ($summary-join"`n")
