param([ValidateRange(1,4)][int]$Zoom=2)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class VisualArbitrationSmokeNative {
  [DllImport("kernel32.dll")] public static extern uint WTSGetActiveConsoleSessionId();
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd,uint msg,IntPtr wParam,IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd,IntPtr after,int x,int y,int cx,int cy,uint flags);
}
'@ -ErrorAction SilentlyContinue

$repo=Resolve-Path (Join-Path $PSScriptRoot '..')
$exe=Join-Path $PSScriptRoot 'build\Release\visual_app.exe'
if(-not(Test-Path $exe)){throw "Visual app not built: $exe"}
if([Diagnostics.Process]::GetCurrentProcess().SessionId-ne[VisualArbitrationSmokeNative]::WTSGetActiveConsoleSessionId()){throw 'Arbitration smoke requires active console session'}
$screens=@([Windows.Forms.Screen]::AllScreens);if($screens.Count-lt2){throw 'Arbitration smoke requires two displays'}
$primary=$screens|Where-Object{$_.Primary}|Select-Object -First 1;$b=$primary.Bounds

$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$run=Join-Path $repo ("lab\benchmarks\integrated_app\runs\${stamp}__arbitration_smoke")
New-Item -ItemType Directory -Force -Path $run|Out-Null
$fixture=Join-Path $run 'arbitration_fixture.txt'
@(
 'Visual pointer versus caret arbitration test.',
 'The caret remains active while the pointer deliberately moves across the source display.',
 'After pointer movement stops, semantic caret tracking should resume automatically.'
)|Set-Content -Encoding UTF8 $fixture

$before=@(Get-Process Notepad -ErrorAction SilentlyContinue|ForEach-Object{$_.Id})
Start-Process notepad.exe -ArgumentList @($fixture)|Out-Null
$deadline=(Get-Date).AddSeconds(10);$np=$null
while((Get-Date)-lt$deadline){
 Start-Sleep -Milliseconds 150
 $c=@(Get-Process Notepad -ErrorAction SilentlyContinue|Where-Object{$_.MainWindowHandle-ne0-and$before-notcontains$_.Id}|Sort-Object StartTime -Descending)
 if($c.Count){$np=$c|Select-Object -First 1;break}
}
if(-not$np){throw 'Notepad test window not found'}
[VisualArbitrationSmokeNative]::SetWindowPos($np.MainWindowHandle,[IntPtr]::Zero,$b.Left+100,$b.Top+90,[Math]::Min(1050,$b.Width-200),[Math]::Min(650,$b.Height-180),0x0040)|Out-Null
[VisualArbitrationSmokeNative]::SetForegroundWindow($np.MainWindowHandle)|Out-Null
$w=New-Object -ComObject WScript.Shell
$w.SendKeys('^{HOME}');Start-Sleep -Milliseconds 300

$telemetry=Join-Path $run 'visual_app_telemetry.csv'
$vp=Start-Process $exe -ArgumentList @('--zoom',[string]$Zoom,'--log',$telemetry) -PassThru
$deadline=(Get-Date).AddSeconds(5);while((Get-Date)-lt$deadline-and$vp.MainWindowHandle-eq0){Start-Sleep -Milliseconds 100;$vp.Refresh()}
if($vp.HasExited){throw 'Visual exited early'}
Start-Sleep -Milliseconds 500

$freq=[Diagnostics.Stopwatch]::Frequency
$pointerStart=[Diagnostics.Stopwatch]::GetTimestamp()
$left=$b.Left+[int]($b.Width*0.25);$right=$b.Left+[int]($b.Width*0.75);$y=$b.Top+[int]($b.Height*0.72)
for($i=0;$i-lt30;$i++){
  $t=$i/29.0
  $x=[int]($left+($right-$left)*$t)
  [Windows.Forms.Cursor]::Position=[Drawing.Point]::new($x,$y)
  Start-Sleep -Milliseconds 45
}
$pointerEnd=[Diagnostics.Stopwatch]::GetTimestamp()

# Stop moving the pointer, let its short freshness window expire, then move the text caret.
Start-Sleep -Milliseconds 250
$caretPhaseStart=[Diagnostics.Stopwatch]::GetTimestamp()
[VisualArbitrationSmokeNative]::SetForegroundWindow($np.MainWindowHandle)|Out-Null
foreach($k in @('{END}','{DOWN}','{RIGHT 18}','{DOWN}','{END}','^{HOME}')){ $w.SendKeys($k); Start-Sleep -Milliseconds 250 }
$caretPhaseEnd=[Diagnostics.Stopwatch]::GetTimestamp()
Start-Sleep -Milliseconds 250

