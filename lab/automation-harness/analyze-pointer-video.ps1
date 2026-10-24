param(
    [string]$RunFolder = 'C:\dev\Visual\lab\benchmarks\visual_regression\runs\2026-09-24_08-03-26__pointer_visibility',
    [int]$AnalysisFps = 8,
    [double]$VideoStartSec = 4.0,
    [double]$VideoDurationSec = 15.0
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest

$video=Join-Path $RunFolder 'desktop.mp4'
$telemetryPath=Join-Path $RunFolder 'visual_telemetry.csv'
$eventsPath=Join-Path $RunFolder 'test_events.csv'
$outJson=Join-Path $RunFolder 'pixel_analysis.json'
$outReport=Join-Path $RunFolder 'PIXEL_REPORT.md'
$outCsv=Join-Path $RunFolder 'pixel_frame_scores.csv'
if(-not(Test-Path $video)){throw "Missing video: $video"}

$ffmpegCmd=Get-Command ffmpeg.exe -ErrorAction SilentlyContinue
$ffmpeg=if($ffmpegCmd){$ffmpegCmd.Source}else{$null}
if(-not $ffmpeg){
    $ffmpeg=Get-ChildItem 'C:\dev\Visual\lab\automation-harness' -Filter ffmpeg.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
}
if(-not $ffmpeg){throw 'ffmpeg.exe not found'}

$events=@(Import-Csv $eventsPath)
$ffEvent=$events|Where-Object{$_.event-eq'ffmpeg_started'}|Select-Object -First 1
if(-not $ffEvent){throw 'ffmpeg_started event missing'}
$baseQpc=[int64](($ffEvent.detail -split 'qpc=')[1])
$qpcFreq=10000000.0

$raw=@(Get-Content $telemetryPath|Where-Object{$_ -and -not $_.StartsWith('#')})
$telemetry=@($raw|ConvertFrom-Csv)
$qpcs=[int64[]]@($telemetry|ForEach-Object{[int64]$_.qpc})

function Nearest-Index([int64]$q){
    $lo=0;$hi=$qpcs.Length-1
    while($lo -lt $hi){
        $mid=[int](($lo+$hi)/2)
        if($qpcs[$mid] -lt $q){$lo=$mid+1}else{$hi=$mid}
    }
    if($lo -gt 0 -and [math]::Abs([double]($qpcs[$lo-1]-$q)) -lt [math]::Abs([double]($qpcs[$lo]-$q))){return $lo-1}
    return $lo
}

$destLeft=1920;$destTop=0;$destWidth=1920;$destHeight=1080
$frameBytes=$destWidth*$destHeight

function Expected-Center($row){
    if([int]$row.poi_source -ne 5 -or [int]$row.locator_visible -ne 1){return $null}
    $vl=[double]$row.view_left;$vt=[double]$row.view_top;$vr=[double]$row.view_right;$vb=[double]$row.view_bottom
    if($vr-le$vl -or $vb-le$vt){return $null}
    $sx=0.5*([double]$row.selected_left+[double]$row.selected_right)
    $sy=0.5*([double]$row.selected_top+[double]$row.selected_bottom)
    $x=($sx-$vl)/($vr-$vl)*$destWidth
    $y=($sy-$vt)/($vb-$vt)*$destHeight
    if($x-lt25 -or $x-ge($destWidth-25) -or $y-lt25 -or $y-ge($destHeight-25)){return $null}
    return @([int][math]::Round($x),[int][math]::Round($y))
}

function Cross-Score([byte[]]$f,[int]$cx,[int]$cy){
    if($cx-lt22-or$cx-ge($destWidth-22)-or$cy-lt22-or$cy-ge($destHeight-22)){return -999.0}
    [double]$white=0;[double]$black=0;[int]$nw=0;[int]$nb=0
    foreach($d in 6..19){
        foreach($s in @(-1,0,1)){
            $white += $f[$cy*$destWidth+($cx+$d)];$nw++
            $white += $f[$cy*$destWidth+($cx-$d)];$nw++
            $white += $f[($cy+$d)*$destWidth+($cx+$s)];$nw++
            $white += $f[($cy-$d)*$destWidth+($cx+$s)];$nw++
        }
    }
    foreach($d in 6..19){
        foreach($s in @(-3,3)){
            $black += $f[($cy+$s)*$destWidth+($cx+$d)];$nb++
            $black += $f[($cy+$s)*$destWidth+($cx-$d)];$nb++
            $black += $f[($cy+$d)*$destWidth+($cx+$s)];$nb++
            $black += $f[($cy-$d)*$destWidth+($cx+$s)];$nb++
        }
    }
    return ($white/[double]$nw)-($black/[double]$nb)
}

function Read-Exact($stream,[byte[]]$buffer){
    $off=0
    while($off-lt$buffer.Length){
        $n=$stream.Read($buffer,$off,$buffer.Length-$off)
        if($n-le0){return $false}
        $off+=$n
    }
    return $true
}

function Quote-Arg([string]$s){
    return '"' + ($s -replace '"','\"') + '"'
}

$filter="crop=$destWidth`:$destHeight`:$destLeft`:$destTop,fps=$AnalysisFps,format=gray"
$ffArgs=@('-hide_banner','-loglevel','error','-ss',$VideoStartSec.ToString([Globalization.CultureInfo]::InvariantCulture),'-t',$VideoDurationSec.ToString([Globalization.CultureInfo]::InvariantCulture),'-i',$video,'-vf',$filter,'-f','rawvideo','-pix_fmt','gray','pipe:1')
$ffArgLine=($ffArgs|ForEach-Object{Quote-Arg ([string]$_)}) -join ' '

function New-FfmpegProcess {
    $psi=New-Object Diagnostics.ProcessStartInfo
    $psi.FileName=$ffmpeg
    $psi.Arguments=$ffArgLine
    $psi.UseShellExecute=$false
    $psi.RedirectStandardOutput=$true
    $psi.RedirectStandardError=$true
    $psi.CreateNoWindow=$true
    $proc=New-Object Diagnostics.Process
    $proc.StartInfo=$psi
    [void]$proc.Start()
    return $proc
}

$offsets=@();for($o=0.40;$o-le1.80;$o+=0.025){$offsets += [math]::Round($o,3)}
$cal=@{}
foreach($o in $offsets){$cal[[string]$o]=[pscustomobject]@{sum=0.0;n=0}}

$p=New-FfmpegProcess
$stream=$p.StandardOutput.BaseStream
$buf=New-Object byte[] $frameBytes
$idx=0
while(Read-Exact $stream $buf){
    $videoTime=$VideoStartSec+($idx/[double]$AnalysisFps)
    foreach($o in $offsets){
        $q=[int64][math]::Round($baseQpc+($videoTime+$o)*$qpcFreq)
        $ti=Nearest-Index $q
        $row=$telemetry[$ti]
        $phaseFast=([int64]$row.qpc -ge 13112636396927 -and [int64]$row.qpc -le 13112724901578)
        if(-not$phaseFast){continue}
        $c=Expected-Center $row
        if($null-eq$c){continue}
        $s=Cross-Score $buf $c[0] $c[1]
        $obj=$cal[[string]$o];$obj.sum+=$s;$obj.n++
    }
    $idx++
}
$p.WaitForExit()
$stderr=$p.StandardError.ReadToEnd()
if($p.ExitCode-ne0){throw "ffmpeg calibration decode failed ($($p.ExitCode)): $stderr"}

$ranked=@($offsets|ForEach-Object{$x=$cal[[string]$_];[pscustomobject]@{offset_sec=$_;n=$x.n;avg_score=if($x.n){$x.sum/$x.n}else{-999}}}|Sort-Object avg_score -Descending)
$best=$ranked[0]
$bestOffset=[double]$best.offset_sec

$p2=New-FfmpegProcess
$stream2=$p2.StandardOutput.BaseStream
$buf2=New-Object byte[] $frameBytes
$rows=New-Object System.Collections.Generic.List[object]
$idx=0
while(Read-Exact $stream2 $buf2){
    $videoTime=$VideoStartSec+($idx/[double]$AnalysisFps)
    $q=[int64][math]::Round($baseQpc+($videoTime+$bestOffset)*$qpcFreq)
    $ti=Nearest-Index $q;$row=$telemetry[$ti]
    $c=Expected-Center $row
    if($null-ne$c){
        $bestScore=-999.0;$bestDx=0;$bestDy=0
        foreach($dx in @(-12,-8,-4,0,4,8,12)){
            foreach($dy in @(-8,-4,0,4,8)){
                $s=Cross-Score $buf2 ($c[0]+$dx) ($c[1]+$dy)
                if($s-gt$bestScore){$bestScore=$s;$bestDx=$dx;$bestDy=$dy}
            }
        }
        $rows.Add([pscustomobject]@{frame=$idx;video_time_sec=[math]::Round($videoTime,3);qpc=$q;telemetry_frame=[int64]$row.frame;poi_source=[int]$row.poi_source;locator_visible=[int]$row.locator_visible;pointer_age_ms=[double]$row.pointer_age_ms;expected_x=$c[0];expected_y=$c[1];score=[math]::Round($bestScore,2);dx=$bestDx;dy=$bestDy})
    }
    $idx++
}
$p2.WaitForExit();$stderr2=$p2.StandardError.ReadToEnd()
if($p2.ExitCode-ne0){throw "ffmpeg scoring decode failed ($($p2.ExitCode)): $stderr2"}

$rows|Export-Csv -NoTypeInformation -Encoding UTF8 $outCsv
$pointerRows=@($rows|Where-Object{$_.poi_source-eq5-and$_.locator_visible-eq1})
$scores=@($pointerRows|ForEach-Object{[double]$_.score}|Sort-Object)
if(-not$scores.Count){throw 'No pointer-locator video samples were scored'}
$median=$scores[[int][math]::Floor(($scores.Count-1)*0.5)]
$p20=$scores[[int][math]::Floor(($scores.Count-1)*0.2)]
$threshold=[math]::Max(25.0,[math]::Min(80.0,$median*0.45))
foreach($r in $pointerRows){$r|Add-Member -NotePropertyName present -NotePropertyValue ([double]$r.score-ge$threshold)}

$missing=@($pointerRows|Where-Object{-not$_.present})
$longest=0;$cur=0;$longestEnd=-1
for($i=0;$i-lt$pointerRows.Count;$i++){
    if(-not$pointerRows[$i].present){$cur++;if($cur-gt$longest){$longest=$cur;$longestEnd=$i}}else{$cur=0}
}
$longestMs=if($longest){1000.0*$longest/$AnalysisFps}else{0.0}
$longestStart=if($longest){$pointerRows[$longestEnd-$longest+1].video_time_sec}else{$null}
$longestStop=if($longest){$pointerRows[$longestEnd].video_time_sec}else{$null}

$result=[ordered]@{
    analysis_fps=$AnalysisFps
    analyzed_video_start_sec=$VideoStartSec
    analyzed_video_duration_sec=$VideoDurationSec
    ffmpeg_launch_qpc=$baseQpc
    best_video_qpc_offset_sec=$bestOffset
    calibration_best_avg_score=[math]::Round([double]$best.avg_score,2)
    calibration_top5=@($ranked|Select-Object -First 5)
    pointer_samples=$pointerRows.Count
    median_crosshair_score=[math]::Round([double]$median,2)
    p20_crosshair_score=[math]::Round([double]$p20,2)
    presence_threshold=[math]::Round([double]$threshold,2)
    missing_samples=$missing.Count
    missing_fraction=if($pointerRows.Count){$missing.Count/[double]$pointerRows.Count}else{0}
    longest_consecutive_missing_samples=$longest
    longest_missing_ms=[math]::Round($longestMs,1)
    longest_missing_video_start_sec=$longestStart
    longest_missing_video_stop_sec=$longestStop
    lowest_scores=@($pointerRows|Sort-Object score|Select-Object -First 12)
}
$result|ConvertTo-Json -Depth 6|Set-Content -Encoding UTF8 $outJson

@"
# Pixel-level pointer locator analysis

This analysis decodes the recorded Detail monitor and checks the actual black/white pointer-crosshair pixel signature at the position predicted by Visual telemetry.

- Analysis sampling: $AnalysisFps fps
- Best video/QPC alignment offset: $bestOffset s
- Calibration average score: $([math]::Round([double]$best.avg_score,2))
- Pointer-locator samples: $($pointerRows.Count)
- Median crosshair score: $([math]::Round([double]$median,2))
- Presence threshold: $([math]::Round([double]$threshold,2))
- Samples below threshold: $($missing.Count)
- Longest consecutive below-threshold interval: $([math]::Round($longestMs,1)) ms

A score compares the white inner cross pixels with the black outer cross pixels defined by Visual's pixel shader. A long interval below threshold while telemetry reports `poi_source=5` and `locator_visible=1` is evidence of a presentation/rendering discrepancy. Short isolated misses can be caused by video/telemetry alignment, H.264 compression, or rapid locator motion between the ~60 Hz Visual render loop and this lower-rate video analysis.

See `pixel_frame_scores.csv` and `pixel_analysis.json` for the raw correlated results.
"@|Set-Content -Encoding UTF8 $outReport

Write-Host "PIXEL_ANALYSIS=$outJson"
Get-Content $outJson
