param(
    [int]$VideoFps = 15,
    [int]$Zoom = 2
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest

$repo=Resolve-Path (Join-Path $PSScriptRoot '..\..')
$visualExe=Join-Path $repo 'app\build\Release\visual_app.exe'
if(-not(Test-Path $visualExe)){throw "Visual executable not found: $visualExe"}

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class CrossingNative {
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr value);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X,int Y);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
  [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
  [DllImport("kernel32.dll")] public static extern bool QueryPerformanceCounter(out long v);
  [DllImport("kernel32.dll")] public static extern bool QueryPerformanceFrequency(out long v);
}
'@
try{[void][CrossingNative]::SetProcessDpiAwarenessContext([IntPtr](-4))}catch{}
Add-Type -AssemblyName System.Windows.Forms

function Qpc { $v=[long]0;[void][CrossingNative]::QueryPerformanceCounter([ref]$v);$v }
$qpcFreq=[long]0;[void][CrossingNative]::QueryPerformanceFrequency([ref]$qpcFreq)

$screens=@([System.Windows.Forms.Screen]::AllScreens)
if($screens.Count-lt2){throw "Need two active displays; found $($screens.Count)."}
$source=$screens|Where-Object{$_.Primary}|Select-Object -First 1
$dest=$screens|Where-Object{-not $_.Primary}|Select-Object -First 1
if(-not $source -or -not $dest){throw 'Could not identify source and destination displays.'}

$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$runRoot=Join-Path $repo "lab\benchmarks\visual_regression\runs\${stamp}__pointer_crossing"
New-Item -ItemType Directory -Force -Path $runRoot|Out-Null
$telemetry=Join-Path $runRoot 'visual_telemetry.csv'
$ground=Join-Path $runRoot 'cursor_ground_truth.csv'
$events=Join-Path $runRoot 'test_events.csv'
$video=Join-Path $runRoot 'desktop.mp4'
$report=Join-Path $runRoot 'REPORT.md'
$analysis=Join-Path $runRoot 'analysis.json'

