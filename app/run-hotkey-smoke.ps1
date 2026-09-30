param()
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class VisualHotkeySmokeNative {
 [DllImport("kernel32.dll")] public static extern uint WTSGetActiveConsoleSessionId();
 [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd,uint msg,IntPtr wParam,IntPtr lParam);
}
'@ -ErrorAction SilentlyContinue

$repo=Resolve-Path (Join-Path $PSScriptRoot '..')
$exe=Join-Path $PSScriptRoot 'build\Release\visual_app.exe'
if(-not(Test-Path $exe)){throw "Visual app not built: $exe"}
if([Diagnostics.Process]::GetCurrentProcess().SessionId -ne [VisualHotkeySmokeNative]::WTSGetActiveConsoleSessionId()){throw 'Hotkey smoke requires active console session'}
$screens=@([Windows.Forms.Screen]::AllScreens);if($screens.Count-lt2){throw 'Hotkey smoke requires two displays'}
$primary=$screens|?{$_.Primary}|Select-Object -First 1;$b=$primary.Bounds
$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss';$run=Join-Path $repo ("lab\benchmarks\integrated_app\runs\${stamp}__hotkey_smoke")
New-Item -ItemType Directory -Force -Path $run|Out-Null
$telemetry=Join-Path $run 'visual_app_telemetry.csv'
[Windows.Forms.Cursor]::Position=[Drawing.Point]::new($b.Left+[int]($b.Width/2),$b.Top+[int]($b.Height/2))
$vp=Start-Process $exe -ArgumentList @('--zoom','2','--log',$telemetry) -PassThru
$deadline=(Get-Date).AddSeconds(5);while((Get-Date)-lt$deadline -and $vp.MainWindowHandle-eq0){Start-Sleep -Milliseconds 150;$vp.Refresh()}
if($vp.HasExited){throw 'Visual exited early'}
$w=New-Object -ComObject WScript.Shell
$x1=$b.Left+[int]($b.Width*0.35);$x2=$b.Left+[int]($b.Width*0.65);$y=$b.Top+[int]($b.Height*0.5)
function Pulse([string]$keys,[int]$x){$w.SendKeys($keys);Start-Sleep -Milliseconds 250;[Windows.Forms.Cursor]::Position=[Drawing.Point]::new($x,$y);Start-Sleep -Milliseconds 550}
Pulse '^%4' $x1
Pulse '^%0' $x2
Pulse '^%0' $x1
Pulse '^%t' $x2
Pulse '^%t' $x1
Pulse '^%2' $x2
Start-Sleep -Milliseconds 500
$vp.Refresh();if(-not$vp.HasExited){$w.SendKeys('^%q')}
if(-not$vp.WaitForExit(5000)){Stop-Process -Id $vp.Id -Force -ErrorAction SilentlyContinue;throw 'Vision app did not close through Ctrl+Alt+Q'}
$rows=@(Import-Csv $telemetry|Where-Object{$_.frame-match'^\d+$'});if(-not$rows.Count){throw 'No telemetry frames'}
$zooms=@($rows|%{[int]$_.zoom}|Sort-Object -Unique);$tracking=@($rows|%{[int]$_.tracking}|Sort-Object -Unique)
$presentFailures=@($rows|?{[uint64]$_.present_hr-ne0}).Count
$zoom1=@($rows|?{[int]$_.zoom-eq1}).Count;$zoom2=@($rows|?{[int]$_.zoom-eq2}).Count;$zoom4=@($rows|?{[int]$_.zoom-eq4}).Count
$trackingOff=@($rows|?{[int]$_.tracking-eq0}).Count;$trackingOn=@($rows|?{[int]$_.tracking-eq1}).Count
$pass=($presentFailures-eq0 -and ($zooms -contains 1) -and ($zooms -contains 2) -and ($zooms -contains 4) -and ($tracking -contains 0) -and ($tracking -contains 1))
$analysis=[ordered]@{frames=$rows.Count;present_failures=$presentFailures;zoom_values=$zooms;tracking_values=$tracking;zoom1_frames=$zoom1;zoom2_frames=$zoom2;zoom4_frames=$zoom4;tracking_off_frames=$trackingOff;tracking_on_frames=$trackingOn;pass=$pass}
$analysis|ConvertTo-Json -Depth 4|Set-Content -Encoding UTF8 (Join-Path $run 'analysis.json')
@('# Integrated Visual hotkey smoke','',"- Frames: $($rows.Count)","- Present failures: $presentFailures","- Zoom values observed: $($zooms -join ', ')","- Zoom frame counts 1x/2x/4x: $zoom1 / $zoom2 / $zoom4","- Tracking values observed: $($tracking -join ', ')","- Tracking off/on frames: $trackingOff / $trackingOn","- Pass: $pass")-join"`r`n"|Set-Content -Encoding UTF8 (Join-Path $run 'SUMMARY.md')
if(-not$pass){throw "Hotkey smoke failed. See $run"}
Write-Host "Integrated hotkey smoke complete: $run";Get-Content (Join-Path $run 'SUMMARY.md')
