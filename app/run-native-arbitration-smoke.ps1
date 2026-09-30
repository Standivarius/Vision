param([ValidateRange(1,4)][int]$Zoom=2)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class VisualNativeArbSmoke {
  [DllImport("kernel32.dll")] public static extern uint WTSGetActiveConsoleSessionId();
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd,uint msg,IntPtr wParam,IntPtr lParam);
}
'@ -ErrorAction SilentlyContinue

$repo=Resolve-Path (Join-Path $PSScriptRoot '..')
$visual=Join-Path $PSScriptRoot 'build\Release\visual_app.exe'
$stimulus=Join-Path $repo 'lab\prototypes\spike3_focus_caret_evidence\build\Release\visual_spike3_stimulus.exe'
if(-not(Test-Path $visual)){throw "Visual app not built: $visual"}
if(-not(Test-Path $stimulus)){throw "Spike 3 stimulus not built: $stimulus"}
if([Diagnostics.Process]::GetCurrentProcess().SessionId-ne[VisualNativeArbSmoke]::WTSGetActiveConsoleSessionId()){throw 'Native arbitration smoke requires active console session'}
$screens=@([Windows.Forms.Screen]::AllScreens);if($screens.Count-lt2){throw 'Native arbitration smoke requires two displays'}
$primary=$screens|Where-Object{$_.Primary}|Select-Object -First 1;$b=$primary.Bounds

$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$run=Join-Path $repo ("lab\benchmarks\integrated_app\runs\${stamp}__native_arbitration_smoke")
New-Item -ItemType Directory -Force -Path $run|Out-Null
$scenario=Join-Path $run 'scenario_events.jsonl'
$telemetry=Join-Path $run 'visual_app_telemetry.csv'

$sp=Start-Process $stimulus -ArgumentList @($scenario) -PassThru
$deadline=(Get-Date).AddSeconds(5);while((Get-Date)-lt$deadline-and$sp.MainWindowHandle-eq0){Start-Sleep -Milliseconds 50;$sp.Refresh()}
if($sp.HasExited){throw "Stimulus exited early: $($sp.ExitCode)"}
$vp=Start-Process $visual -ArgumentList @('--zoom',[string]$Zoom,'--log',$telemetry) -PassThru
$deadline=(Get-Date).AddSeconds(5);while((Get-Date)-lt$deadline-and$vp.MainWindowHandle-eq0){Start-Sleep -Milliseconds 50;$vp.Refresh()}
if($vp.HasExited){throw "Visual exited early: $($vp.ExitCode)"}

# Wait until the first real edit caret phase is active.
$deadline=(Get-Date).AddSeconds(5);$singleStart=$null
while((Get-Date)-lt$deadline){
  if(Test-Path $scenario){
    $events=@(Get-Content $scenario -ErrorAction SilentlyContinue|Where-Object{$_.Trim()}|ForEach-Object{$_|ConvertFrom-Json})
    $singleStart=$events|Where-Object{$_.event-eq'single_start'}|Select-Object -First 1
    if($singleStart){break}
  }
  Start-Sleep -Milliseconds 20
}
if(-not$singleStart){throw 'Stimulus did not enter single_start caret phase'}
Start-Sleep -Milliseconds 80

$freq=[double][Diagnostics.Stopwatch]::Frequency
$pointerStart=[Diagnostics.Stopwatch]::GetTimestamp()
$left=$b.Left+[int]($b.Width*.30);$right=$b.Left+[int]($b.Width*.70);$y=$b.Top+[int]($b.Height*.68)
for($i=0;$i-lt20;$i++){
  $t=$i/19.0;$x=[int]($left+($right-$left)*$t)
  [Windows.Forms.Cursor]::Position=[Drawing.Point]::new($x,$y)
  Start-Sleep -Milliseconds 20
}
$pointerEnd=[Diagnostics.Stopwatch]::GetTimestamp()
Start-Sleep -Milliseconds 450

$vp.Refresh();if(-not$vp.HasExited-and$vp.MainWindowHandle-ne0){[VisualNativeArbSmoke]::PostMessage($vp.MainWindowHandle,0x0010,[IntPtr]::Zero,[IntPtr]::Zero)|Out-Null}
if(-not$vp.WaitForExit(5000)){Stop-Process -Id $vp.Id -Force -ErrorAction SilentlyContinue;throw 'Visual did not close'}
if(-not$sp.HasExited){Stop-Process -Id $sp.Id -Force -ErrorAction SilentlyContinue}

$rows=@(Import-Csv $telemetry|Where-Object{$_.frame-match'^\d+$'})
if(-not$rows.Count){throw 'No Visual telemetry'}
$pointerRows=@($rows|Where-Object{[int64]$_.qpc-ge$pointerStart-and[int64]$_.qpc-le$pointerEnd})
$pointerSelected=@($pointerRows|Where-Object{[int]$_.poi_source-eq5}).Count
$after=@($rows|Where-Object{[int64]$_.qpc-ge$pointerEnd})
$firstNonPointer=$after|Where-Object{[int]$_.poi_source-ne5}|Select-Object -First 1
$firstCaret=$after|Where-Object{[int]$_.poi_source-eq0-or[int]$_.poi_source-eq1-or[int]$_.poi_source-eq2}|Select-Object -First 1
$nonPointerMs=if($firstNonPointer){1000.0*([int64]$firstNonPointer.qpc-$pointerEnd)/$freq}else{$null}
$caretMs=if($firstCaret){1000.0*([int64]$firstCaret.qpc-$pointerEnd)/$freq}else{$null}
$presentFailures=@($rows|Where-Object{[uint64]$_.present_hr-ne0}).Count
$uiaCaretAfter=@($after|Where-Object{[int]$_.uia_caret_present-eq1}).Count
$maxPointerAgeAfter=($after|Select-Object -First 20|Measure-Object -Property pointer_age_ms -Maximum).Maximum
$pass=($presentFailures-eq0-and$pointerRows.Count-gt5-and$pointerSelected-gt0-and$firstCaret-and$caretMs-ge0-and$caretMs-lt300)
$analysis=[ordered]@{frames=$rows.Count;pointer_phase_frames=$pointerRows.Count;pointer_selected_frames=$pointerSelected;first_non_pointer_after_stop_ms=if($nonPointerMs-ne$null){[Math]::Round($nonPointerMs,2)}else{$null};first_semantic_caret_after_stop_ms=if($caretMs-ne$null){[Math]::Round($caretMs,2)}else{$null};uia_caret_present_frames_after_stop=$uiaCaretAfter;max_pointer_age_first_20_after_stop_ms=$maxPointerAgeAfter;present_failures=$presentFailures;pass=$pass}
$analysis|ConvertTo-Json -Depth 4|Out-File (Join-Path $run 'analysis.json') -Encoding utf8
@('# Native pointer/caret arbitration smoke','',"- Frames: $($rows.Count)","- Pointer phase frames / pointer selected: $($pointerRows.Count) / $pointerSelected","- First non-pointer after stop: $([Math]::Round([double]$nonPointerMs,2)) ms","- First semantic caret after stop: $([Math]::Round([double]$caretMs,2)) ms","- UIA-caret-present frames after stop: $uiaCaretAfter","- Present failures: $presentFailures","- Pass: $pass")-join"`r`n"|Out-File (Join-Path $run 'SUMMARY.md') -Encoding utf8
if(-not$pass){throw "Native arbitration smoke failed. See $run"}
Write-Host "Native arbitration smoke complete: $run"
Get-Content (Join-Path $run 'SUMMARY.md')