"qpc,event,detail"|Set-Content -Encoding ascii $events
"qpc,phase,step,expected_x,expected_y,observed_x,observed_y,monitor"|Set-Content -Encoding ascii $ground
function Ev([string]$name,[string]$detail=''){"$(Qpc),$name,$($detail.Replace(',',';'))"|Add-Content -Encoding ascii $events}
function Membership([int]$x,[int]$y){
  $sb=$source.Bounds;$db=$dest.Bounds
  if($x-ge$sb.Left-and$x-lt$sb.Right-and$y-ge$sb.Top-and$y-lt$sb.Bottom){return 'primary'}
  if($x-ge$db.Left-and$x-lt$db.Right-and$y-ge$db.Top-and$y-lt$db.Bottom){return 'secondary'}
  return 'neither'
}
function Put([string]$phase,[int]$step,[int]$x,[int]$y){
  [void][CrossingNative]::SetCursorPos($x,$y)
  $p=New-Object CrossingNative+POINT;[void][CrossingNative]::GetCursorPos([ref]$p)
  $m=Membership $p.X $p.Y
  "$(Qpc),$phase,$step,$x,$y,$($p.X),$($p.Y),$m"|Add-Content -Encoding ascii $ground
}
function Hold([string]$phase,[int]$x,[int]$y,[int]$ms){
  Ev 'phase_start' $phase
  $steps=[math]::Max(1,[int]($ms/20))
  for($i=0;$i-lt$steps;$i++){Put $phase $i $x $y;Start-Sleep -Milliseconds 20}
  Ev 'phase_end' $phase
}
function Sweep([string]$phase,[int]$x0,[int]$y0,[int]$x1,[int]$y1,[int]$ms){
  Ev 'phase_start' $phase
  $steps=[math]::Max(2,[int]($ms/20))
  for($i=0;$i-le$steps;$i++){$t=$i/[double]$steps;$x=[int][math]::Round($x0+($x1-$x0)*$t);$y=[int][math]::Round($y0+($y1-$y0)*$t);Put $phase $i $x $y;Start-Sleep -Milliseconds 20}
  Ev 'phase_end' $phase
}
function TelemetryFrameCount([string]$path){
  if(-not(Test-Path $path)){return 0}
  return @(Get-Content $path -ErrorAction SilentlyContinue|Where-Object{$_ -match '^\d+,'}).Count
}
function TelemetrySuccessfulFrameCount([string]$path){
  if(-not(Test-Path $path)){return 0}
  $count=0
  foreach($line in @(Get-Content $path -ErrorAction SilentlyContinue|Where-Object{$_ -match '^\d+,'})){
    $parts=$line.Split(',')
    if($parts.Count-le12){continue}
    try{$hr=[uint64]$parts[12]}catch{continue}
    if($hr-lt2147483648){$count++}
  }
  return $count
}
function HasFirstRenderEvent([string]$path){
  if(-not(Test-Path $path)){return $false}
  return @((Get-Content $path -ErrorAction SilentlyContinue)|Where-Object{$_ -eq '# event=first_render_frame'}).Count -gt 0
}
function Wait-VisualTelemetryReady([System.Diagnostics.Process]$process,[string]$path,[int]$timeoutMs=12000){
  $sw=[System.Diagnostics.Stopwatch]::StartNew()
  while($sw.ElapsedMilliseconds-lt$timeoutMs){
    $process.Refresh()
    if($process.HasExited){
      Ev 'visual_exited_early' "exit_code=$($process.ExitCode);elapsed_ms=$($sw.ElapsedMilliseconds)"
      throw "Visual exited before telemetry became ready (exit code $($process.ExitCode))."
    }
    $successCount=TelemetrySuccessfulFrameCount $path
    if((HasFirstRenderEvent $path)-and$successCount-gt0){Ev 'telemetry_ready' "successful_frames=$successCount;elapsed_ms=$($sw.ElapsedMilliseconds)";return}
    Start-Sleep -Milliseconds 100
  }
  $process.Refresh()
  $detail="elapsed_ms=$($sw.ElapsedMilliseconds);frames=$(TelemetryFrameCount $path);successful_frames=$(TelemetrySuccessfulFrameCount $path);first_render_event=$(HasFirstRenderEvent $path);has_exited=$($process.HasExited)"
  if($process.HasExited){$detail+=";exit_code=$($process.ExitCode)"}
  Ev 'telemetry_timeout' $detail
  throw "Visual telemetry did not produce a successful rendered frame within $timeoutMs ms."
}
function Request-VisualExit([System.Diagnostics.Process]$process){
  if(-not$process){return}
  $process.Refresh()
  if($process.HasExited){Ev 'visual_already_exited' "exit_code=$($process.ExitCode)";return}
  Ev 'visual_graceful_exit_requested' 'hotkey=Ctrl+Alt+Q'
  [CrossingNative]::keybd_event(0x11,0,0,[UIntPtr]::Zero)
  [CrossingNative]::keybd_event(0x12,0,0,[UIntPtr]::Zero)
  [CrossingNative]::keybd_event(0x51,0,0,[UIntPtr]::Zero)
  [CrossingNative]::keybd_event(0x51,0,2,[UIntPtr]::Zero)
  [CrossingNative]::keybd_event(0x12,0,2,[UIntPtr]::Zero)
  [CrossingNative]::keybd_event(0x11,0,2,[UIntPtr]::Zero)
  Wait-Process -Id $process.Id -Timeout 3 -ErrorAction SilentlyContinue
  $process.Refresh()
  if($process.HasExited){Ev 'visual_graceful_exit' "exit_code=$($process.ExitCode)";return}
  Ev 'visual_force_kill' "pid=$($process.Id)"
  Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
  Wait-Process -Id $process.Id -Timeout 2 -ErrorAction SilentlyContinue
}

