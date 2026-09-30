param(
    [Parameter(Mandatory=$true)][string]$RunDir
)
$ErrorActionPreference='Stop'
$RunDir=(Resolve-Path $RunDir).Path
$telemetryPath=Join-Path $RunDir 'visual_telemetry.csv'
if(-not (Test-Path $telemetryPath)){throw "Missing telemetry: $telemetryPath"}

function Percentile([double[]]$Values,[double]$P){
    if(-not $Values -or $Values.Count -eq 0){return $null}
    $xs=@($Values | Sort-Object)
    if($xs.Count -eq 1){return [double]$xs[0]}
    $k=($xs.Count-1)*$P/100.0
    $lo=[math]::Floor($k)
    $hi=[math]::Ceiling($k)
    if($lo -eq $hi){return [double]$xs[$lo]}
    return [double]($xs[$lo]*($hi-$k)+$xs[$hi]*($k-$lo))
}

function StatBlock([double[]]$Values){
    if(-not $Values -or $Values.Count -eq 0){return $null}
    $m=$Values | Measure-Object -Minimum -Maximum -Average
    return [ordered]@{
        count=$Values.Count
        min=[double]$m.Minimum
        p50=Percentile $Values 50
        p90=Percentile $Values 90
        p95=Percentile $Values 95
        p99=Percentile $Values 99
        max=[double]$m.Maximum
        mean=[double]$m.Average
    }
}

$comments=@{}
$eventLines=New-Object System.Collections.Generic.List[string]
$dataLines=New-Object System.Collections.Generic.List[string]
foreach($line in [IO.File]::ReadLines($telemetryPath)){
    if([string]::IsNullOrWhiteSpace($line)){continue}
    if($line.StartsWith('# event=')){$eventLines.Add($line.Substring(2));continue}
    if($line.StartsWith('# ')){
        $body=$line.Substring(2)
        $idx=$body.IndexOf('=')
        if($idx -gt 0){$comments[$body.Substring(0,$idx)]=$body.Substring($idx+1)}
        continue
    }
    $dataLines.Add($line)
}
if($dataLines.Count -lt 2){throw 'No telemetry frame rows found'}
$rows=@($dataLines | ConvertFrom-Csv)
$qpcFreq=[double]$comments['qpc_frequency']
$arrivals=@($rows | ForEach-Object {[double]$_.arrival_qpc})
$interarrival=New-Object System.Collections.Generic.List[double]
for($i=1;$i -lt $arrivals.Count;$i++){
    if($arrivals[$i] -ge $arrivals[$i-1]){
        $interarrival.Add(($arrivals[$i]-$arrivals[$i-1])*1000.0/$qpcFreq)
    }
}

$arrivalDelta=@($rows | ForEach-Object {[double]$_.arrival_minus_frame_timestamp_us/1000.0})
$renderDelta=@($rows | ForEach-Object {[double]$_.render_start_minus_frame_timestamp_us/1000.0})
$presentDuration=@($rows | ForEach-Object {[double]$_.present_call_duration_us/1000.0})
$presentFailures=@($rows | Where-Object {[uint64]$_.present_hr -ne 0}).Count
$gpuCopies=@($rows | Where-Object {$_.gpu_copy -eq '1'}).Count
$durationS=$null
$fps=$null
if($arrivals.Count -ge 2 -and $qpcFreq -gt 0){
    $durationS=($arrivals[-1]-$arrivals[0])/$qpcFreq
    if($durationS -gt 0){$fps=($arrivals.Count-1)/$durationS}
}

$scenario=@()
$scenarioPath=Join-Path $RunDir 'scenario_events.jsonl'
if(Test-Path $scenarioPath){
    $scenario=@([IO.File]::ReadLines($scenarioPath) | Where-Object {$_} | ForEach-Object {$_ | ConvertFrom-Json})
}
$phaseStarts=@($scenario | Where-Object {$_.type -eq 'phase_start'})
$manifest=$null
$manifestPath=Join-Path $RunDir 'manifest.json'
if(Test-Path $manifestPath){$manifest=Get-Content -Raw $manifestPath | ConvertFrom-Json}
$videoPath=Join-Path $RunDir 'video.mp4'
$runId=Split-Path -Leaf $RunDir
if($manifest -and $manifest.run_id){$runId=$manifest.run_id}

