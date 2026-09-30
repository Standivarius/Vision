param()
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -TypeDefinition @'
using System;using System.Runtime.InteropServices;
public static class VisualExitSmokeNative { [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h,uint m,IntPtr w,IntPtr l); }
'@ -ErrorAction SilentlyContinue
$repo=Resolve-Path (Join-Path $PSScriptRoot '..');$exe=Join-Path $PSScriptRoot 'build\Release\visual_app.exe'
$screens=@([Windows.Forms.Screen]::AllScreens);if($screens.Count-lt2){throw 'Requires two displays'}
$run=Join-Path $repo ("lab\benchmarks\integrated_app\runs\$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')__exit_hotkey_smoke");New-Item -ItemType Directory -Force -Path $run|Out-Null
$telemetry=Join-Path $run 'visual_app_telemetry.csv'
$p=Start-Process $exe -ArgumentList @('--zoom','2','--log',$telemetry) -PassThru
$deadline=(Get-Date).AddSeconds(5);while((Get-Date)-lt$deadline -and $p.MainWindowHandle-eq0){Start-Sleep -Milliseconds 100;$p.Refresh()}
if($p.HasExited){throw 'Visual exited before exit-hotkey test'}
Start-Sleep -Milliseconds 500
$w=New-Object -ComObject WScript.Shell;$w.SendKeys('^%q')
$closed=$p.WaitForExit(4000)
if(-not$closed){$p.Refresh();if(-not$p.HasExited -and $p.MainWindowHandle-ne0){[VisualExitSmokeNative]::PostMessage($p.MainWindowHandle,0x0010,[IntPtr]::Zero,[IntPtr]::Zero)|Out-Null};$p.WaitForExit(3000)|Out-Null;throw 'Ctrl+Alt+Q did not close Visual'}
@('# Visual exit-hotkey smoke','',"- Ctrl+Alt+Q closed app: $closed")-join"`r`n"|Set-Content -Encoding UTF8 (Join-Path $run 'SUMMARY.md')
Write-Host "Exit-hotkey smoke complete: $run";Get-Content (Join-Path $run 'SUMMARY.md')