# Find portable ffmpeg from previous harness download or PATH.
$ffmpeg=(Get-Command ffmpeg.exe -ErrorAction SilentlyContinue).Source
if(-not$ffmpeg){$ffmpeg=Get-ChildItem (Join-Path $PSScriptRoot 'tools\ffmpeg') -Filter ffmpeg.exe -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1 -ExpandProperty FullName}
if(-not$ffmpeg){throw 'ffmpeg not found; run the pointer-visibility harness once to provision the portable recorder.'}

# Virtual bounds using DPI-aware Screen coordinates.
$left=($screens|ForEach-Object{$_.Bounds.Left}|Measure-Object -Minimum).Minimum
$top=($screens|ForEach-Object{$_.Bounds.Top}|Measure-Object -Minimum).Minimum
$right=($screens|ForEach-Object{$_.Bounds.Right}|Measure-Object -Maximum).Maximum
$bottom=($screens|ForEach-Object{$_.Bounds.Bottom}|Measure-Object -Maximum).Maximum
$vw=$right-$left;$vh=$bottom-$top

$sb=$source.Bounds;$db=$dest.Bounds
$srcCenterX=[int](($sb.Left+$sb.Right)/2);$srcCenterY=[int](($sb.Top+$sb.Bottom)/2)
$srcEdgeX=$sb.Right-8;$srcEdgeY=[math]::Min($sb.Bottom-8,[math]::Max($sb.Top+8,$srcCenterY))
$dstNearX=$db.Left+30;$dstCenterX=[int](($db.Left+$db.Right)/2);$dstCenterY=[int](($db.Top+$db.Bottom)/2)
$dstFarX=$db.Right-60

$visual=$null;$ff=$null
try{
  Ev 'harness_start' "source=$($source.DeviceName);dest=$($dest.DeviceName)"
  $visual=Start-Process $visualExe -ArgumentList @('--zoom',$Zoom.ToString(),'--log',$telemetry) -PassThru
  Ev 'visual_started' "pid=$($visual.Id)"
  Wait-VisualTelemetryReady $visual $telemetry

  $ffArgs=@('-y','-hide_banner','-loglevel','warning','-f','gdigrab','-framerate',$VideoFps.ToString(),'-draw_mouse','1','-offset_x',$left.ToString(),'-offset_y',$top.ToString(),'-video_size',("{0}x{1}"-f$vw,$vh),'-i','desktop','-t','24','-c:v','libx264','-preset','ultrafast','-crf','18','-pix_fmt','yuv420p',$video)
  $ff=Start-Process $ffmpeg -ArgumentList $ffArgs -RedirectStandardError (Join-Path $runRoot 'ffmpeg_stderr.log') -PassThru -WindowStyle Hidden
  Ev 'ffmpeg_started' "pid=$($ff.Id);fps=$VideoFps"
  Start-Sleep -Seconds 1

  Hold 'primary_center_hold' $srcCenterX $srcCenterY 1500
  Sweep 'primary_to_edge' $srcCenterX $srcCenterY $srcEdgeX $srcEdgeY 1200
  Hold 'primary_edge_hold' $srcEdgeX $srcEdgeY 1500

  # Explicitly cross to the secondary display and keep the pointer there long enough to be unmistakable in video.
  Sweep 'cross_to_secondary' $srcEdgeX $srcEdgeY $dstNearX $dstCenterY 800
  Hold 'secondary_near_hold' $dstNearX $dstCenterY 1800
  Sweep 'secondary_sweep' $dstNearX $dstCenterY $dstFarX $dstCenterY 1500
  Hold 'secondary_far_hold' $dstFarX $dstCenterY 1800

  Sweep 'return_to_primary' $dstFarX $dstCenterY $srcCenterX $srcCenterY 1200
  Hold 'primary_return_hold' $srcCenterX $srcCenterY 1800
  Ev 'test_complete'

  if($ff){Wait-Process -Id $ff.Id -Timeout 12 -ErrorAction SilentlyContinue}
} finally {
  if($visual){Request-VisualExit $visual}
  if($ff-and-not$ff.HasExited){Stop-Process -Id $ff.Id -Force -ErrorAction SilentlyContinue}
}

