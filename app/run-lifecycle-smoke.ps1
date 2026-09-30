param()
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class VisualLifecycleSmokeNative {
 [DllImport("kernel32.dll")] public static extern uint WTSGetActiveConsoleSessionId();
 [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd,uint msg,IntPtr wParam,IntPtr lParam);
}
'@ -ErrorAction SilentlyContinue

$repo=Resolve-Path (Join-Path $PSScriptRoot '..')
$exe=Join-Path $PSScriptRoot 'build\Release\visual_app.exe'
if(-not(Test-Path $exe)){throw "Visual app not built: $exe"}
if([Diagnostics.Process]::GetCurrentProcess().SessionId-ne[VisualLifecycleSmokeNative]::WTSGetActiveConsoleSessionId()){throw 'Lifecycle smoke requires active console session'}
$screens=@([Windows.Forms.Screen]::AllScreens);if($screens.Count-lt2){throw 'Lifecycle smoke requires two displays'}

$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$run=Join-Path $repo ("lab\benchmarks\integrated_app\runs\${stamp}__lifecycle_smoke")
New-Item -ItemType Directory -Force -Path $run|Out-Null
$telemetry=Join-Path $run 'visual_app_telemetry.csv'
$vp=Start-Process $exe -ArgumentList @('--zoom','2','--log',$telemetry) -PassThru
$deadline=(Get-Date).AddSeconds(5);while((Get-Date)-lt$deadline-and$vp.MainWindowHandle-eq0){Start-Sleep -Milliseconds 100;$vp.Refresh()}
if($vp.HasExited){throw "Visual exited early: $($vp.ExitCode)"}
Start-Sleep -Milliseconds 400

# WM_DISPLAYCHANGE = 0x007E. This validates the safe topology-invalidation path without changing hardware.
[VisualLifecycleSmokeNative]::PostMessage($vp.MainWindowHandle,0x007E,[IntPtr]::Zero,[IntPtr]::Zero)|Out-Null
if(-not$vp.WaitForExit(5000)){Stop-Process -Id $vp.Id -Force -ErrorAction SilentlyContinue;throw 'Visual did not exit after synthetic display change'}
$vp.Refresh()
$raw=if(Test-Path $telemetry){Get-Content -Raw $telemetry}else{''}
$hasEvent=$raw -match '# event=shutdown_display_topology_changed'
$frameLines=@(Get-Content $telemetry|Where-Object{$_ -and -not$_.StartsWith('#')})
$frames=[Math]::Max(0,$frameLines.Count-1)
$pass=($vp.ExitCode-eq12-and$hasEvent-and$frames-gt0)
$analysis=[ordered]@{visual_exit=$vp.ExitCode;frames=$frames;shutdown_event_present=$hasEvent;pass=$pass}
$analysis|ConvertTo-Json -Depth 3|Set-Content -Encoding UTF8 (Join-Path $run 'analysis.json')
@('# Integrated Visual lifecycle smoke','',"- Visual exit code: $($vp.ExitCode)","- Frames before topology event: $frames","- Topology shutdown telemetry present: $hasEvent","- Pass: $pass")-join"`r`n"|Set-Content -Encoding UTF8 (Join-Path $run 'SUMMARY.md')
if(-not$pass){throw "Lifecycle smoke failed. See $run"}
Write-Host "Integrated lifecycle smoke complete: $run";Get-Content (Join-Path $run 'SUMMARY.md')