$vp.Refresh();if(-not$vp.HasExited-and$vp.MainWindowHandle-ne0){[VisualArbitrationSmokeNative]::PostMessage($vp.MainWindowHandle,0x0010,[IntPtr]::Zero,[IntPtr]::Zero)|Out-Null}
if(-not$vp.WaitForExit(5000)){Stop-Process -Id $vp.Id -Force -ErrorAction SilentlyContinue;throw 'Visual did not close'}
[VisualArbitrationSmokeNative]::PostMessage($np.MainWindowHandle,0x0010,[IntPtr]::Zero,[IntPtr]::Zero)|Out-Null

$rows=@(Import-Csv $telemetry);if(-not$rows.Count){throw 'No telemetry'}
$pointerRows=@($rows|Where-Object{[int64]$_.qpc-ge$pointerStart-and[int64]$_.qpc-le$pointerEnd})
$caretRows=@($rows|Where-Object{[int64]$_.qpc-ge$caretPhaseStart-and[int64]$_.qpc-le$caretPhaseEnd})
$pointerSelected=@($pointerRows|Where-Object{[int]$_.poi_source-eq5}).Count
$semanticDuringPointer=@($pointerRows|Where-Object{[int]$_.poi_source-eq0-or[int]$_.poi_source-eq1-or[int]$_.poi_source-eq2}).Count
$semanticDuringCaret=@($caretRows|Where-Object{[int]$_.poi_source-eq0-or[int]$_.poi_source-eq1-or[int]$_.poi_source-eq2}).Count
$pointerDuringCaret=@($caretRows|Where-Object{[int]$_.poi_source-eq5}).Count
$firstSemanticAfter=@($rows|Where-Object{[int64]$_.qpc-ge$pointerEnd-and([int]$_.poi_source-eq0-or[int]$_.poi_source-eq1-or[int]$_.poi_source-eq2)}|Select-Object -First 1)
$resumeMs=$null
if($firstSemanticAfter){$resumeMs=[math]::Round(1000.0*([int64]$firstSemanticAfter.qpc-$pointerEnd)/$freq,1)}
$presentFailures=@($rows|Where-Object{[uint64]$_.present_hr-ne0}).Count
$invalid=@($rows|Where-Object{[int]$_.viewport_action-eq0}).Count
$locator=@($rows|Where-Object{[int]$_.locator_visible-eq1}).Count
$pass=($presentFailures-eq0-and$pointerRows.Count-gt0-and$caretRows.Count-gt0-and$pointerSelected-gt0-and$semanticDuringCaret-gt0-and$invalid-eq0)
$analysis=[ordered]@{
 frames=$rows.Count;present_failures=$presentFailures;pointer_phase_frames=$pointerRows.Count;pointer_selected_frames=$pointerSelected;semantic_caret_frames_during_pointer_phase=$semanticDuringPointer;caret_phase_frames=$caretRows.Count;semantic_caret_frames_during_caret_phase=$semanticDuringCaret;pointer_frames_during_caret_phase=$pointerDuringCaret;caret_resume_after_pointer_stop_ms=$resumeMs;locator_visible_frames=$locator;invalid_frames=$invalid;pass=$pass
}
$analysis|ConvertTo-Json -Depth 4|Set-Content -Encoding UTF8 (Join-Path $run 'analysis.json')
@('# Integrated Visual pointer/caret arbitration smoke','',"- Frames: $($rows.Count)","- Present failures: $presentFailures","- Pointer phase frames / pointer-selected: $($pointerRows.Count) / $pointerSelected","- Semantic caret frames during pointer phase: $semanticDuringPointer","- Caret phase frames / semantic-caret selected: $($caretRows.Count) / $semanticDuringCaret","- Pointer frames during caret phase: $pointerDuringCaret","- Caret resume after pointer stop: $resumeMs ms","- Locator-visible frames: $locator","- Invalid viewport decisions: $invalid","- Pass: $pass")-join"`r`n"|Set-Content -Encoding UTF8 (Join-Path $run 'SUMMARY.md')
if(-not$pass){throw "Arbitration smoke failed. See $run"}
Write-Host "Integrated arbitration smoke complete: $run";Get-Content (Join-Path $run 'SUMMARY.md')
