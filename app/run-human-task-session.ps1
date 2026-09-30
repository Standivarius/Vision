param([ValidateSet(1,2,4)][int]$Zoom=2)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class VisualHumanSessionNative {
  [DllImport("kernel32.dll")] public static extern uint WTSGetActiveConsoleSessionId();
}
'@ -ErrorAction SilentlyContinue

$repo=Resolve-Path (Join-Path $PSScriptRoot '..')
$exe=Join-Path $PSScriptRoot 'build\Release\visual_app.exe'
if(-not(Test-Path $exe)){throw "Visual app not built: $exe"}
$processSession=[Diagnostics.Process]::GetCurrentProcess().SessionId
$consoleSession=[VisualHumanSessionNative]::WTSGetActiveConsoleSessionId()
if($processSession-ne$consoleSession){throw "Human task session requires active console session. Process=$processSession Console=$consoleSession"}
$screens=@([Windows.Forms.Screen]::AllScreens)
if($screens.Count-lt2){throw "Human task session requires at least two displays; found $($screens.Count)"}

$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$run=Join-Path $repo ("lab\benchmarks\integrated_app\runs\${stamp}__human_task_session")
New-Item -ItemType Directory -Force -Path $run|Out-Null
$fixture=Join-Path $run 'human_task_fixture.txt'
$telemetry=Join-Path $run 'visual_app_telemetry.csv'
$status=Join-Path $run 'status.json'
@'
VISUAL TWO-SCREEN HUMAN TASK SESSION

This document is temporary and exists only for the Visual usability session.

Task paragraph 1 — reading and caret tracking
Visual should let you read this paragraph on the source display while the Detail display remains useful and stable. Move through the sentence with the arrow keys. The magnified viewport should not move on every single caret step; it should remain still while the caret is comfortably visible and pan only when needed.

Task paragraph 2 — longer horizontal movement
This is a deliberately longer line of text intended to make the caret travel far enough across the editing surface that you can judge whether the Detail view follows naturally, moves too early, moves too late, jumps too far, or otherwise feels distracting during ordinary keyboard navigation.

Task paragraph 3 — mouse versus caret
Click at several different places in this paragraph, then stop moving the mouse and use the arrow keys again. Mouse intent should win briefly while you move it, then caret tracking should resume automatically after the pointer stops.

Task paragraph 4 — zoom and return
Try 2x and 4x, then use the temporary normal-view command and return. Returning from 1x should bring you back to the exact magnified location you had before.

Task paragraph 5 — final impression
Use the document freely for a minute: read, click, move the caret, type a few harmless characters if you want, and judge whether the second display behaves like a useful detail view rather than a technical demo.
'@ | Set-Content -Encoding UTF8 $fixture

function Write-Status([string]$phase,[hashtable]$extra=@{}){
  $obj=[ordered]@{phase=$phase;updated_at=(Get-Date).ToString('o');run_dir=$run;fixture=$fixture;telemetry=$telemetry;zoom=$Zoom;display_count=$screens.Count}
  foreach($k in $extra.Keys){$obj[$k]=$extra[$k]}
  $obj|ConvertTo-Json -Depth 5|Set-Content -Encoding UTF8 $status
}

$beforeNotepad=@(Get-Process Notepad -ErrorAction SilentlyContinue|ForEach-Object{$_.Id})
Write-Status 'launching'
Start-Process notepad.exe -ArgumentList @($fixture)|Out-Null
$deadline=(Get-Date).AddSeconds(10);$np=$null
while((Get-Date)-lt$deadline){
  Start-Sleep -Milliseconds 200
  $c=@(Get-Process Notepad -ErrorAction SilentlyContinue|Where-Object{$_.MainWindowHandle-ne0-and$beforeNotepad-notcontains$_.Id}|Sort-Object StartTime -Descending)
  if($c.Count){$np=$c|Select-Object -First 1;break}
}
if(-not$np){throw 'Human-session Notepad window not found'}

