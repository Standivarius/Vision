param(
    [int]$VideoFps = 30,
    [int]$Zoom = 2,
    [switch]$SkipFfmpegDownload
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repo = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$visualExe = Join-Path $repo 'app\build\Release\visual_app.exe'
if (-not (Test-Path $visualExe)) { throw "Visual Release executable not found: $visualExe" }

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class VisualRegressionNative {
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }
    [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr value);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
    [DllImport("kernel32.dll")] public static extern bool QueryPerformanceCounter(out long v);
    [DllImport("kernel32.dll")] public static extern bool QueryPerformanceFrequency(out long v);
}
'@
try { [void][VisualRegressionNative]::SetProcessDpiAwarenessContext([IntPtr](-4)) } catch {}
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Get-Qpc { $v = [long]0; [void][VisualRegressionNative]::QueryPerformanceCounter([ref]$v); return $v }
$qpcFreq = [long]0; [void][VisualRegressionNative]::QueryPerformanceFrequency([ref]$qpcFreq)

$stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$runRoot = Join-Path $repo "lab\benchmarks\visual_regression\runs\${stamp}__pointer_visibility"
New-Item -ItemType Directory -Force -Path $runRoot | Out-Null
$telemetryPath = Join-Path $runRoot 'visual_telemetry.csv'
$groundPath = Join-Path $runRoot 'cursor_ground_truth.csv'
$eventsPath = Join-Path $runRoot 'test_events.csv'
$videoPath = Join-Path $runRoot 'desktop.mp4'
$analysisPath = Join-Path $runRoot 'analysis.json'
$reportPath = Join-Path $runRoot 'REPORT.md'
$fixturePath = Join-Path $runRoot 'notepad_fixture.txt'

$versionInfo = (Get-Item $visualExe).VersionInfo
$visualVersion = if ($versionInfo.ProductVersion) { $versionInfo.ProductVersion } elseif ($versionInfo.FileVersion) { $versionInfo.FileVersion } else { 'unknown' }

# PMv2 awareness is established before any Screen/SystemInformation query above this point.
$virtual = [System.Windows.Forms.SystemInformation]::VirtualScreen
$primary = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$screens = @([System.Windows.Forms.Screen]::AllScreens)
if ($screens.Count -lt 2) { throw 'Two active displays are required for this regression test.' }
$dest = $screens | Where-Object { -not $_.Primary } | Select-Object -First 1

# Portable ffmpeg stays inside the lab harness; no machine-wide installation.
$ffmpeg = (Get-Command ffmpeg.exe -ErrorAction SilentlyContinue).Source
if (-not $ffmpeg) {
    $ffmpegRoot = Join-Path $PSScriptRoot 'tools\ffmpeg'
    $ffmpeg = Get-ChildItem $ffmpegRoot -Filter ffmpeg.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
    if (-not $ffmpeg -and -not $SkipFfmpegDownload) {
        $zip = Join-Path $PSScriptRoot 'tools\ffmpeg-release-essentials.zip'
        New-Item -ItemType Directory -Force -Path (Split-Path $zip -Parent) | Out-Null
        Invoke-WebRequest -Uri 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' -OutFile $zip
        if (Test-Path $ffmpegRoot) { Remove-Item -Recurse -Force $ffmpegRoot }
        New-Item -ItemType Directory -Force -Path $ffmpegRoot | Out-Null
        Expand-Archive -Path $zip -DestinationPath $ffmpegRoot -Force
        Remove-Item $zip -Force
        $ffmpeg = Get-ChildItem $ffmpegRoot -Filter ffmpeg.exe -Recurse | Select-Object -First 1 -ExpandProperty FullName
    }
}
if (-not $ffmpeg) { throw 'ffmpeg was not found and portable download was unavailable.' }
$ffprobe = Join-Path (Split-Path $ffmpeg -Parent) 'ffprobe.exe'

