param([ValidateRange(1,4)][int]$Zoom=2)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;using System.Runtime.InteropServices;
public static class VisualNativeFallbackSmoke {
 [DllImport("kernel32.dll")] public static extern uint WTSGetActiveConsoleSessionId();
 [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h,uint m,IntPtr w,IntPtr l);
 [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h,IntPtr a,int x,int y,int cx,int cy,uint f);
}
'@ -ErrorAction SilentlyContinue
$repo=Resolve-Path (Join-Path $PSScriptRoot '..')
$visual=Join-Path $PSScriptRoot 'build\Release\visual_app.exe'
$stimulus=Join-Path $repo 'lab\prototypes\spike3_focus_caret_evidence\build\Release\visual_spike3_stimulus.exe'
if(-not(Test-Path $visual)){throw 'Visual app missing'}
if(-not(Test-Path $stimulus)){throw 'Spike 3 stimulus missing'}
if([Diagnostics.Process]::GetCurrentProcess().SessionId-ne[VisualNativeFallbackSmoke]::WTSGetActiveConsoleSessionId()){throw 'Requires active console session'}
$screens=@([Windows.Forms.Screen]::AllScreens);if($screens.Count-lt2){throw 'Requires two displays'}
$primary=$screens|?{$_.Primary}|Select-Object -First 1;$b=$primary.Bounds
$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss';$run=Join-Path $repo ("lab\benchmarks\integrated_app\runs\${stamp}__native_fallback_smoke")
New-Item -ItemType Directory -Force -Path $run|Out-Null
$scenario=Join-Path $run 'scenario_events.jsonl';$telemetry=Join-Path $run 'visual_app_telemetry.csv'
[Windows.Forms.Cursor]::Position=[Drawing.Point]::new($b.Left+[int]($b.Width/2),$b.Top+[int]($b.Height/2))
$sp=Start-Process $stimulus -ArgumentList @($scenario) -PassThru
$deadline=(Get-Date).AddSeconds(5);while((Get-Date)-lt$deadline -and $sp.MainWindowHandle-eq0){Start-Sleep -Milliseconds 100;$sp.Refresh()}
if($sp.MainWindowHandle-ne0){[VisualNativeFallbackSmoke]::SetWindowPos($sp.MainWindowHandle,[IntPtr]::Zero,$b.Left+120,$b.Top+100,700,430,0x0040)|Out-Null}
Start-Sleep -Milliseconds 250
$vp=Start-Process $visual -ArgumentList @('--zoom',[string]$Zoom,'--log',$telemetry) -PassThru
$deadline=(Get-Date).AddSeconds(5);while((Get-Date)-lt$deadline -and $vp.MainWindowHandle-eq0){Start-Sleep -Milliseconds 100;$vp.Refresh()}
if($vp.HasExited){throw 'Visual exited early'}
$sp.WaitForExit()
Start-Sleep -Milliseconds 500
$vp.Refresh();if(-not$vp.HasExited -and $vp.MainWindowHandle-ne0){[VisualNativeFallbackSmoke]::PostMessage($vp.MainWindowHandle,0x0010,[IntPtr]::Zero,[IntPtr]::Zero)|Out-Null}
if(-not$vp.WaitForExit(5000)){Stop-Process -Id $vp.Id -Force -ErrorAction SilentlyContinue;throw 'Visual did not close'}
$rows=@(Import-Csv $telemetry);if(-not$rows.Count){throw 'No telemetry'}
$counts=@{};foreach($source in 0..5){$counts[$source]=@($rows|?{[int]$_.poi_source-eq$source}).Count}
$fail=@($rows|?{[uint64]$_.present_hr-ne0}).Count
$invalid=@($rows|?{[int]$_.viewport_action-eq0}).Count
$pass=($fail-eq0 -and $counts[2]-gt0 -and $counts[3]-gt0 -and $invalid-eq0)
$analysis=[ordered]@{frames=$rows.Count;present_failures=$fail;uia_text2=$counts[0];uia_selection=$counts[1];win32_caret=$counts[2];uia_focus=$counts[3];win32_focus=$counts[4];pointer=$counts[5];invalid_viewport=$invalid;pass=$pass}
$analysis|ConvertTo-Json -Depth 4|Set-Content -Encoding UTF8 (Join-Path $run 'analysis.json')
@('# Integrated native fallback smoke','',"- Frames: $($rows.Count)","- Present failures: $fail","- UIA Text2 / UIA selection / Win32 caret: $($counts[0]) / $($counts[1]) / $($counts[2])","- UIA focus / Win32 focus / pointer: $($counts[3]) / $($counts[4]) / $($counts[5])","- Invalid viewport decisions: $invalid","- Pass: $pass")-join"`r`n"|Set-Content -Encoding UTF8 (Join-Path $run 'SUMMARY.md')
if(-not$pass){throw "Native fallback smoke failed. See $run"}
Write-Host "Integrated native fallback smoke complete: $run";Get-Content (Join-Path $run 'SUMMARY.md')
