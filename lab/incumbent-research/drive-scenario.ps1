param(
  [Parameter(Mandatory=$true)][ValidateSet('pointer_sweep','caret_navigation','focus_navigation','cross_monitor','manual_feature')][string]$Scenario,
  [Parameter(Mandatory=$true)][string]$RunDirectory,
  [ValidateRange(0,10000)][int]$StartDelayMs=1200
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class IncumbentStimulusNative {
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr value);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hwnd,int x,int y,int w,int h,bool repaint);
}
"@ -ErrorAction SilentlyContinue
try {[void][IncumbentStimulusNative]::SetProcessDpiAwarenessContext([IntPtr](-4))} catch {}
$fixture=Join-Path $PSScriptRoot 'fixtures\magnifier_fixture.html'
if(-not(Test-Path $fixture)){throw "Fixture missing: $fixture"}
New-Item -ItemType Directory -Force $RunDirectory|Out-Null
$events=Join-Path $RunDirectory 'stimulus_events.csv'
'qpc,event,detail'|Set-Content -Encoding ascii $events
function Qpc {[Diagnostics.Stopwatch]::GetTimestamp()}
function Ev([string]$name,[string]$detail=''){("$((Qpc)),$name,$($detail.Replace(',',';'))")|Add-Content -Encoding ascii $events}
function Put([int]$x,[int]$y,[string]$detail=''){[void][IncumbentStimulusNative]::SetCursorPos($x,$y);Ev 'cursor' ("x=$x;y=$y;$detail")}
function Sweep([int]$x0,[int]$y0,[int]$x1,[int]$y1,[int]$steps,[int]$sleepMs,[string]$name){Ev 'phase_start' $name;for($i=0;$i-le$steps;$i++){$t=$i/[double]$steps;Put ([int][math]::Round($x0+($x1-$x0)*$t)) ([int][math]::Round($y0+($y1-$y0)*$t)) "$name step=$i";if($sleepMs-gt0){Start-Sleep -Milliseconds $sleepMs}};Ev 'phase_end' $name}
function FindById([IntPtr]$hwnd,[string]$id){$root=[System.Windows.Automation.AutomationElement]::FromHandle($hwnd);if(-not$root){return $null};$c=New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::AutomationIdProperty,$id);return $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants,$c)}
$screens=@([Windows.Forms.Screen]::AllScreens)
if($screens.Count-lt2){throw "Research fixture currently requires at least two active displays; found $($screens.Count)"}
$source=$screens|Where-Object{$_.Primary}|Select-Object -First 1
$secondary=$screens|Where-Object{-not$_.Primary}|Select-Object -First 1
$sb=$source.Bounds;$db=$secondary.Bounds
$browser=@('C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe','C:\Program Files\Microsoft\Edge\Application\msedge.exe')|Where-Object{Test-Path $_}|Select-Object -First 1
if(-not$browser){throw 'Microsoft Edge not found'}
$profile=Join-Path $RunDirectory 'edge_profile'
$uri=[Uri]$fixture
$before=Get-Date
$launcher=Start-Process $browser -ArgumentList @("--user-data-dir=$profile",'--no-first-run','--disable-sync','--force-renderer-accessibility','--enable-features=UiaProvider',"--app=$($uri.AbsoluteUri)") -PassThru
Ev 'browser_launch' "launcher_pid=$($launcher.Id)"
$deadline=(Get-Date).AddSeconds(12);$bp=$null
while((Get-Date)-lt$deadline){Start-Sleep -Milliseconds 150;$bp=Get-Process msedge -ErrorAction SilentlyContinue|Where-Object{$_.MainWindowHandle-ne0 -and $_.StartTime-ge$before.AddSeconds(-1)}|Sort-Object StartTime -Descending|Select-Object -First 1;if($bp){break}}
if(-not$bp){throw 'Fixture browser window not found'}
[void][IncumbentStimulusNative]::MoveWindow($bp.MainWindowHandle,$sb.Left+20,$sb.Top+20,[math]::Max(640,$sb.Width-40),[math]::Max(500,$sb.Height-40),$true)
[void][IncumbentStimulusNative]::SetForegroundWindow($bp.MainWindowHandle)
Start-Sleep -Milliseconds $StartDelayMs
Ev 'scenario_start' $Scenario
try {
  $w=New-Object -ComObject WScript.Shell
  switch($Scenario){
    'pointer_sweep' {
      $left=$sb.Left+80;$right=$sb.Right-80;$top=$sb.Top+120;$bottom=$sb.Bottom-100;$midY=[int](($top+$bottom)/2)
      Sweep $left $midY $right $midY 90 18 'slow_horizontal';Start-Sleep -Milliseconds 300
      for($pass=0;$pass-lt6;$pass++){if(($pass%2)-eq0){Sweep $left $midY $right $midY 35 4 "fast_$pass"}else{Sweep $right $midY $left $midY 35 4 "fast_$pass"}}
      Sweep $left $top $right $bottom 55 8 'diagonal';Sweep $right $top $left $bottom 55 8 'diagonal_return'
    }
    'caret_navigation' {
      $editor=FindById $bp.MainWindowHandle 'editor';if($editor){$editor.SetFocus();Ev 'focus_strategy' 'uia_editor'}else{[void][IncumbentStimulusNative]::SetForegroundWindow($bp.MainWindowHandle);Ev 'focus_strategy' 'fallback_page_autofocus'}
      Start-Sleep -Milliseconds 300;$w.SendKeys('^{HOME}');Ev 'key' 'CTRL+HOME';Start-Sleep -Milliseconds 250
      for($i=0;$i-lt50;$i++){$w.SendKeys('{RIGHT}');Start-Sleep -Milliseconds 25};Ev 'key_phase' 'RIGHT x50'
      $w.SendKeys('{END}');Ev 'key' 'END';Start-Sleep -Milliseconds 300
      for($i=0;$i-lt4;$i++){$w.SendKeys('{DOWN}');Start-Sleep -Milliseconds 220};Ev 'key_phase' 'DOWN x4'
      $w.SendKeys('{HOME}');Ev 'key' 'HOME';Start-Sleep -Milliseconds 300
      for($i=0;$i-lt3;$i++){$w.SendKeys('{UP}');Start-Sleep -Milliseconds 220};Ev 'key_phase' 'UP x3'
      for($i=0;$i-lt35;$i++){$w.SendKeys('{RIGHT}');Start-Sleep -Milliseconds 25};Ev 'key_phase' 'RIGHT x35'
    }
    'focus_navigation' {
      $b1=FindById $bp.MainWindowHandle 'b1';if($b1){$b1.SetFocus();Ev 'focus_strategy' 'uia_b1'}else{[void][IncumbentStimulusNative]::SetForegroundWindow($bp.MainWindowHandle);Start-Sleep -Milliseconds 200;for($j=0;$j-lt5;$j++){$w.SendKeys('+{TAB}');Start-Sleep -Milliseconds 120};Ev 'focus_strategy' 'fallback_shift_tab_to_b1'}
      Start-Sleep -Milliseconds 350;Ev 'focus' 'b1'
      for($i=0;$i-lt7;$i++){$w.SendKeys('{TAB}');Ev 'key' "TAB step=$i";Start-Sleep -Milliseconds 450}
      for($i=0;$i-lt4;$i++){$w.SendKeys('+{TAB}');Ev 'key' "SHIFT+TAB step=$i";Start-Sleep -Milliseconds 450}
    }
    'cross_monitor' {
      $sx=[int](($sb.Left+$sb.Right)/2);$sy=[int](($sb.Top+$sb.Bottom)/2);$sex=$sb.Right-8;$sey=[int][math]::Min($sb.Bottom-8,[math]::Max($sb.Top+8,$sy));$dx=$db.Left+30;$dy=[int](($db.Top+$db.Bottom)/2);$df=$db.Right-80
      Put $sx $sy 'source_center';Start-Sleep -Milliseconds 700
      Sweep $sx $sy $sex $sey 45 12 'source_to_edge';Sweep $sex $sey $dx $dy 30 15 'cross_to_secondary';Put $dx $dy 'secondary_near';Start-Sleep -Milliseconds 1000
      Sweep $dx $dy $df $dy 55 12 'secondary_sweep';Put $df $dy 'secondary_far';Start-Sleep -Milliseconds 800;Sweep $df $dy $sx $sy 70 12 'return_to_source';Put $sx $sy 'source_return';Start-Sleep -Milliseconds 700
    }
    'manual_feature' {Ev 'manual_window' 'No automated stimulus; perform documented feature interaction while recording.';Start-Sleep -Seconds 8}
  }
  Ev 'scenario_complete' $Scenario
} finally {
  try {Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" -ErrorAction SilentlyContinue|Where-Object{$_.CommandLine -like "*$profile*"}|ForEach-Object{Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue}} catch {}
}