"qpc,event,detail" | Set-Content -Encoding ascii $eventsPath
"qpc,phase,step,expected_x,expected_y,observed_x,observed_y" | Set-Content -Encoding ascii $groundPath
function Event([string]$name, [string]$detail='') {
    $safe = $detail.Replace(',', ';')
    "$(Get-Qpc),$name,$safe" | Add-Content -Encoding ascii $eventsPath
}
function TelemetryFrameCount([string]$path) {
    if (-not (Test-Path $path)) { return 0 }
    return @(Get-Content $path -ErrorAction SilentlyContinue | Where-Object { $_ -match '^\d+,' }).Count
}
function TelemetrySuccessfulFrameCount([string]$path) {
    if (-not (Test-Path $path)) { return 0 }
    $count = 0
    foreach($line in @(Get-Content $path -ErrorAction SilentlyContinue | Where-Object { $_ -match '^\d+,' })) {
        $parts = $line.Split(',')
        if ($parts.Count -le 12) { continue }
        try { $hr = [uint64]$parts[12] } catch { continue }
        if ($hr -lt 2147483648) { $count++ }
    }
    return $count
}
function HasFirstRenderEvent([string]$path) {
    if (-not (Test-Path $path)) { return $false }
    return @((Get-Content $path -ErrorAction SilentlyContinue) | Where-Object { $_ -eq '# event=first_render_frame' }).Count -gt 0
}
function Wait-VisualTelemetryReady([System.Diagnostics.Process]$process, [string]$path, [int]$timeoutMs=12000) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $timeoutMs) {
        $process.Refresh()
        if ($process.HasExited) {
            Event 'visual_exited_early' "exit_code=$($process.ExitCode);elapsed_ms=$($sw.ElapsedMilliseconds)"
            throw "Visual exited before telemetry became ready (exit code $($process.ExitCode))."
        }
        $successCount = TelemetrySuccessfulFrameCount $path
        if ((HasFirstRenderEvent $path) -and $successCount -gt 0) {
            Event 'telemetry_ready' "successful_frames=$successCount;elapsed_ms=$($sw.ElapsedMilliseconds)"
            return
        }
        Start-Sleep -Milliseconds 100
    }
    $process.Refresh()
    $detail = "elapsed_ms=$($sw.ElapsedMilliseconds);frames=$(TelemetryFrameCount $path);successful_frames=$(TelemetrySuccessfulFrameCount $path);first_render_event=$(HasFirstRenderEvent $path);has_exited=$($process.HasExited)"
    if ($process.HasExited) { $detail += ";exit_code=$($process.ExitCode)" }
    Event 'telemetry_timeout' $detail
    throw "Visual telemetry did not produce a successful rendered frame within $timeoutMs ms."
}
function Request-VisualExit([System.Diagnostics.Process]$process) {
    if (-not $process) { return }
    $process.Refresh()
    if ($process.HasExited) { Event 'visual_already_exited' "exit_code=$($process.ExitCode)"; return }
    Event 'visual_graceful_exit_requested' 'hotkey=Ctrl+Alt+Q'
    [VisualRegressionNative]::keybd_event(0x11,0,0,[UIntPtr]::Zero)
    [VisualRegressionNative]::keybd_event(0x12,0,0,[UIntPtr]::Zero)
    [VisualRegressionNative]::keybd_event(0x51,0,0,[UIntPtr]::Zero)
    [VisualRegressionNative]::keybd_event(0x51,0,2,[UIntPtr]::Zero)
    [VisualRegressionNative]::keybd_event(0x12,0,2,[UIntPtr]::Zero)
    [VisualRegressionNative]::keybd_event(0x11,0,2,[UIntPtr]::Zero)
    Wait-Process -Id $process.Id -Timeout 3 -ErrorAction SilentlyContinue
    $process.Refresh()
    if ($process.HasExited) { Event 'visual_graceful_exit' "exit_code=$($process.ExitCode)"; return }
    Event 'visual_force_kill' "pid=$($process.Id)"
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    Wait-Process -Id $process.Id -Timeout 2 -ErrorAction SilentlyContinue
}
function Sample([string]$phase, [int]$step, [int]$x, [int]$y) {
    [void][VisualRegressionNative]::SetCursorPos($x,$y)
    $p = New-Object VisualRegressionNative+POINT
    [void][VisualRegressionNative]::GetCursorPos([ref]$p)
    "$(Get-Qpc),$phase,$step,$x,$y,$($p.X),$($p.Y)" | Add-Content -Encoding ascii $groundPath
}
function Sweep([string]$phase, [int]$x0, [int]$y0, [int]$x1, [int]$y1, [int]$steps, [int]$sleepMs) {
    Event "phase_start" $phase
    for ($i=0; $i -le $steps; $i++) {
        $t = $i / [double]$steps
        $x = [int][math]::Round($x0 + ($x1-$x0)*$t)
        $y = [int][math]::Round($y0 + ($y1-$y0)*$t)
        Sample $phase $i $x $y
        if ($sleepMs -gt 0) { Start-Sleep -Milliseconds $sleepMs }
    }
    Event "phase_end" $phase
}

