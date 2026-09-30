param(
 [Parameter(Mandatory=$true)][ValidateSet('caret_focus_native','pointer_sweep','cross_monitor','manual')][string]$Scenario,
 [Parameter(Mandatory=$true)][string]$RunDirectory
)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public static class ResearchStimulusNative {
 [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
 [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }
 [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
 [DllImport("kernel32.dll")] public static extern bool QueryPerformanceCounter(out long v);
}
"@
try{[ResearchStimulusNative]::SetProcessDpiAwarenessContext([IntPtr](-4))|Out-Null}catch{}
function Qpc {$v=[long]0;[ResearchStimulusNative]::QueryPerformanceCounter([ref]$v)|Out-Null;$v}
New-Item -ItemType Directory -Force $RunDirectory|Out-Null
$events=Join-Path $RunDirectory 'stimulus_events.csv'; 'qpc,event,detail'|Set-Content -Encoding ascii $events
$commands=Join-Path $RunDirectory 'stimulus_commands.csv'; 'qpc,phase,step,x,y,observed_x,observed_y'|Set-Content -Encoding ascii $commands
function Ev([string]$e,[string]$d=''){"$(Qpc),$e,$($d.Replace(',',';'))"|Add-Content -Encoding ascii $events}
function Put([string]$phase,[int]$step,[int]$x,[int]$y){[ResearchStimulusNative]::SetCursorPos($x,$y)|Out-Null;$p=New-Object ResearchStimulusNative+POINT;[ResearchStimulusNative]::GetCursorPos([ref]$p)|Out-Null;"$(Qpc),$phase,$step,$x,$y,$($p.X),$($p.Y)"|Add-Content -Encoding ascii $commands}
function Sweep([string]$phase,[int]$x0,[int]$y0,[int]$x1,[int]$y1,[int]$steps,[int]$sleepMs){Ev 'phase_start' $phase;for($i=0;$i-le$steps;$i++){$t=$i/[double]$steps;Put $phase $i ([int][math]::Round($x0+($x1-$x0)*$t)) ([int][math]::Round($y0+($y1-$y0)*$t));if($sleepMs-gt0){Start-Sleep -Milliseconds $sleepMs}};Ev 'phase_end' $phase}
$screens=@([Windows.Forms.Screen]::AllScreens);$primary=$screens|Where-Object{$_.Primary}|Select-Object -First 1
Ev 'stimulus_start' "scenario=$Scenario;displays=$($screens.Count)"
switch($Scenario){
 'caret_focus_native' {
   $stim=Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')) 'lab\prototypes\spike3_focus_caret_evidence\build\Release\visual_spike3_stimulus.exe'
   if(-not(Test-Path $stim)){throw 'Spike3 native stimulus executable missing'}
   $log=Join-Path $RunDirectory 'native_stimulus_events.jsonl'; $p=Start-Process $stim -ArgumentList @($log) -PassThru; $p.WaitForExit(); Ev 'native_stimulus_exit' "exit=$($p.ExitCode)"
 }
 'pointer_sweep' {
   $b=$primary.Bounds;$y=[int]($b.Top+$b.Height*.5);$x0=$b.Left+80;$x1=$b.Right-80
   Sweep 'slow_horizontal' $x0 $y $x1 $y 80 16; Start-Sleep -Milliseconds 300
   for($pass=0;$pass-lt6;$pass++){if(($pass%2)-eq0){Sweep 'fast_horizontal' $x0 $y $x1 $y 32 4}else{Sweep 'fast_horizontal' $x1 $y $x0 $y 32 4}}
   Start-Sleep -Milliseconds 500
 }
 'cross_monitor' {
   if($screens.Count-lt2){throw 'cross_monitor requires at least two displays'}
   $secondary=$screens|Where-Object{-not$_.Primary}|Select-Object -First 1;$a=$primary.Bounds;$b=$secondary.Bounds
   $ax=[int]($a.Left+$a.Width*.5);$ay=[int]($a.Top+$a.Height*.5);$bx=[int]($b.Left+$b.Width*.5);$by=[int]($b.Top+$b.Height*.5)
   Put 'primary_hold' 0 $ax $ay;Start-Sleep -Milliseconds 700;Sweep 'to_secondary' $ax $ay $bx $by 80 12;Start-Sleep -Milliseconds 900;Sweep 'to_primary' $bx $by $ax $ay 80 12;Start-Sleep -Milliseconds 700
 }
 'manual' {Start-Sleep -Seconds 10}
}
Ev 'stimulus_complete'
