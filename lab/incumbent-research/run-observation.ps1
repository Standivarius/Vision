param(
  [Parameter(Mandatory=$true)][string]$Product,
  [string]$ProcessName='',
  [ValidateRange(3,120)][int]$DurationSec=20,
  [string]$OutputDir='',
  [string]$Notes=''
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Windows.Forms
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class IncumbentObserveNative {
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
  [StructLayout(LayoutKind.Sequential)] public struct GUITHREADINFO {
    public int cbSize; public uint flags; public IntPtr hwndActive; public IntPtr hwndFocus; public IntPtr hwndCapture;
    public IntPtr hwndMenuOwner; public IntPtr hwndMoveSize; public IntPtr hwndCaret; public RECT rcCaret;
  }
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr value);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint pid);
  [DllImport("user32.dll")] public static extern bool GetGUIThreadInfo(uint idThread,ref GUITHREADINFO info);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr hwnd,ref POINT p);
  [DllImport("kernel32.dll")] public static extern bool QueryPerformanceCounter(out long v);
  [DllImport("kernel32.dll")] public static extern bool QueryPerformanceFrequency(out long v);
  [DllImport("kernel32.dll")] public static extern uint WTSGetActiveConsoleSessionId();
}
'@ -ErrorAction SilentlyContinue
try{[IncumbentObserveNative]::SetProcessDpiAwarenessContext([IntPtr](-4))|Out-Null}catch{}
function Qpc {$v=[long]0;[IncumbentObserveNative]::QueryPerformanceCounter([ref]$v)|Out-Null;return $v}
$freq=[long]0;[IncumbentObserveNative]::QueryPerformanceFrequency([ref]$freq)|Out-Null
if([Diagnostics.Process]::GetCurrentProcess().SessionId-ne[IncumbentObserveNative]::WTSGetActiveConsoleSessionId()){throw 'Observation must run in the active physical console session.'}
$repo=Resolve-Path (Join-Path $PSScriptRoot '..\..')
if(-not$OutputDir){$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss';$safe=($Product -replace '[^A-Za-z0-9_-]','_');$OutputDir=Join-Path $repo ('lab\benchmarks\incumbent_research\runs\'+$stamp+'__'+$safe)}
New-Item -ItemType Directory -Force $OutputDir|Out-Null
$screens=@([Windows.Forms.Screen]::AllScreens)
$left=($screens|ForEach-Object{$_.Bounds.Left}|Measure-Object -Minimum).Minimum
$top=($screens|ForEach-Object{$_.Bounds.Top}|Measure-Object -Minimum).Minimum
$right=($screens|ForEach-Object{$_.Bounds.Right}|Measure-Object -Maximum).Maximum
$bottom=($screens|ForEach-Object{$_.Bounds.Bottom}|Measure-Object -Maximum).Maximum
$width=$right-$left;$height=$bottom-$top
$ffmpeg=(Get-Command ffmpeg.exe -ErrorAction SilentlyContinue).Source
if(-not$ffmpeg){$ffmpeg=Get-ChildItem (Join-Path $PSScriptRoot 'tools\ffmpeg') -Filter ffmpeg.exe -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1 -ExpandProperty FullName}
if(-not$ffmpeg){throw 'Portable ffmpeg missing. Run ensure-ffmpeg.ps1 first.'}
$video=Join-Path $OutputDir 'desktop.mp4'
$stderr=Join-Path $OutputDir 'ffmpeg_stderr.log'
$samplePath=Join-Path $OutputDir 'observation.csv'
$processPath=Join-Path $OutputDir 'process.csv'
$eventPath=Join-Path $OutputDir 'events.csv'
"qpc,event,detail"|Set-Content -Encoding ascii $eventPath
function Ev([string]$name,[string]$detail=''){"$(Qpc),$name,$($detail.Replace(',',';'))"|Add-Content -Encoding ascii $eventPath}
$displayMeta=@($screens|ForEach-Object{[ordered]@{device=$_.DeviceName;primary=$_.Primary;x=$_.Bounds.X;y=$_.Bounds.Y;width=$_.Bounds.Width;height=$_.Bounds.Height}})
$meta=[ordered]@{product=$Product;process_name=$ProcessName;captured_at=(Get-Date).ToString('o');duration_sec=$DurationSec;notes=$Notes;machine=$env:COMPUTERNAME;qpc_frequency=$freq;virtual_desktop=[ordered]@{x=$left;y=$top;width=$width;height=$height};screens=$displayMeta}
$meta|ConvertTo-Json -Depth 6|Set-Content -Encoding UTF8 (Join-Path $OutputDir 'metadata.json')
"qpc,cursor_x,cursor_y,foreground_hwnd,foreground_pid,caret_hwnd,caret_left,caret_top,caret_right,caret_bottom"|Set-Content -Encoding ascii $samplePath
"qpc,pid,cpu_seconds,working_set_bytes,private_bytes,responding"|Set-Content -Encoding ascii $processPath
$size=('{0}x{1}' -f $width,$height)
$ffArgs=@('-y','-hide_banner','-loglevel','warning','-f','gdigrab','-framerate','30','-draw_mouse','1','-offset_x',$left.ToString(),'-offset_y',$top.ToString(),'-video_size',$size,'-i','desktop','-t',($DurationSec+2).ToString(),'-c:v','libx264','-preset','ultrafast','-crf','18','-pix_fmt','yuv420p',$video)
$ff=Start-Process -FilePath $ffmpeg -ArgumentList $ffArgs -RedirectStandardError $stderr -PassThru -WindowStyle Hidden
Ev 'recording_started' "pid=$($ff.Id)"
$end=(Get-Date).AddSeconds($DurationSec)
try{
  while((Get-Date)-lt$end){
    $q=Qpc
    $pt=New-Object IncumbentObserveNative+POINT
    [IncumbentObserveNative]::GetCursorPos([ref]$pt)|Out-Null
    $fg=[IncumbentObserveNative]::GetForegroundWindow();$fgPid=[uint32]0;$tid=if($fg-ne[IntPtr]::Zero){[IncumbentObserveNative]::GetWindowThreadProcessId($fg,[ref]$fgPid)}else{0}
    $ch='';$cl='';$ct='';$cr='';$cb=''
    if($tid-ne0){
      $gi=New-Object IncumbentObserveNative+GUITHREADINFO;$gi.cbSize=[Runtime.InteropServices.Marshal]::SizeOf($gi)
      if([IncumbentObserveNative]::GetGUIThreadInfo($tid,[ref]$gi) -and $gi.hwndCaret-ne[IntPtr]::Zero){
        $p1=New-Object IncumbentObserveNative+POINT;$p1.X=$gi.rcCaret.Left;$p1.Y=$gi.rcCaret.Top
        $p2=New-Object IncumbentObserveNative+POINT;$p2.X=$gi.rcCaret.Right;$p2.Y=$gi.rcCaret.Bottom
        [IncumbentObserveNative]::ClientToScreen($gi.hwndCaret,[ref]$p1)|Out-Null;[IncumbentObserveNative]::ClientToScreen($gi.hwndCaret,[ref]$p2)|Out-Null
        $ch=$gi.hwndCaret.ToInt64();$cl=$p1.X;$ct=$p1.Y;$cr=$p2.X;$cb=$p2.Y
      }
    }
    "$q,$($pt.X),$($pt.Y),$($fg.ToInt64()),$fgPid,$ch,$cl,$ct,$cr,$cb"|Add-Content -Encoding ascii $samplePath
    if($ProcessName){
      Get-Process -Name $ProcessName -ErrorAction SilentlyContinue|ForEach-Object{
        try{"$q,$($_.Id),$([Math]::Round($_.CPU,4)),$($_.WorkingSet64),$($_.PrivateMemorySize64),$($_.Responding)"|Add-Content -Encoding ascii $processPath}catch{}
      }
    }
    Start-Sleep -Milliseconds 20
  }
} finally {
  Ev 'observation_complete'
  if($ff-and-not$ff.HasExited){Wait-Process -Id $ff.Id -Timeout 5 -ErrorAction SilentlyContinue}
  if($ff-and-not$ff.HasExited){Stop-Process -Id $ff.Id -Force -ErrorAction SilentlyContinue}
}
$obsRows=@(Import-Csv $samplePath -ErrorAction SilentlyContinue)
$procRows=@(Import-Csv $processPath -ErrorAction SilentlyContinue)
$analysis=[ordered]@{
  samples=$obsRows.Count
  process_samples=$procRows.Count
  product_process_observed=($procRows.Count-gt0)
  max_working_set_mb=if($procRows.Count){[math]::Round((($procRows|ForEach-Object{[double]$_.working_set_bytes}|Measure-Object -Maximum).Maximum/1MB),2)}else{$null}
  max_private_mb=if($procRows.Count){[math]::Round((($procRows|ForEach-Object{[double]$_.private_bytes}|Measure-Object -Maximum).Maximum/1MB),2)}else{$null}
  video_present=(Test-Path $video)
  video_bytes=if(Test-Path $video){(Get-Item $video).Length}else{0}
}
$analysis|ConvertTo-Json -Depth 4|Set-Content -Encoding UTF8 (Join-Path $OutputDir 'observer_analysis.json')
@("# Observation summary","","- Product: $Product","- Samples: $($analysis.samples)","- Product process samples: $($analysis.process_samples)","- Product process observed: $($analysis.product_process_observed)","- Max working set: $($analysis.max_working_set_mb) MB","- Max private bytes: $($analysis.max_private_mb) MB","- Video present: $($analysis.video_present)") -join "`r`n" | Set-Content -Encoding UTF8 (Join-Path $OutputDir 'OBSERVER_SUMMARY.md')
Write-Output $OutputDir