@'
Visual automated pointer/caret regression fixture.

The pointer will move automatically. No user interaction is required.

Line 1: The quick brown fox jumps over the lazy dog.
Line 2: Magnification should remain responsive during fast pointer motion.
Line 3: After pointer motion stops, semantic caret evidence should be able to resume.
Line 4: 0123456789 ABCDEFGHIJKLMNOPQRSTUVWXYZ
'@ | Set-Content -Encoding UTF8 $fixturePath

$notepad = $null
$visual = $null
$ff = $null
try {
    Event 'harness_start' "version=$visualVersion"
    $notepad = Start-Process notepad.exe -ArgumentList @($fixturePath) -PassThru
    Start-Sleep -Seconds 2

    $visualArgs = @('--zoom', $Zoom.ToString(), '--log', $telemetryPath)
    $visual = Start-Process -FilePath $visualExe -ArgumentList $visualArgs -PassThru
    Event 'visual_started' "pid=$($visual.Id);version=$visualVersion"
    Wait-VisualTelemetryReady $visual $telemetryPath

    $ffArgs = @(
        '-y','-hide_banner','-loglevel','warning',
        '-f','gdigrab','-framerate',$VideoFps.ToString(),'-draw_mouse','1',
        '-offset_x',$virtual.Left.ToString(),'-offset_y',$virtual.Top.ToString(),
        '-video_size',("{0}x{1}" -f $virtual.Width,$virtual.Height),
        '-i','desktop','-t','22',
        '-c:v','libx264','-preset','ultrafast','-crf','18','-pix_fmt','yuv420p',
        $videoPath
    )
    $ffmpegLaunchQpc = Get-Qpc
    $ff = Start-Process -FilePath $ffmpeg -ArgumentList $ffArgs -RedirectStandardError (Join-Path $runRoot 'ffmpeg_stderr.log') -PassThru -WindowStyle Hidden
    Event 'ffmpeg_started' "pid=$($ff.Id);fps=$VideoFps;qpc=$ffmpegLaunchQpc"
    Start-Sleep -Seconds 1

    $left = $primary.Left + 120
    $right = $primary.Right - 120
    $top = $primary.Top + 120
    $bottom = $primary.Bottom - 120
    $midX = [int](($left+$right)/2)
    $midY = [int](($top+$bottom)/2)

    Sample 'sync_center' 0 $midX $midY
    Event 'sync_center'
    Start-Sleep -Milliseconds 800

    Sweep 'slow_horizontal' $left $midY $right $midY 100 18
    Start-Sleep -Milliseconds 400

    Event 'phase_start' 'fast_horizontal_bursts'
    $step=0
    for($pass=0;$pass -lt 10;$pass++) {
        $a = if(($pass % 2)-eq 0){$left}else{$right}
        $b = if(($pass % 2)-eq 0){$right}else{$left}
        for($i=0;$i -le 32;$i++) {
            $t=$i/32.0
            $x=[int][math]::Round($a+($b-$a)*$t)
            Sample 'fast_horizontal_bursts' $step $x $midY
            $step++
            Start-Sleep -Milliseconds 4
        }
    }
    Event 'phase_end' 'fast_horizontal_bursts'
    Start-Sleep -Milliseconds 500

    Event 'phase_start' 'fast_zigzag'
    $corners=@(
        @($left,$top),@($right,$bottom),@($left,$bottom),@($right,$top),@($midX,$bottom),@($midX,$top)
    )
    $step=0
    for($cycle=0;$cycle -lt 8;$cycle++) {
        foreach($c in $corners) {
            Sample 'fast_zigzag' $step ([int]$c[0]) ([int]$c[1])
            $step++
            Start-Sleep -Milliseconds 12
        }
    }
    Event 'phase_end' 'fast_zigzag'
    Start-Sleep -Milliseconds 500

    Event 'phase_start' 'edge_teleports'
    for($i=0;$i -lt 80;$i++) {
        if(($i % 2)-eq0){ Sample 'edge_teleports' $i $left $midY } else { Sample 'edge_teleports' $i $right $midY }
        Start-Sleep -Milliseconds 10
    }
    Event 'phase_end' 'edge_teleports'

    Sample 'stationary' 0 $midX $midY
    Event 'stationary_start'
    Start-Sleep -Seconds 2
    Event 'stationary_end'

    # Caret handoff phase. Bring Notepad forward, click inside its client area, then move the caret.
    $np = Get-Process notepad -ErrorAction SilentlyContinue | Sort-Object StartTime -Descending | Select-Object -First 1
    if($np -and $np.MainWindowHandle -ne 0) {
        [void][VisualRegressionNative]::SetForegroundWindow($np.MainWindowHandle)
        Start-Sleep -Milliseconds 300
        [System.Windows.Forms.SendKeys]::SendWait('^{HOME}')
        Event 'caret_phase_start'
        for($i=0;$i -lt 24;$i++) {
            [System.Windows.Forms.SendKeys]::SendWait('{RIGHT}')
            Start-Sleep -Milliseconds 70
        }
        Event 'caret_phase_end'
    }

    if($ff) { Wait-Process -Id $ff.Id -Timeout 15 -ErrorAction SilentlyContinue }
    Event 'test_complete'
}
finally {
    if($visual) { Request-VisualExit $visual }
    if($ff -and -not $ff.HasExited) { Stop-Process -Id $ff.Id -Force -ErrorAction SilentlyContinue }
    if($notepad -and -not $notepad.HasExited) { Stop-Process -Id $notepad.Id -Force -ErrorAction SilentlyContinue }
}

