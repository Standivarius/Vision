param(
  [string]$RunDir = 'C:\dev\Visual\lab\benchmarks\integrated_app\runs\2026-09-22_21-31-05__human_task_session'
)
$ErrorActionPreference='Stop'
$csv=Join-Path $RunDir 'visual_app_telemetry.csv'
$raw=@(Import-Csv $csv)
$rows=@()
foreach($r in $raw){
  $frame=0L;$qpc=0L
  if(-not [int64]::TryParse([string]$r.frame,[ref]$frame)){continue}
  if(-not [int64]::TryParse([string]$r.qpc,[ref]$qpc)){continue}
  if($qpc-le0){continue}
  $r.frame=$frame;$r.qpc=$qpc;$r.poi_source=[int]$r.poi_source;$r.viewport_action=[int]$r.viewport_action;$r.present_hr=[uint64]$r.present_hr
  $r.view_left=[double]$r.view_left;$r.view_top=[double]$r.view_top;$r.view_right=[double]$r.view_right;$r.view_bottom=[double]$r.view_bottom
  $rows+=$r
}
if($rows.Count-lt2){throw 'Not enough valid telemetry rows'}
$freq=[double][Diagnostics.Stopwatch]::Frequency
$end=[int64]$rows[-1].qpc;$cut=$end-[int64](300*$freq)
$recent=@($rows|Where-Object{[int64]$_.qpc-ge$cut-and[int64]$_.qpc-le$end})
function Stats([double[]]$vals){
 if(-not$vals-or$vals.Count-eq0){return [ordered]@{n=0;min_ms=$null;median_ms=$null;p95_ms=$null;max_ms=$null}}
 $s=@($vals|Sort-Object);$n=$s.Count;$median=if($n%2){$s[[int]($n/2)]}else{($s[$n/2-1]+$s[$n/2])/2};$p95=$s[[Math]::Min($n-1,[Math]::Floor(($n-1)*.95))]
 [ordered]@{n=$n;min_ms=[Math]::Round($s[0],3);median_ms=[Math]::Round($median,3);p95_ms=[Math]::Round($p95,3);max_ms=[Math]::Round($s[-1],3)}
}
$gaps=New-Object Collections.Generic.List[double];$longGaps=@()
for($i=1;$i-lt$recent.Count;$i++){
 $ms=1000.0*([int64]$recent[$i].qpc-[int64]$recent[$i-1].qpc)/$freq
 if($ms-lt0){continue};$gaps.Add($ms)
 if($ms-ge100){$longGaps+=[pscustomobject]@{from_frame=$recent[$i-1].frame;to_frame=$recent[$i].frame;gap_ms=[Math]::Round($ms,3);source_before=$recent[$i-1].poi_source;source_after=$recent[$i].poi_source}}
}
$trans=@();$pointerRuns=@();$handoffPaths=@();$i=0
while($i-lt$recent.Count){
 if([int]$recent[$i].poi_source-eq5){
  $start=$i;$j=$i;while($j+1-lt$recent.Count-and[int]$recent[$j+1].poi_source-eq5){$j++}
  $dur=1000.0*([int64]$recent[$j].qpc-[int64]$recent[$start].qpc)/$freq
  $pointerRuns+=[pscustomobject]@{start_frame=$recent[$start].frame;end_frame=$recent[$j].frame;duration_ms=[Math]::Round($dur,3);frames=$j-$start+1;last_action=$recent[$j].viewport_action}
  $next=$j+1
  if($next-lt$recent.Count){
   $firstNextSource=[int]$recent[$next].poi_source;$firstNextMs=1000.0*([int64]$recent[$next].qpc-[int64]$recent[$j].qpc)/$freq
   $k=$next;$counts=@{}
   while($k-lt$recent.Count-and[int]$recent[$k].poi_source-notin@(0,1,2)){$s=[string]$recent[$k].poi_source;if(-not$counts.ContainsKey($s)){$counts[$s]=0};$counts[$s]++;$k++}
   if($k-lt$recent.Count){$ms=1000.0*([int64]$recent[$k].qpc-[int64]$recent[$j].qpc)/$freq;$trans+=[pscustomobject]@{last_pointer_frame=$recent[$j].frame;caret_frame=$recent[$k].frame;handoff_ms=[Math]::Round($ms,3);caret_source=$recent[$k].poi_source;intervening_frames=$k-$j-1};$handoffPaths+=[pscustomobject]@{last_pointer_frame=$recent[$j].frame;first_after_pointer_source=$firstNextSource;first_after_pointer_ms=[Math]::Round($firstNextMs,3);caret_frame=$recent[$k].frame;caret_handoff_ms=[Math]::Round($ms,3);intervening_source_counts=$counts}}
  }
  $i=$j+1
 }else{$i++}
}
$pointerMoveDeltas=New-Object Collections.Generic.List[double]
for($i=1;$i-lt$recent.Count;$i++){if([int]$recent[$i].poi_source-eq5){$dx=[double]$recent[$i].view_left-[double]$recent[$i-1].view_left;$dy=[double]$recent[$i].view_top-[double]$recent[$i-1].view_top;$pointerMoveDeltas.Add([Math]::Sqrt($dx*$dx+$dy*$dy))}}
$handoffVals=@($trans|%{[double]$_.handoff_ms});$runDurVals=@($pointerRuns|%{[double]$_.duration_ms});$sourceCounts=@{};foreach($r in $recent){$k=[string]$r.poi_source;if(-not$sourceCounts.ContainsKey($k)){$sourceCounts[$k]=0};$sourceCounts[$k]++}
$out=[ordered]@{qpc_frequency=$freq;valid_rows=$rows.Count;recent_rows=$recent.Count;recent_span_seconds=[Math]::Round((([int64]$recent[-1].qpc-[int64]$recent[0].qpc)/$freq),3);cadence_ms=Stats $gaps.ToArray();gaps_over_100ms_count=$longGaps.Count;longest_gaps=@($longGaps|Sort-Object gap_ms -Descending|Select-Object -First 12);present_failures_recent=@($recent|?{[uint64]$_.present_hr-ne0}).Count;source_counts=$sourceCounts;pointer_run_duration_ms=Stats ([double[]]$runDurVals);pointer_to_caret_handoff_ms=Stats ([double[]]$handoffVals);slow_handoffs=@($handoffPaths|?{$_.caret_handoff_ms-ge250}|Sort-Object caret_handoff_ms -Descending|Select-Object -First 20);longest_pointer_runs=@($pointerRuns|Sort-Object duration_ms -Descending|Select-Object -First 12);pointer_viewport_delta_px=Stats $pointerMoveDeltas.ToArray()}
$out|ConvertTo-Json -Depth 8|Set-Content -Encoding UTF8 (Join-Path $RunDir 'LIVE_ANALYSIS.json')
$out|ConvertTo-Json -Depth 8