$vp=Start-Process $exe -ArgumentList @('--zoom',[string]$Zoom,'--log',$telemetry) -PassThru
$deadline=(Get-Date).AddSeconds(8)
while((Get-Date)-lt$deadline-and$vp.MainWindowHandle-eq0-and-not$vp.HasExited){Start-Sleep -Milliseconds 100;$vp.Refresh()}
if($vp.HasExited){throw "Visual exited before human session started. Exit=$($vp.ExitCode)"}
Start-Sleep -Milliseconds 700
$vp.Refresh()
if($vp.HasExited){throw "Visual exited before human session was ready. Exit=$($vp.ExitCode)"}

Write-Status 'ready' @{visual_pid=$vp.Id;notepad_pid=$np.Id}
@'
READY

Use the temporary Notepad document normally while watching the Detail display.
End the session with Ctrl+Alt+Q.
'@ | Set-Content -Encoding UTF8 (Join-Path $run 'READY.txt')

$vp.WaitForExit()
$vp.Refresh()
Start-Sleep -Milliseconds 250

$rows=@(Import-Csv $telemetry -ErrorAction SilentlyContinue)
$frames=$rows.Count
$presentFailures=@($rows|Where-Object{[uint64]$_.present_hr-ne0}).Count
$invalid=@($rows|Where-Object{[int]$_.viewport_action-eq0}).Count
$holds=@($rows|Where-Object{[int]$_.viewport_action-eq1}).Count
$pans=@($rows|Where-Object{[int]$_.viewport_action-eq2}).Count
$jumps=@($rows|Where-Object{[int]$_.viewport_action-eq3}).Count
$pointer=@($rows|Where-Object{[int]$_.poi_source-eq5}).Count
$uiaText2=@($rows|Where-Object{[int]$_.poi_source-eq0}).Count
$uiaText=@($rows|Where-Object{[int]$_.poi_source-eq1}).Count
$winCaret=@($rows|Where-Object{[int]$_.poi_source-eq2}).Count
$uiaFocus=@($rows|Where-Object{[int]$_.poi_source-eq3}).Count
$winFocus=@($rows|Where-Object{[int]$_.poi_source-eq4}).Count
$locator=@($rows|Where-Object{[int]$_.locator_visible-eq1}).Count
$analysis=[ordered]@{
  captured_at=(Get-Date).ToString('o');visual_exit=$vp.ExitCode;frames=$frames;present_failures=$presentFailures;invalid_viewport_frames=$invalid
  hold_frames=$holds;pan_frames=$pans;jump_frames=$jumps;pointer_source_frames=$pointer;uia_textpattern2_frames=$uiaText2;uia_textpattern_frames=$uiaText;win32_caret_frames=$winCaret;uia_focus_frames=$uiaFocus;win32_focus_frames=$winFocus;locator_visible_frames=$locator
}
$analysis|ConvertTo-Json -Depth 4|Set-Content -Encoding UTF8 (Join-Path $run 'analysis.json')
@(
 '# Visual human task session telemetry','',
 "- Visual exit: $($vp.ExitCode)",
 "- Frames: $frames",
 "- Present failures: $presentFailures",
 "- Invalid viewport decisions: $invalid",
 "- Hold / Pan / Jump: $holds / $pans / $jumps",
 "- POI pointer / UIA Text2 / UIA Text / Win32 caret / UIA focus / Win32 focus: $pointer / $uiaText2 / $uiaText / $winCaret / $uiaFocus / $winFocus",
 "- Locator-visible frames: $locator",
 '',
 'Human qualitative feedback is intentionally recorded separately after the session.'
)-join"`r`n"|Set-Content -Encoding UTF8 (Join-Path $run 'SUMMARY.md')
Write-Status 'complete' @{visual_exit=$vp.ExitCode;frames=$frames;analysis=(Join-Path $run 'analysis.json')}

# Close only the temporary Notepad instance if it is still running.
try{$np.Refresh()}catch{}
if($np-and-not$np.HasExited){Stop-Process -Id $np.Id -ErrorAction SilentlyContinue}

Write-Host "Human task session complete: $run"
Get-Content (Join-Path $run 'SUMMARY.md')
