param()
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class VisualPostReconnectNative {
  [DllImport("kernel32.dll")] public static extern uint WTSGetActiveConsoleSessionId();
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd,uint msg,IntPtr wParam,IntPtr lParam);
}
'@ -ErrorAction SilentlyContinue

$repo=Resolve-Path (Join-Path $PSScriptRoot '..')
$exe=Join-Path $PSScriptRoot 'build\Release\visual_app.exe'
if(-not(Test-Path $exe)){throw "Visual app not built: $exe"}
if([Diagnostics.Process]::GetCurrentProcess().SessionId-ne[VisualPostReconnectNative]::WTSGetActiveConsoleSessionId()){throw 'Relaunch smoke requires active console session'}
$screens=@([Windows.Forms.Screen]::AllScreens)
if($screens.Count-lt2){throw "Relaunch smoke requires two displays; found $($screens.Count)"}

$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$run=Join-Path $repo ("lab\benchmarks\integrated_app\runs\${stamp}__post_reconnect_relaunch")
New-Item -ItemType Directory -Force -Path $run|Out-Null
$telemetry=Join-Path $run 'visual_app_telemetry.csv'
$vp=Start-Process $exe -ArgumentList @('--zoom','2','--log',$telemetry) -PassThru
$deadline=(Get-Date).AddSeconds(5)
while((Get-Date)-lt$deadline-and$vp.MainWindowHandle-eq0-and-not$vp.HasExited){Start-Sleep -Milliseconds 100;$vp.Refresh()}
if($vp.HasExited){throw "Visual exited early: $($vp.ExitCode)"}
Start-Sleep -Milliseconds 2200
$vp.Refresh()
if(-not$vp.HasExited-and$vp.MainWindowHandle-ne0){[VisualPostReconnectNative]::PostMessage($vp.MainWindowHandle,0x0010,[IntPtr]::Zero,[IntPtr]::Zero)|Out-Null}
if(-not$vp.WaitForExit(5000)){Stop-Process -Id $vp.Id -Force -ErrorAction SilentlyContinue;throw 'Visual did not close after relaunch smoke'}
$vp.Refresh()
$rows=@(Import-Csv $telemetry -ErrorAction SilentlyContinue)
$fail=@($rows|Where-Object{[uint64]$_.present_hr-ne0}).Count
$pass=($vp.ExitCode-eq0-and$rows.Count-gt0-and$fail-eq0)
$analysis=[ordered]@{visual_exit=$vp.ExitCode;frames=$rows.Count;present_failures=$fail;display_count=$screens.Count;pass=$pass}
$analysis|ConvertTo-Json -Depth 3|Set-Content -Encoding UTF8 (Join-Path $run 'analysis.json')
@('# Post-reconnect Visual relaunch smoke','',"- Displays: $($screens.Count)","- Visual exit: $($vp.ExitCode)","- Frames: $($rows.Count)","- Present failures: $fail","- Pass: $pass")-join"`r`n"|Set-Content -Encoding UTF8 (Join-Path $run 'SUMMARY.md')
if(-not$pass){throw "Post-reconnect relaunch smoke failed. See $run"}
Write-Host "Post-reconnect relaunch smoke complete: $run";Get-Content (Join-Path $run 'SUMMARY.md')
