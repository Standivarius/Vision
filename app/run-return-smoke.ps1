param()
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class VisualReturnSmokeNative {
 [DllImport("kernel32.dll")] public static extern uint WTSGetActiveConsoleSessionId();
 [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd,uint msg,IntPtr wParam,IntPtr lParam);
}
'@ -ErrorAction SilentlyContinue

$repo=Resolve-Path (Join-Path $PSScriptRoot '..')
$exe=Join-Path $PSScriptRoot 'build\Release\visual_app.exe'
if(-not(Test-Path $exe)){throw "Visual app not built: $exe"}
if([Diagnostics.Process]::GetCurrentProcess().SessionId-ne[VisualReturnSmokeNative]::WTSGetActiveConsoleSessionId()){throw 'Return smoke requires active console session'}
$screens=@([Windows.Forms.Screen]::AllScreens);if($screens.Count-lt2){throw 'Return smoke requires two displays'}
$primary=$screens|Where-Object{$_.Primary}|Select-Object -First 1;$b=$primary.Bounds
$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$run=Join-Path $repo ("lab\benchmarks\integrated_app\runs\${stamp}__return_smoke")
New-Item -ItemType Directory -Force -Path $run|Out-Null
$telemetry=Join-Path $run 'visual_app_telemetry.csv'

# Start from a deliberately off-center location so exact return is measurable.
$x=$b.Left+[int]($b.Width*0.73);$y=$b.Top+[int]($b.Height*0.61)
[Windows.Forms.Cursor]::Position=[Drawing.Point]::new($x,$y)
$vp=Start-Process $exe -ArgumentList @('--zoom','2','--log',$telemetry) -PassThru
$deadline=(Get-Date).AddSeconds(5);while((Get-Date)-lt$deadline-and$vp.MainWindowHandle-eq0){Start-Sleep -Milliseconds 100;$vp.Refresh()}
if($vp.HasExited){throw 'Visual exited early'}
# Do not race the first Ctrl+Alt+0 against WGC/render startup. The exact-return
# oracle requires an actual rendered 2x "before" frame, not merely a live HWND.
$renderDeadline=(Get-Date).AddSeconds(5)
$beforeReady=$false
while((Get-Date)-lt$renderDeadline){
  if(Test-Path $telemetry){
    $seed=@(Import-Csv $telemetry -ErrorAction SilentlyContinue|Where-Object{$_.frame-match'^\d+$'-and[int]$_.zoom-eq2}|Select-Object -First 1)
    if($seed){$beforeReady=$true;break}
  }
  $vp.Refresh();if($vp.HasExited){break};Start-Sleep -Milliseconds 100
}
if(-not$beforeReady){throw "Visual did not render an initial 2x frame. See $run"}
Start-Sleep -Milliseconds 150

$w=New-Object -ComObject WScript.Shell
$enterNormalQpc=[Diagnostics.Stopwatch]::GetTimestamp()
$w.SendKeys('^%0')
Start-Sleep -Milliseconds 650
$returnQpc=[Diagnostics.Stopwatch]::GetTimestamp()
$w.SendKeys('^%0')
Start-Sleep -Milliseconds 450

$vp.Refresh();if(-not$vp.HasExited){$w.SendKeys('^%q')}
if(-not$vp.WaitForExit(5000)){Stop-Process -Id $vp.Id -Force -ErrorAction SilentlyContinue;throw 'Vision did not close through Ctrl+Alt+Q'}

$rows=@(Import-Csv $telemetry|Where-Object{$_.frame-match'^\d+$'});if(-not$rows.Count){throw 'No telemetry frames'}
$before=@($rows|Where-Object{[int64]$_.qpc-lt$enterNormalQpc-and[int]$_.zoom-eq2}|Select-Object -Last 1)
$normal=@($rows|Where-Object{[int64]$_.qpc-ge$enterNormalQpc-and[int64]$_.qpc-lt$returnQpc-and[int]$_.zoom-eq1})
$after=@($rows|Where-Object{[int64]$_.qpc-ge$returnQpc-and[int]$_.zoom-eq2}|Select-Object -First 1)
if(-not$before-or-not$after-or$normal.Count-eq0){throw "Could not identify before/normal/after telemetry phases. See $run"}

function D([string]$v){return [double]::Parse($v,[Globalization.CultureInfo]::InvariantCulture)}
$coords=@('view_left','view_top','view_right','view_bottom')
$maxDelta=0.0
foreach($c in $coords){$d=[math]::Abs((D $before.$c)-(D $after.$c));if($d-gt$maxDelta){$maxDelta=$d}}

# Do not use PowerShell/WinForms screen geometry as coordinate truth here: this process can be DPI-virtualized.
# Instead, verify that Visual's 1x viewport is stable and exactly twice the 2x viewport dimensions.
$normalRef=$normal[0]
$beforeWidth=(D $before.view_right)-(D $before.view_left)
$beforeHeight=(D $before.view_bottom)-(D $before.view_top)
$normalWidth=(D $normalRef.view_right)-(D $normalRef.view_left)
$normalHeight=(D $normalRef.view_bottom)-(D $normalRef.view_top)
$normalScaleCorrect=([math]::Abs($normalWidth-(2.0*$beforeWidth))-lt0.01-and[math]::Abs($normalHeight-(2.0*$beforeHeight))-lt0.01)
$normalStable=0
foreach($r in $normal){
  $rowDelta=0.0
  foreach($c in $coords){$d=[math]::Abs((D $r.$c)-(D $normalRef.$c));if($d-gt$rowDelta){$rowDelta=$d}}
  if($rowDelta-lt0.01){$normalStable++}
}
$fail=@($rows|Where-Object{[uint64]$_.present_hr-ne0}).Count
$invalid=@($rows|Where-Object{[int]$_.viewport_action-eq0}).Count
$pass=($fail-eq0-and$invalid-eq0-and$normalScaleCorrect-and$normalStable-eq$normal.Count-and$maxDelta-lt0.01)
$analysis=[ordered]@{frames=$rows.Count;present_failures=$fail;invalid_frames=$invalid;normal_frames=$normal.Count;normal_stable_frames=$normalStable;normal_dimensions_match_1x_from_2x=$normalScaleCorrect;return_max_coordinate_delta_px=[math]::Round($maxDelta,6);before_view=@((D $before.view_left),(D $before.view_top),(D $before.view_right),(D $before.view_bottom));normal_view=@((D $normalRef.view_left),(D $normalRef.view_top),(D $normalRef.view_right),(D $normalRef.view_bottom));after_view=@((D $after.view_left),(D $after.view_top),(D $after.view_right),(D $after.view_bottom));pass=$pass}
$analysis|ConvertTo-Json -Depth 5|Set-Content -Encoding UTF8 (Join-Path $run 'analysis.json')
@('# Integrated Visual exact-return smoke','',"- Frames: $($rows.Count)","- Present failures: $fail","- 1x frames / stable 1x frames: $($normal.Count) / $normalStable","- 1x dimensions correctly derived from 2x viewport: $normalScaleCorrect","- Return maximum viewport-coordinate delta: $([math]::Round($maxDelta,6)) px","- Invalid viewport decisions: $invalid","- Pass: $pass")-join"`r`n"|Set-Content -Encoding UTF8 (Join-Path $run 'SUMMARY.md')
if(-not$pass){throw "Exact-return smoke failed. See $run"}
Write-Host "Integrated exact-return smoke complete: $run";Get-Content (Join-Path $run 'SUMMARY.md')