$analysis=[ordered]@{
    run_id=$runId
    mode=$comments['mode']
    monitor_count=[int]$comments['monitor_count']
    frames=$rows.Count
    capture_duration_s=$durationS
    effective_capture_fps=$fps
    arrival_minus_frame_timestamp_ms=StatBlock ([double[]]$arrivalDelta)
    render_start_minus_frame_timestamp_ms=StatBlock ([double[]]$renderDelta)
    present_call_duration_ms=StatBlock ([double[]]$presentDuration)
    interarrival_ms=StatBlock ([double[]]$interarrival.ToArray())
    present_failures=$presentFailures
    gpu_copy_frames=$gpuCopies
    gpu_copy_percent=if($rows.Count -gt 0){100.0*$gpuCopies/$rows.Count}else{$null}
    detail_excluded_from_capture=$comments['detail_excluded_from_capture']
    detail_exclusion_error=$comments['detail_exclusion_error']
    telemetry_events=@($eventLines)
    scenario_phase_count=$phaseStarts.Count
    scenario_phases=@($phaseStarts | ForEach-Object {[ordered]@{elapsed_ms=$_.elapsed_ms;detail=$_.detail}})
    video=[ordered]@{exists=(Test-Path $videoPath);bytes=if(Test-Path $videoPath){(Get-Item $videoPath).Length}else{0}}
    timing_note='SystemRelativeTime is a compositor QPC timestamp. Signed deltas are diagnostic only and are not end-to-end latency or frame age.'
}
$analysis | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 (Join-Path $RunDir 'analysis.json')

function F($x){if($null -eq $x){return 'n/a'}else{return ('{0:N2}' -f [double]$x)}}
$ad=$analysis.arrival_minus_frame_timestamp_ms
$pd=$analysis.present_call_duration_ms
$gap=$analysis.interarrival_ms
$summary=New-Object System.Collections.Generic.List[string]
$summary.Add("# Spike 1 automated run summary - $($analysis.run_id)")
$summary.Add('')
$summary.Add("- Mode: $($analysis.mode)")
$summary.Add("- Monitors reported by Visual: $($analysis.monitor_count)")
$summary.Add("- Frames: $($analysis.frames)")
$summary.Add("- Capture duration: $(F $analysis.capture_duration_s) s")
$summary.Add("- Effective capture cadence: $(F $analysis.effective_capture_fps) fps")
$summary.Add("- Arrival minus WGC frame timestamp p50/p95/p99: $(F $ad.p50) / $(F $ad.p95) / $(F $ad.p99) ms (signed diagnostic delta, not latency)")
$summary.Add("- Present call duration p50/p95/p99/max: $(F $pd.p50) / $(F $pd.p95) / $(F $pd.p99) / $(F $pd.max) ms")
$summary.Add("- Inter-arrival p50/p95/max: $(F $gap.p50) / $(F $gap.p95) / $(F $gap.max) ms")
$summary.Add("- Present failures: $($analysis.present_failures)")
$summary.Add("- GPU-copy fallback: $($analysis.gpu_copy_frames) frames ($(F $analysis.gpu_copy_percent) percent)")
$summary.Add("- Detail window excluded from capture: $($analysis.detail_excluded_from_capture) (error $($analysis.detail_exclusion_error))")
$summary.Add("- Scenario phases observed: $($analysis.scenario_phase_count)")
$summary.Add("- Video present: $(if($analysis.video.exists){'yes'}else{'no'})")
$summary.Add('')
$summary.Add('Timing note: Direct3D11CaptureFrame.SystemRelativeTime is retained as a raw compositor QPC timestamp. Signed QPC deltas are diagnostic only; they are not photon latency.')
$summary | Set-Content -Encoding UTF8 (Join-Path $RunDir 'SUMMARY.md')
$summary -join "`n"