$g=@(Import-Csv $ground)
$rawTelemetry=@(Get-Content $telemetry -ErrorAction Stop|Where-Object{$_-and-not$_.StartsWith('#')})
$t=@($rawTelemetry|ConvertFrom-Csv)
$successfulTelemetryFrames=TelemetrySuccessfulFrameCount $telemetry
$phaseSummary=@()
foreach($name in @('primary_center_hold','primary_edge_hold','cross_to_secondary','secondary_near_hold','secondary_sweep','secondary_far_hold','return_to_primary','primary_return_hold')){
  $rows=@($g|Where-Object{$_.phase-eq$name})
  $phaseSummary += [pscustomobject]@{phase=$name;samples=$rows.Count;primary=@($rows|Where-Object{$_.monitor-eq'primary'}).Count;secondary=@($rows|Where-Object{$_.monitor-eq'secondary'}).Count;neither=@($rows|Where-Object{$_.monitor-eq'neither'}).Count;first_x=if($rows.Count){[int]$rows[0].observed_x}else{$null};last_x=if($rows.Count){[int]$rows[-1].observed_x}else{$null}}
}

$result=[ordered]@{
 run=$stamp
 source=@{device=$source.DeviceName;left=$sb.Left;top=$sb.Top;right=$sb.Right;bottom=$sb.Bottom;width=$sb.Width;height=$sb.Height}
 secondary=@{device=$dest.DeviceName;left=$db.Left;top=$db.Top;right=$db.Right;bottom=$db.Bottom;width=$db.Width;height=$db.Height}
 video_fps_requested=$VideoFps
 ground_truth_samples=$g.Count
 telemetry_frames=$t.Count
 telemetry_successful_frames=$successfulTelemetryFrames
 phases=$phaseSummary
 hypothesis_supported=(@($g|Where-Object{$_.phase-like'secondary*'-and$_.monitor-eq'secondary'}).Count -gt 0)
}
$result|ConvertTo-Json -Depth 6|Set-Content -Encoding UTF8 $analysis

$md=($phaseSummary|ForEach-Object{"| $($_.phase) | $($_.samples) | $($_.primary) | $($_.secondary) | $($_.neither) | $($_.first_x) | $($_.last_x) |"})-join"`n"
@"
# Pointer crossing regression

This test directly checks whether the native Windows pointer can leave the primary/source display, remain on the secondary Detail display, and later return, while Visual is running.

- Source: `$($source.DeviceName)` $($sb.Left),$($sb.Top) $($sb.Width)x$($sb.Height)
- Secondary: `$($dest.DeviceName)` $($db.Left),$($db.Top) $($db.Width)x$($db.Height)
- Ground-truth samples: $($g.Count)
- Visual telemetry frames: $($t.Count)
- Successful Visual telemetry frames: $successfulTelemetryFrames
- Video: `desktop.mp4` with native cursor capture enabled (`draw_mouse=1`)

| Phase | Samples | On primary | On secondary | Neither | First X | Last X |
|---|---:|---:|---:|---:|---:|---:|
$md

`hypothesis_supported` in `analysis.json` means the independent `GetCursorPos` stream objectively observed the pointer on the secondary display for the deliberate secondary phases. The long holds make this independent of recorder frame rate.
"@|Set-Content -Encoding UTF8 $report

if($t.Count-eq0-or$successfulTelemetryFrames-eq0){Ev 'postrun_telemetry_invalid' "frames=$($t.Count);successful_frames=$successfulTelemetryFrames";throw "Pointer crossing run produced no successful Visual telemetry frame rows: $telemetry"}

Write-Host "RUN_FOLDER=$runRoot"
Get-Content $analysis
