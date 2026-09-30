param([ValidateRange(1,4)][int]$Zoom=2)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class VisualFocusSmokeNative {
  [DllImport("kernel32.dll")] public static extern uint WTSGetActiveConsoleSessionId();
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd,uint msg,IntPtr wParam,IntPtr lParam);
}
'@ -ErrorAction SilentlyContinue

$repo=Resolve-Path (Join-Path $PSScriptRoot '..')
$visual=Join-Path $PSScriptRoot 'build\Release\visual_app.exe'
$stimulus=Join-Path $repo 'lab\prototypes\spike3_focus_caret_evidence\build\Release\visual_spike3_stimulus.exe'
if(-not(Test-Path $visual)){throw "Visual app not built: $visual"}
if(-not(Test-Path $stimulus)){throw "Spike 3 stimulus not built: $stimulus"}
if([Diagnostics.Process]::GetCurrentProcess().SessionId-ne[VisualFocusSmokeNative]::WTSGetActiveConsoleSessionId()){throw 'Focus smoke requires active console session'}
$screens=@([Windows.Forms.Screen]::AllScreens);if($screens.Count-lt2){throw 'Focus smoke requires two displays'}
$primary=$screens|Where-Object{$_.Primary}|Select-Object -First 1
$b=$primary.Bounds

$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$run=Join-Path $repo ("lab\benchmarks\integrated_app\runs\${stamp}__focus_smoke")
New-Item -ItemType Directory -Force -Path $run|Out-Null
$scenario=Join-Path $run 'scenario_events.jsonl'
$telemetry=Join-Path $run 'visual_app_telemetry.csv'

[Windows.Forms.Cursor]::Position=[Drawing.Point]::new($b.Right-40,$b.Bottom-40)
$sp=Start-Process $stimulus -ArgumentList @($scenario) -PassThru
$deadline=(Get-Date).AddSeconds(5);while((Get-Date)-lt$deadline -and $sp.MainWindowHandle-eq0){Start-Sleep -Milliseconds 100;$sp.Refresh()}
if($sp.HasExited){throw "Stimulus exited early: $($sp.ExitCode)"}
Start-Sleep -Milliseconds 250
$vp=Start-Process $visual -ArgumentList @('--zoom',[string]$Zoom,'--log',$telemetry) -PassThru
$deadline=(Get-Date).AddSeconds(5);while((Get-Date)-lt$deadline -and $vp.MainWindowHandle-eq0){Start-Sleep -Milliseconds 100;$vp.Refresh()}
if($vp.HasExited){throw "Visual exited early: $($vp.ExitCode)"}

if(-not$sp.WaitForExit(15000)){Stop-Process -Id $sp.Id -Force -ErrorAction SilentlyContinue;throw 'Stimulus timed out'}
Start-Sleep -Milliseconds 300
$vp.Refresh();if(-not$vp.HasExited-and$vp.MainWindowHandle-ne0){[VisualFocusSmokeNative]::PostMessage($vp.MainWindowHandle,0x0010,[IntPtr]::Zero,[IntPtr]::Zero)|Out-Null}
if(-not$vp.WaitForExit(5000)){Stop-Process -Id $vp.Id -Force -ErrorAction SilentlyContinue;throw 'Visual did not close'}

$rows=@(Import-Csv $telemetry);$events=@(Get-Content $scenario|Where-Object{$_.Trim()}|ForEach-Object{$_|ConvertFrom-Json})
if(-not$rows.Count-or-not$events.Count){throw 'Missing telemetry or scenario events'}
function PhaseRows([string]$name){
  $idx=-1;for($i=0;$i-lt$events.Count;$i++){if([string]$events[$i].event-eq$name){$idx=$i;break}}
  if($idx-lt0){return @()}
  $start=[int64]$events[$idx].qpc;$end=if($idx+1-lt$events.Count){[int64]$events[$idx+1].qpc}else{[int64]::MaxValue}
  return @($rows|Where-Object{[int64]$_.qpc-ge$start-and[int64]$_.qpc-lt$end})
}
$button=@(PhaseRows 'button_focus');$check=@(PhaseRows 'checkbox_focus')
$focusRows=@($button+$check)
$focusSemantic=@($focusRows|Where-Object{[int]$_.poi_source-eq3}).Count
$focusWin32=@($focusRows|Where-Object{[int]$_.poi_source-eq4}).Count
$focusPointer=@($focusRows|Where-Object{[int]$_.poi_source-eq5}).Count
$focusCaret=@($focusRows|Where-Object{[int]$_.poi_source-eq0-or[int]$_.poi_source-eq1-or[int]$_.poi_source-eq2}).Count
$focusLocator=@($focusRows|Where-Object{[int]$_.locator_visible-eq1}).Count
$presentFailures=@($rows|Where-Object{[uint64]$_.present_hr-ne0}).Count
$invalid=@($rows|Where-Object{[int]$_.viewport_action-eq0}).Count
$pass=($presentFailures-eq0-and$focusRows.Count-gt0-and($focusSemantic+$focusWin32)-gt0-and$focusCaret-eq0-and$focusPointer-eq0-and$focusLocator-gt0-and$invalid-eq0)
$analysis=[ordered]@{
 frames=$rows.Count;present_failures=$presentFailures;focus_phase_frames=$focusRows.Count;uia_focus_frames=$focusSemantic;win32_focus_frames=$focusWin32;pointer_frames_in_focus_phases=$focusPointer;caret_frames_in_focus_phases=$focusCaret;locator_frames_in_focus_phases=$focusLocator;invalid_frames=$invalid;pass=$pass
}
$analysis|ConvertTo-Json -Depth 4|Set-Content -Encoding UTF8 (Join-Path $run 'analysis.json')
@('# Integrated Visual focus smoke','',"- Frames: $($rows.Count)","- Present failures: $presentFailures","- Button/checkbox focus-phase frames: $($focusRows.Count)","- UIA focus / Win32 focus: $focusSemantic / $focusWin32","- Pointer / caret frames during focus-only phases: $focusPointer / $focusCaret","- Locator frames during focus-only phases: $focusLocator","- Invalid viewport decisions: $invalid","- Pass: $pass")-join"`r`n"|Set-Content -Encoding UTF8 (Join-Path $run 'SUMMARY.md')
if(-not$pass){throw "Integrated focus smoke failed. See $run"}
Write-Host "Integrated focus smoke complete: $run";Get-Content (Join-Path $run 'SUMMARY.md')
