param([ValidateRange(1,4)][int]$Zoom=2)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class VisualCaretSmokeNative {
  [DllImport("kernel32.dll")] public static extern uint WTSGetActiveConsoleSessionId();
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd,uint msg,IntPtr wParam,IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd,IntPtr after,int x,int y,int cx,int cy,uint flags);
}
'@ -ErrorAction SilentlyContinue

$repo=Resolve-Path (Join-Path $PSScriptRoot '..')
$exe=Join-Path $PSScriptRoot 'build\Release\visual_app.exe'
if(-not(Test-Path $exe)){throw "Visual app not built: $exe"}
$processSession=[Diagnostics.Process]::GetCurrentProcess().SessionId
$consoleSession=[VisualCaretSmokeNative]::WTSGetActiveConsoleSessionId()
if($processSession-ne$consoleSession){throw "Physical smoke requires active console session. Process=$processSession Console=$consoleSession"}
$screens=@([Windows.Forms.Screen]::AllScreens);if($screens.Count-lt2){throw "Need two displays; found $($screens.Count)"}
$primary=$screens|?{$_.Primary}|Select-Object -First 1

$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$run=Join-Path $repo ("lab\benchmarks\integrated_app\runs\${stamp}__caret_smoke")
New-Item -ItemType Directory -Force -Path $run|Out-Null
$fixture=Join-Path $run 'caret_fixture.txt'
@(
 'Visual integrated caret tracking smoke test.',
 'The second line is deliberately long enough to move the caret across the magnified viewport and exercise the comfort margins.',
 'The third line provides another vertical target for viewport movement.'
)|Set-Content -Encoding UTF8 $fixture

$before=@(Get-Process Notepad -ErrorAction SilentlyContinue|%{$_.Id})
Start-Process notepad.exe -ArgumentList @($fixture)|Out-Null
$deadline=(Get-Date).AddSeconds(10);$np=$null
while((Get-Date)-lt$deadline){
 Start-Sleep -Milliseconds 200
 $c=@(Get-Process Notepad -ErrorAction SilentlyContinue|?{$_.MainWindowHandle-ne0 -and $before -notcontains $_.Id}|Sort-Object StartTime -Descending)
 if($c.Count){$np=$c|Select-Object -First 1;break}
}
if(-not$np){throw 'Notepad test window not found'}
$b=$primary.Bounds
[VisualCaretSmokeNative]::SetWindowPos($np.MainWindowHandle,[IntPtr]::Zero,$b.Left+80,$b.Top+80,[Math]::Min(1100,$b.Width-160),[Math]::Min(700,$b.Height-160),0x0040)|Out-Null
[VisualCaretSmokeNative]::SetForegroundWindow($np.MainWindowHandle)|Out-Null
[Windows.Forms.Cursor]::Position=[Drawing.Point]::new($b.Left+$b.Width/2,$b.Top+$b.Height/2)
Start-Sleep -Milliseconds 500

$telemetry=Join-Path $run 'visual_app_telemetry.csv'
$vp=Start-Process $exe -ArgumentList @('--zoom',[string]$Zoom,'--log',$telemetry) -PassThru
$deadline=(Get-Date).AddSeconds(6)
while((Get-Date)-lt$deadline -and $vp.MainWindowHandle-eq0){Start-Sleep -Milliseconds 150;$vp.Refresh()}
if($vp.HasExited){throw 'Visual app exited early'}
Start-Sleep -Milliseconds 800

$w=New-Object -ComObject WScript.Shell
$keys=@('^{HOME}','{END}','{DOWN}','{HOME}','{RIGHT 25}','{RIGHT 35}','{END}','{DOWN}','{END}','{HOME}','^{HOME}')
foreach($k in $keys){
 [VisualCaretSmokeNative]::SetForegroundWindow($np.MainWindowHandle)|Out-Null
 Start-Sleep -Milliseconds 450
 $w.SendKeys($k)
}
Start-Sleep -Milliseconds 500

$vp.Refresh();if(-not$vp.HasExited -and $vp.MainWindowHandle-ne0){[VisualCaretSmokeNative]::PostMessage($vp.MainWindowHandle,0x0010,[IntPtr]::Zero,[IntPtr]::Zero)|Out-Null}
if(-not$vp.WaitForExit(5000)){Stop-Process -Id $vp.Id -Force -ErrorAction SilentlyContinue;throw 'Visual app did not close cleanly'}
[VisualCaretSmokeNative]::PostMessage($np.MainWindowHandle,0x0010,[IntPtr]::Zero,[IntPtr]::Zero)|Out-Null
Start-Sleep -Milliseconds 300

$rows=@(Import-Csv $telemetry);if(-not$rows.Count){throw 'No Visual telemetry frames'}
$fail=@($rows|?{[uint64]$_.present_hr-ne0}).Count
$uiaText2=@($rows|?{[int]$_.poi_source-eq0}).Count
$uiaSelection=@($rows|?{[int]$_.poi_source-eq1}).Count
$winCaret=@($rows|?{[int]$_.poi_source-eq2}).Count
$uiaFocus=@($rows|?{[int]$_.poi_source-eq3}).Count
$winFocus=@($rows|?{[int]$_.poi_source-eq4}).Count
$pointer=@($rows|?{[int]$_.poi_source-eq5}).Count
$hold=@($rows|?{[int]$_.viewport_action-eq1}).Count
$pan=@($rows|?{[int]$_.viewport_action-eq2}).Count
$jump=@($rows|?{[int]$_.viewport_action-eq3}).Count
$invalid=@($rows|?{[int]$_.viewport_action-eq0}).Count
$semanticCaret=$uiaText2+$uiaSelection
$analysis=[ordered]@{captured_at=(Get-Date).ToString('o');frames=$rows.Count;present_failures=$fail;uia_textpattern2_caret_frames=$uiaText2;uia_textpattern_selection_frames=$uiaSelection;win32_caret_frames=$winCaret;uia_focus_frames=$uiaFocus;win32_focus_frames=$winFocus;pointer_frames=$pointer;semantic_caret_frames=$semanticCaret;hold_frames=$hold;pan_frames=$pan;jump_frames=$jump;invalid_frames=$invalid;zoom=$Zoom;display_count=$screens.Count}
$analysis|ConvertTo-Json -Depth 4|Set-Content -Encoding UTF8 (Join-Path $run 'analysis.json')
@(
 '# Integrated Visual caret smoke','',
 "- Frames: $($rows.Count)","- Present failures: $fail",
 "- UIA TextPattern2 caret: $uiaText2",
 "- UIA TextPattern selection caret: $uiaSelection",
 "- Win32 caret: $winCaret",
 "- UIA focus / Win32 focus / pointer: $uiaFocus / $winFocus / $pointer",
 "- Hold / Pan / Jump / Invalid: $hold / $pan / $jump / $invalid",
 "- Zoom: ${Zoom}x","- Displays: $($screens.Count)"
)-join"`r`n"|Set-Content -Encoding UTF8 (Join-Path $run 'SUMMARY.md')
Write-Host "Integrated caret smoke complete: $run";Get-Content (Join-Path $run 'SUMMARY.md')
