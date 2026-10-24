param(
 [Parameter(Mandatory=$true)][string]$RunDir,
 [Parameter(Mandatory=$true)][string]$TargetProcessName,
 [int]$TargetProcessId = 0
)
$ErrorActionPreference='Stop'
$telemetry=Join-Path $RunDir 'focus_caret_telemetry.jsonl'
if(-not(Test-Path $telemetry)){throw "Missing telemetry: $telemetry"}
$samples=@(Get-Content $telemetry|Where-Object{$_.Trim()}|ForEach-Object{$_|ConvertFrom-Json})
$rows=if($TargetProcessId-gt0){@($samples|Where-Object{[int]$_.foreground.pid-eq$TargetProcessId})}else{@($samples|Where-Object{[IO.Path]::GetFileNameWithoutExtension([string]$_.foreground.image)-ieq$TargetProcessName})}
function P($n,$d){if($d-le0){0}else{[math]::Round(100*$n/$d,1)}}
$n=$rows.Count
$stats=[ordered]@{
 run_dir=$RunDir;target_process=$TargetProcessName;target_process_id=$TargetProcessId;total_samples=$samples.Count;target_samples=$n;target_coverage_percent=P $n $samples.Count
 win32_focus_percent=P (@($rows|?{$_.win32.focus_hwnd-ne'0x0'}).Count) $n
 win32_caret_percent=P (@($rows|?{$null-ne$_.win32.caret_screen_rect}).Count) $n
 uia_focus_percent=P (@($rows|?{$_.uia.focused-eq$true}).Count) $n
 text2_present_percent=P (@($rows|?{$_.uia.text2_present-eq$true}).Count) $n
 text2_caret_range_percent=P (@($rows|?{$_.uia.caret_range_present-eq$true}).Count) $n
 text2_char_rect_percent=P (@($rows|?{[int]$_.uia.caret_char_context_rect_count-gt0}).Count) $n
 text_present_percent=P (@($rows|?{$_.uia.text_present-eq$true}).Count) $n
 selection_range_percent=P (@($rows|?{$_.uia.selection_range_present-eq$true}).Count) $n
 selection_degenerate_percent=P (@($rows|?{$_.uia.selection_degenerate_known-eq$true-and$_.uia.selection_degenerate-eq$true}).Count) $n
 selection_char_rect_percent=P (@($rows|?{[int]$_.uia.selection_char_context_rect_count-gt0}).Count) $n
 frameworks=@($rows|%{[string]$_.uia.framework}|?{$_}|Sort-Object -Unique)
 control_types=@($rows|%{[int]$_.uia.control_type}|?{$_-ne0}|Sort-Object -Unique)
 focused_names=@($rows|%{[string]$_.uia.name}|?{$_}|Sort-Object -Unique|Select-Object -First 20)
}
$stats|ConvertTo-Json -Depth 6|Set-Content -Encoding UTF8 (Join-Path $RunDir 'analysis.json')
$summary=@(
 "# Spike 3 $TargetProcessName summary",'',
 "- Total probe samples: $($stats.total_samples)",
 "- Target foreground samples: $($stats.target_samples) ($($stats.target_coverage_percent)%)",
 "- Win32 focus: $($stats.win32_focus_percent)%",
 "- Win32 caret: $($stats.win32_caret_percent)%",
 "- UIA focus: $($stats.uia_focus_percent)%",
 "- TextPattern2 interface: $($stats.text2_present_percent)%",
 "- TextPattern2 caret range: $($stats.text2_caret_range_percent)%",
 "- TextPattern2 character context: $($stats.text2_char_rect_percent)%",
 "- TextPattern interface: $($stats.text_present_percent)%",
 "- TextPattern selection/insertion range: $($stats.selection_range_percent)%",
 "- TextPattern degenerate insertion range: $($stats.selection_degenerate_percent)%",
 "- TextPattern character context: $($stats.selection_char_rect_percent)%",
 "- UIA frameworks: $($stats.frameworks -join ', ')",
 "- UIA control types: $($stats.control_types -join ', ')",''
)
$summary+='This is an observed real-application run, not a deterministic provider guarantee. Coverage is specific to the exercised UI state.'
$summary-join"`r`n"|Set-Content -Encoding UTF8 (Join-Path $RunDir 'SUMMARY.md')
Write-Host ($summary-join"`n")