# Analyze Visual telemetry against test phase intervals.
$eventRows = Import-Csv $eventsPath
$rawTelemetry = @(Get-Content $telemetryPath -ErrorAction Stop | Where-Object { $_ -and -not $_.StartsWith('#') })
$frames = @($rawTelemetry | ConvertFrom-Csv)
$successfulTelemetryFrames = TelemetrySuccessfulFrameCount $telemetryPath
$ground = @(Import-Csv $groundPath)

$phaseNames = @('slow_horizontal','fast_horizontal_bursts','fast_zigzag','edge_teleports')
$phaseResults = @()
$anomalies = @()
foreach($phase in $phaseNames) {
    $startRow = $eventRows | Where-Object { $_.event -eq 'phase_start' -and $_.detail -eq $phase } | Select-Object -First 1
    $endRow = $eventRows | Where-Object { $_.event -eq 'phase_end' -and $_.detail -eq $phase } | Select-Object -First 1
    if(-not $startRow -or -not $endRow){ continue }
    $qs=[int64]$startRow.qpc; $qe=[int64]$endRow.qpc
    $pf=@($frames | Where-Object { [int64]$_.qpc -ge $qs -and [int64]$_.qpc -le $qe })
    $pointer=@($pf | Where-Object { [int]$_.poi_source -eq 5 })
    $locatorMissing=@($pf | Where-Object { [int]$_.locator_visible -ne 1 })
    $pointerStale=@($pf | Where-Object { [double]$_.pointer_age_ms -gt 100.0 })
    $presentFails=@($pf | Where-Object { [uint64]$_.present_hr -ge 2147483648 })
    $maxPointerAge=if($pf.Count){($pf|Measure-Object -Property pointer_age_ms -Maximum).Maximum}else{$null}
    $phaseResults += [pscustomobject]@{
        phase=$phase; frame_count=$pf.Count; pointer_selected=$pointer.Count; pointer_selected_fraction=if($pf.Count){$pointer.Count/[double]$pf.Count}else{0};
        locator_missing_frames=$locatorMissing.Count; pointer_age_over_100ms_frames=$pointerStale.Count; max_pointer_age_ms=$maxPointerAge; present_failures=$presentFails.Count
    }
    foreach($f in $pf | Where-Object { [int]$_.locator_visible -ne 1 -or ([int]$_.poi_source -ne 5 -and [double]$_.pointer_age_ms -le 100.0) -or [double]$_.pointer_age_ms -gt 100.0 }) {
        $anomalies += [pscustomobject]@{phase=$phase;qpc=[int64]$f.qpc;frame=[int64]$f.frame;poi_source=[int]$f.poi_source;locator_visible=[int]$f.locator_visible;pointer_age_ms=[double]$f.pointer_age_ms;present_hr=[uint64]$f.present_hr}
    }
}

$allPresentFails=@($frames | Where-Object { [uint64]$_.present_hr -ge 2147483648 })
$analysis=[ordered]@{
    run=$stamp
    tested_executable=$visualExe
    tested_version=$visualVersion
    qpc_frequency=$qpcFreq
    video_fps=$VideoFps
    virtual_desktop=@{left=$virtual.Left;top=$virtual.Top;width=$virtual.Width;height=$virtual.Height}
    source_primary=@{left=$primary.Left;top=$primary.Top;width=$primary.Width;height=$primary.Height}
    destination=@{left=$dest.Bounds.Left;top=$dest.Bounds.Top;width=$dest.Bounds.Width;height=$dest.Bounds.Height}
    telemetry_frames=$frames.Count
    telemetry_successful_frames=$successfulTelemetryFrames
    ground_truth_samples=$ground.Count
    present_failures=$allPresentFails.Count
    phases=$phaseResults
    anomaly_count=$anomalies.Count
    anomalies=@($anomalies | Select-Object -First 100)
    video_path=$videoPath
}
$analysis | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 $analysisPath

