param([Parameter(Mandatory=$true)][string]$Product,[string]$ProcessName='',[int]$DurationSec=20,[int]$FrameIntervalMs=200,[string]$OutputDir='')
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public static class ResearchNative {
 [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }
 [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);
 [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
 [DllImport("kernel32.dll")] public static extern bool QueryPerformanceCounter(out long v);
 [DllImport("kernel32.dll")] public static extern bool QueryPerformanceFrequency(out long v);
}
"@
try{[ResearchNative]::SetProcessDpiAwarenessContext([IntPtr](-4))|Out-Null}catch{}
function Qpc {$v=[long]0;[ResearchNative]::QueryPerformanceCounter([ref]$v)|Out-Null;$v}
$freq=[long]0;[ResearchNative]::QueryPerformanceFrequency([ref]$freq)|Out-Null
$repo=Resolve-Path (Join-Path $PSScriptRoot '..\..')
if(-not$OutputDir){$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss';$safe=($Product-replace'[^A-Za-z0-9_-]','_');$OutputDir=Join-Path $repo ('lab\benchmarks\incumbent_research\runs\'+$stamp+'__'+$safe)}
New-Item -ItemType Directory -Force $OutputDir|Out-Null
$frames=Join-Path $OutputDir 'frames';New-Item -ItemType Directory -Force $frames|Out-Null
$s=@([Windows.Forms.Screen]::AllScreens);$l=($s|%{$_.Bounds.Left}|Measure-Object -Minimum).Minimum;$t=($s|%{$_.Bounds.Top}|Measure-Object -Minimum).Minimum;$r=($s|%{$_.Bounds.Right}|Measure-Object -Maximum).Maximum;$b=($s|%{$_.Bounds.Bottom}|Measure-Object -Maximum).Maximum;$w=$r-$l;$h=$b-$t
$meta=[ordered]@{product=$Product;process_name=$ProcessName;captured_at=(Get-Date).ToString('o');duration_sec=$DurationSec;frame_interval_ms=$FrameIntervalMs;machine=$env:COMPUTERNAME;qpc_frequency=$freq;screens=@($s|%{[ordered]@{device=$_.DeviceName;primary=$_.Primary;x=$_.Bounds.X;y=$_.Bounds.Y;width=$_.Bounds.Width;height=$_.Bounds.Height}})}
$meta|ConvertTo-Json -Depth 6|Set-Content -Encoding UTF8 (Join-Path $OutputDir 'metadata.json')
'qpc,cursor_x,cursor_y,pid,cpu_seconds,working_set_mb,private_mb'|Set-Content -Encoding ascii (Join-Path $OutputDir 'samples.csv')
$end=(Get-Date).AddSeconds($DurationSec);$next=(Get-Date);$n=0
while((Get-Date)-lt$end){$q=Qpc;$p=New-Object ResearchNative+POINT;[ResearchNative]::GetCursorPos([ref]$p)|Out-Null;$procId='';$cpu='';$ws='';$priv='';if($ProcessName){$pp=Get-Process -Name $ProcessName -ErrorAction SilentlyContinue|Sort-Object WorkingSet64 -Descending|Select-Object -First 1;if($pp){$procId=$pp.Id;$cpu=[math]::Round($pp.CPU,3);$ws=[math]::Round($pp.WorkingSet64/1MB,2);$priv=[math]::Round($pp.PrivateMemorySize64/1MB,2)}};"$q,$($p.X),$($p.Y),$procId,$cpu,$ws,$priv"|Add-Content -Encoding ascii (Join-Path $OutputDir 'samples.csv');if((Get-Date)-ge$next){$bmp=[Drawing.Bitmap]::new([int]$w,[int]$h);$g=[Drawing.Graphics]::FromImage($bmp);try{$g.CopyFromScreen($l,$t,0,0,([Drawing.Size]::new([int]$w,[int]$h)));$bmp.Save((Join-Path $frames ('frame_{0:D5}_{1}.jpg'-f$n,$q)),[Drawing.Imaging.ImageFormat]::Jpeg)}finally{$g.Dispose();$bmp.Dispose()};$n++;$next=(Get-Date).AddMilliseconds($FrameIntervalMs)};Start-Sleep -Milliseconds 20}
[ordered]@{output_dir=$OutputDir;frames=$n;samples=((Get-Content (Join-Path $OutputDir 'samples.csv')).Count-1)}|ConvertTo-Json
