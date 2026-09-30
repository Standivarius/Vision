param([ValidateRange(1,4)][int]$Zoom=2,[int]$MovementMs=1800)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class VisualPointerStressNative {
  [DllImport("kernel32.dll")] public static extern uint WTSGetActiveConsoleSessionId();
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd,uint msg,IntPtr wParam,IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr value);
}
'@ -ErrorAction SilentlyContinue
[VisualPointerStressNative]::SetProcessDpiAwarenessContext([IntPtr](-4))|Out-Null
$repo=Resolve-Path (Join-Path $PSScriptRoot '..')
$visual=Join-Path $PSScriptRoot 'build\Release\visual_app.exe'
$stimulus=Join-Path $repo 'lab\prototypes\spike3_focus_caret_evidence\build\Release\visual_spike3_stimulus.exe'
if([Diagnostics.Process]::GetCurrentProcess().SessionId-ne[VisualPointerStressNative]::WTSGetActiveConsoleSessionId()){throw 'Pointer stress requires console session'}
$screens=@([Windows.Forms.Screen]::AllScreens);if($screens.Count-lt2){throw 'Pointer stress requires two displays'}
$primary=$screens|Where-Object{$_.Primary}|Select-Object -First 1;$b=$primary.Bounds
$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss';$run=Join-Path $repo ("lab\benchmarks\integrated_app\runs\${stamp}__pointer_stress_smoke")
New-Item -ItemType Directory -Force -Path $run|Out-Null
$scenario=Join-Path $run 'scenario_events.jsonl';$telemetry=Join-Path $run 'visual_app_telemetry.csv';$commands=Join-Path $run 'pointer_commands.csv'
$sp=Start-Process $stimulus -ArgumentList @($scenario) -PassThru
$deadline=(Get-Date).AddSeconds(5);while((Get-Date)-lt$deadline-and$sp.MainWindowHandle-eq0){Start-Sleep -Milliseconds 50;$sp.Refresh()}
$vp=Start-Process $visual -ArgumentList @('--zoom',[string]$Zoom,'--log',$telemetry) -PassThru
$deadline=(Get-Date).AddSeconds(5);while((Get-Date)-lt$deadline-and$vp.MainWindowHandle-eq0){Start-Sleep -Milliseconds 50;$vp.Refresh()}
if($vp.HasExited-or$sp.HasExited){throw 'Visual or stimulus exited early'}
Start-Sleep -Milliseconds 700
$freq=[double][Diagnostics.Stopwatch]::Frequency
$left=$b.Left+[int]($b.Width*.18);$right=$b.Left+[int]($b.Width*.82);$top=$b.Top+[int]($b.Height*.28);$bottom=$b.Top+[int]($b.Height*.72)
$cmd=New-Object Collections.Generic.List[object]
$start=[Diagnostics.Stopwatch]::GetTimestamp();$deadlineQpc=$start+[int64]($MovementMs*$freq/1000.0);$i=0
while([Diagnostics.Stopwatch]::GetTimestamp()-lt$deadlineQpc){
  $phase=($i%120)/119.0;if((([int]($i/120))%2)-eq1){$phase=1.0-$phase}
  $x=[int]($left+($right-$left)*$phase);$wave=[Math]::Sin($i*.19);$y=[int](($top+$bottom)/2+($bottom-$top)*.45*$wave)
  [VisualPointerStressNative]::SetCursorPos($x,$y)|Out-Null
  $q=[Diagnostics.Stopwatch]::GetTimestamp();$cmd.Add([pscustomobject]@{qpc=$q;x=$x;y=$y})
  $i++;Start-Sleep -Milliseconds 5
}
$end=[Diagnostics.Stopwatch]::GetTimestamp();$cmd|Export-Csv -NoTypeInformation $commands
Start-Sleep -Milliseconds 450
$vp.Refresh();if(-not$vp.HasExited){[VisualPointerStressNative]::PostMessage($vp.MainWindowHandle,0x0010,[IntPtr]::Zero,[IntPtr]::Zero)|Out-Null}
$vp.WaitForExit(5000)|Out-Null;if(-not$sp.HasExited){Stop-Process -Id $sp.Id -Force -ErrorAction SilentlyContinue}
$rows=@(Import-Csv $telemetry|Where-Object{$_.frame-match'^\d+$'});$motion=@($rows|Where-Object{[int64]$_.qpc-ge$start-and[int64]$_.qpc-le$end-and[int]$_.poi_source-eq5})
if($motion.Count-lt10){throw "Too few pointer-selected frames: $($motion.Count)"}
$errors=New-Object Collections.Generic.List[double];$ages=New-Object Collections.Generic.List[double];$ci=0
foreach($r in $motion){$rq=[int64]$r.qpc;while($ci+1-lt$cmd.Count-and[int64]$cmd[$ci+1].qpc-le$rq){$ci++};$dx=[double]$r.selected_left-[double]$cmd[$ci].x;$dy=[double]$r.selected_top-[double]$cmd[$ci].y;$errors.Add([Math]::Sqrt($dx*$dx+$dy*$dy));$ages.Add([double]$r.pointer_age_ms)}
function Pct([double[]]$v,[double]$p){$s=@($v|Sort-Object);$s[[Math]::Min($s.Count-1,[Math]::Floor(($s.Count-1)*$p))]}
$errP95=Pct $errors.ToArray() .95;$errMax=($errors|Measure-Object -Maximum).Maximum;$ageP95=Pct $ages.ToArray() .95;$ageMax=($ages|Measure-Object -Maximum).Maximum
$after=@($rows|Where-Object{[int64]$_.qpc-ge$end});$firstCaret=$after|Where-Object{[int]$_.poi_source-eq0-or[int]$_.poi_source-eq1-or[int]$_.poi_source-eq2}|Select-Object -First 1
$handoff=if($firstCaret){1000.0*([int64]$firstCaret.qpc-$end)/$freq}else{$null};$fail=@($rows|Where-Object{[uint64]$_.present_hr-ne0}).Count
$pass=($fail-eq0-and$motion.Count-ge50-and$errP95-le45-and$ageP95-le35-and$firstCaret-and$handoff-lt300)
$a=[ordered]@{primary_width=$b.Width;primary_height=$b.Height;command_samples=$cmd.Count;pointer_selected_frames=$motion.Count;position_error_p95_px=[Math]::Round($errP95,2);position_error_max_px=[Math]::Round($errMax,2);pointer_age_p95_ms=[Math]::Round($ageP95,2);pointer_age_max_ms=[Math]::Round($ageMax,2);caret_handoff_ms=if($handoff-ne$null){[Math]::Round($handoff,2)}else{$null};present_failures=$fail;pass=$pass}
$a|ConvertTo-Json -Depth 4|Out-File (Join-Path $run 'analysis.json') -Encoding utf8
@('# Fast pointer stress smoke','',"- PMv2 primary: $($b.Width)x$($b.Height)","- Command samples: $($cmd.Count)","- Pointer-selected frames: $($motion.Count)","- Position error p95 / max: $([Math]::Round($errP95,2)) / $([Math]::Round($errMax,2)) px","- Pointer age p95 / max: $([Math]::Round($ageP95,2)) / $([Math]::Round($ageMax,2)) ms","- Caret handoff after stop: $([Math]::Round([double]$handoff,2)) ms","- Present failures: $fail","- Pass: $pass")-join"`r`n"|Out-File (Join-Path $run 'SUMMARY.md') -Encoding utf8
if(-not$pass){throw "Pointer stress failed: $run"}
Write-Host "Pointer stress complete: $run";Get-Content (Join-Path $run 'SUMMARY.md')