# Generate contact sheets for the scripted fast phases using QPC relative to ffmpeg launch.
$contactDir=Join-Path $runRoot 'contact_sheets'; New-Item -ItemType Directory -Force -Path $contactDir|Out-Null
$ffStart = $eventRows | Where-Object {$_.event -eq 'ffmpeg_started'} | Select-Object -First 1
if((Test-Path $videoPath) -and $ffStart){
    $ffQpc=[int64](($ffStart.detail -split 'qpc=')[1])
    foreach($phase in $phaseNames){
        $startRow=$eventRows|Where-Object{$_.event-eq'phase_start'-and$_.detail-eq$phase}|Select-Object -First 1
        $endRow=$eventRows|Where-Object{$_.event-eq'phase_end'-and$_.detail-eq$phase}|Select-Object -First 1
        if(-not $startRow -or -not $endRow){continue}
        $startSec=[math]::Max(0,(([int64]$startRow.qpc-$ffQpc)/[double]$qpcFreq)-0.25)
        $duration=((([int64]$endRow.qpc-[int64]$startRow.qpc)/[double]$qpcFreq)+0.5)
        $sheet=Join-Path $contactDir "$phase.jpg"
        $crop="crop=$($dest.Bounds.Width):$($dest.Bounds.Height):$($dest.Bounds.Left-$virtual.Left):$($dest.Bounds.Top-$virtual.Top)"
        & $ffmpeg -y -hide_banner -loglevel error -ss $startSec -t $duration -i $videoPath -vf "$crop,fps=6,scale=640:-1,tile=4x4:padding=2:margin=2" -frames:v 1 $sheet
    }
}

$phaseMarkdown = ($phaseResults | ForEach-Object { "| $($_.phase) | $($_.frame_count) | $([math]::Round(100*$_.pointer_selected_fraction,1))% | $($_.locator_missing_frames) | $($_.pointer_age_over_100ms_frames) | $([math]::Round([double]$_.max_pointer_age_ms,1)) | $($_.present_failures) |" }) -join "`n"
@"
# Automated pointer visibility regression

- Run: `$stamp`
- Visual executable: `$visualExe`
- Version resource: `$visualVersion`
- Recording: ffmpeg gdigrab, full virtual desktop, ${VideoFps} fps, $($virtual.Width)x$($virtual.Height)
- Telemetry frames: $($frames.Count)
- Successful telemetry frames: $successfulTelemetryFrames
- Cursor ground-truth samples: $($ground.Count)
- Present failures: $($allPresentFails.Count)
- Telemetry anomaly rows: $($anomalies.Count)

| Phase | Frames | Pointer selected | Locator missing | Pointer age >100 ms | Max pointer age ms | Present failures |
|---|---:|---:|---:|---:|---:|---:|
$phaseMarkdown

## Interpretation

`poi_source=5` is Visual pointer evidence. The recorder uses `draw_mouse=1`, so the source-screen Windows cursor is added by gdigrab; Visual's destination-screen black/white locator is rendered by Visual itself and is therefore part of the actual Detail pixels.

Contact sheets under `contact_sheets/` are approximate QPC-to-video alignment using the ffmpeg launch timestamp. For exact sub-frame synchronization a later harness can add an explicit visual time marker, but this run is sufficient to distinguish long (~0.5-2 s) visible locator loss from normal frame timing.

The detailed machine-readable result is `analysis.json`.
"@ | Set-Content -Encoding UTF8 $reportPath

if($frames.Count-eq0-or$successfulTelemetryFrames-eq0){Event 'postrun_telemetry_invalid' "frames=$($frames.Count);successful_frames=$successfulTelemetryFrames";throw "Pointer visibility run produced no successful Visual telemetry frame rows: $telemetryPath"}

Write-Host "RUN_FOLDER=$runRoot"
Write-Host "ANALYSIS=$analysisPath"
Write-Host "REPORT=$reportPath"
Write-Host "VIDEO=$videoPath"
Get-Content $analysisPath
