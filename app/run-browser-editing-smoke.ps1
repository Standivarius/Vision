param(
    [ValidateRange(1,4)][int]$Zoom=2,
    [ValidateRange(0.0,1.0)][double]$MinCaretPresenceRatio=0.70,
    [ValidateRange(0.0,1.0)][double]$MinCaretSelectedRatio=0.60
)
$ErrorActionPreference='Stop'

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class VisualBrowserSmokeNative {
  [DllImport("kernel32.dll")] public static extern uint WTSGetActiveConsoleSessionId();
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd,uint msg,IntPtr wParam,IntPtr lParam);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd,out uint pid);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a,uint b,bool attach);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  public static void ForceForeground(IntPtr hwnd) {
    IntPtr fg=GetForegroundWindow(); uint pid; uint fgTid=fg!=IntPtr.Zero?GetWindowThreadProcessId(fg,out pid):0; uint cur=GetCurrentThreadId();
    bool attached=fgTid!=0 && fgTid!=cur && AttachThreadInput(cur,fgTid,true);
    SetForegroundWindow(hwnd); if(attached) AttachThreadInput(cur,fgTid,false);
  }
}
'@ -ErrorAction SilentlyContinue

function Focus-Editor([IntPtr]$BrowserHwnd) {
    $root=[System.Windows.Automation.AutomationElement]::FromHandle($BrowserHwnd)
    if(-not$root){throw 'Unable to create UIA root for browser window'}
    $condition=New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::AutomationIdProperty,'e')
    $editor=$root.FindFirst([System.Windows.Automation.TreeScope]::Descendants,$condition)
    if(-not$editor){throw 'Browser fixture editor (AutomationId=e) was not found in the UIA tree'}
    if(-not$editor.Current.IsKeyboardFocusable){throw 'Browser fixture editor is not keyboard-focusable'}
    $patterns=@($editor.GetSupportedPatterns()|ForEach-Object{$_.ProgrammaticName})
    if(-not($patterns -contains 'TextPatternIdentifiers.Pattern')){
        throw 'Browser fixture editor does not expose UIA TextPattern'
    }
    $editor.SetFocus()
    $deadline=(Get-Date).AddSeconds(2)
    while((Get-Date)-lt$deadline -and -not$editor.Current.HasKeyboardFocus){Start-Sleep -Milliseconds 50}
    if(-not$editor.Current.HasKeyboardFocus){throw 'Browser fixture editor did not acquire UIA keyboard focus'}
    return [pscustomobject]@{
        automation_id=$editor.Current.AutomationId
        framework=$editor.Current.FrameworkId
        control_type=$editor.Current.ControlType.ProgrammaticName
        supported_patterns=$patterns
    }
}

$repo=Resolve-Path (Join-Path $PSScriptRoot '..')
$visual=Join-Path $PSScriptRoot 'build\Release\visual_app.exe'
if(-not(Test-Path $visual -PathType Leaf)){throw "Vision executable not found: $visual"}
if([Diagnostics.Process]::GetCurrentProcess().SessionId-ne[VisualBrowserSmokeNative]::WTSGetActiveConsoleSessionId()){
    throw 'Browser smoke requires console session'
}

$existingVision=@(Get-Process visual_app -ErrorAction SilentlyContinue|Where-Object{
    try{$_.Path -eq (Resolve-Path $visual).Path}catch{$false}
})
if($existingVision.Count){
    throw "Browser smoke requires no existing dev Vision instance; found PID(s): $($existingVision.Id -join ', ')"
}

$candidates=@(
  'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
  'C:\Program Files\Microsoft\Edge\Application\msedge.exe',
  'C:\Program Files\Google\Chrome\Application\chrome.exe',
  'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe'
)
$browser=$candidates|Where-Object{Test-Path $_}|Select-Object -First 1
if(-not$browser){throw 'No supported Chromium browser found'}
$name=[IO.Path]::GetFileNameWithoutExtension($browser)
$before=@(Get-Process $name -ErrorAction SilentlyContinue|ForEach-Object{$_.Id})

$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$run=Join-Path $repo ("lab\benchmarks\integrated_app\runs\${stamp}__browser_editing_smoke")
New-Item -ItemType Directory -Force -Path $run|Out-Null
$html=Join-Path $run 'editor.html'
$profile=Join-Path $run 'browser_profile'
$telemetry=Join-Path $run 'visual_app_telemetry.csv'
@'
<!doctype html><html><head><meta charset="utf-8"><title>Vision Browser Editing Smoke</title><style>body{font:26px Segoe UI;margin:36px}textarea{font:26px Segoe UI;width:90vw;height:70vh;line-height:1.5}</style></head><body><h1>Vision browser editing smoke</h1><textarea id="e" autofocus>Vision browser caret tracking test. Move through this text with the keyboard while Vision follows the browser editing caret.
Second line for vertical caret movement and semantic accessibility evidence.
Third line provides a longer editing surface for repeated movement.</textarea><script>window.onload=()=>{const e=document.getElementById('e');e.focus();e.setSelectionRange(0,0);}</script></body></html>
'@|Out-File $html -Encoding utf8

$uri=[Uri]$html
$args=@("--user-data-dir=$profile",'--no-first-run','--disable-sync','--force-renderer-accessibility','--enable-features=UiaProvider',"--app=$($uri.AbsoluteUri)")
$launcher=$null
$bp=$null
$vp=$null
$editorInfo=$null
$forcedVisionCleanup=$false
$phaseStart=0L
$phaseEnd=0L

try {
    $launcher=Start-Process $browser -ArgumentList $args -PassThru
    $deadline=(Get-Date).AddSeconds(12)
    while((Get-Date)-lt$deadline){
        Start-Sleep -Milliseconds 150
        $wins=@(Get-Process $name -ErrorAction SilentlyContinue|Where-Object{
            $_.MainWindowHandle-ne0 -and $before-notcontains$_.Id
        }|Sort-Object StartTime -Descending)
        if($wins.Count){$bp=$wins|Select-Object -First 1;break}
    }
    if(-not$bp){throw "Browser app window not found for $browser"}

    [VisualBrowserSmokeNative]::ForceForeground($bp.MainWindowHandle)
    Start-Sleep -Milliseconds 500
    $editorInfo=Focus-Editor $bp.MainWindowHandle
    $w=New-Object -ComObject WScript.Shell
    $w.SendKeys('^{HOME}')
    Start-Sleep -Milliseconds 250

    $vp=Start-Process $visual -ArgumentList @('--zoom',[string]$Zoom,'--log',$telemetry) -PassThru
    $deadline=(Get-Date).AddSeconds(6)
    while((Get-Date)-lt$deadline-and$vp.MainWindowHandle-eq0){Start-Sleep -Milliseconds 100;$vp.Refresh()}
    if($vp.HasExited){throw "Vision exited early: $($vp.ExitCode)"}

    Start-Sleep -Milliseconds 700
    [VisualBrowserSmokeNative]::ForceForeground($bp.MainWindowHandle)
    Start-Sleep -Milliseconds 200
    $editorInfo=Focus-Editor $bp.MainWindowHandle
    $w.SendKeys('^{HOME}')
    Start-Sleep -Milliseconds 350

    $phaseStart=[Diagnostics.Stopwatch]::GetTimestamp()
    foreach($keys in @('{RIGHT 16}','{DOWN}','{RIGHT 12}','{END}','{UP}','{LEFT 10}','{DOWN}','{HOME}','{RIGHT 20}')){
        $w.SendKeys($keys)
        Start-Sleep -Milliseconds 240
    }
    $phaseEnd=[Diagnostics.Stopwatch]::GetTimestamp()
    Start-Sleep -Milliseconds 350
}
finally {
    if($vp){
        try{
            $vp.Refresh()
            if(-not$vp.HasExited -and $w){
                # Use Vision's real global exit path so telemetry buffers close normally.
                $w.SendKeys('^%q')
                $vp.WaitForExit(4000)|Out-Null
                $vp.Refresh()
            }
            if(-not$vp.HasExited){
                [VisualBrowserSmokeNative]::PostMessage($vp.MainWindowHandle,0x0010,[IntPtr]::Zero,[IntPtr]::Zero)|Out-Null
                $vp.WaitForExit(1800)|Out-Null
                $vp.Refresh()
            }
            if(-not$vp.HasExited){
                Stop-Process -Id $vp.Id -Force -ErrorAction SilentlyContinue
                $forcedVisionCleanup=$true
            }
        }catch{}
    }
    if($bp){
        try{[VisualBrowserSmokeNative]::PostMessage($bp.MainWindowHandle,0x0010,[IntPtr]::Zero,[IntPtr]::Zero)|Out-Null}catch{}
    }
    Start-Sleep -Milliseconds 350
    Get-CimInstance Win32_Process -Filter "Name='$name.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like "*$profile*" } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

if($phaseStart-eq0 -or $phaseEnd-le$phaseStart){throw "Browser editing phase did not complete: $run"}
if(-not(Test-Path $telemetry)){throw "Vision telemetry was not created: $telemetry"}

$rows=@(Import-Csv $telemetry|Where-Object{$_.frame-match'^\d+$'})
$phase=@($rows|Where-Object{[int64]$_.qpc-ge$phaseStart-and[int64]$_.qpc-le$phaseEnd})
$uia2=@($phase|Where-Object{[int]$_.poi_source-eq0}).Count
$uiaText=@($phase|Where-Object{[int]$_.poi_source-eq1}).Count
$winCaret=@($phase|Where-Object{[int]$_.poi_source-eq2}).Count
$focus=@($phase|Where-Object{[int]$_.poi_source-eq3-or[int]$_.poi_source-eq4}).Count
$pointer=@($phase|Where-Object{[int]$_.poi_source-eq5}).Count
$caretPresent=@($phase|Where-Object{[int]$_.uia_caret_present-eq1}).Count
$fail=@($rows|Where-Object{[uint64]$_.present_hr-ne0}).Count
$locator=@($phase|Where-Object{[int]$_.locator_visible-eq1}).Count
$caretSelected=$uia2+$uiaText+$winCaret
$caretPresenceRatio=if($phase.Count){$caretPresent/[double]$phase.Count}else{0.0}
$caretSelectedRatio=if($phase.Count){$caretSelected/[double]$phase.Count}else{0.0}
$pointerFresh=@($phase|Where-Object{
    $age=[double]$_.pointer_age_ms
    $age-ge0-and$age-lt100
}).Count
$pass=(
    $fail-eq0 -and
    $phase.Count-gt120 -and
    $caretPresenceRatio-ge$MinCaretPresenceRatio -and
    $caretSelectedRatio-ge$MinCaretSelectedRatio -and
    $locator-gt0
)

$a=[ordered]@{
    browser=$browser
    browser_version=(Get-Item $browser).VersionInfo.ProductVersion
    editor_automation_id=$editorInfo.automation_id
    editor_framework=$editorInfo.framework
    editor_control_type=$editorInfo.control_type
    editor_supported_patterns=@($editorInfo.supported_patterns)
    phase_frames=$phase.Count
    uia_textpattern2_frames=$uia2
    uia_textpattern_frames=$uiaText
    win32_caret_frames=$winCaret
    caret_selected_frames=$caretSelected
    caret_selected_ratio=[math]::Round($caretSelectedRatio,3)
    uia_caret_present_frames=$caretPresent
    uia_caret_present_ratio=[math]::Round($caretPresenceRatio,3)
    focus_frames=$focus
    pointer_frames=$pointer
    pointer_fresh_frames=$pointerFresh
    locator_frames=$locator
    present_failures=$fail
    forced_vision_cleanup=$forcedVisionCleanup
    min_caret_presence_ratio=$MinCaretPresenceRatio
    min_caret_selected_ratio=$MinCaretSelectedRatio
    pass=$pass
}
$a|ConvertTo-Json -Depth 4|Out-File (Join-Path $run 'analysis.json') -Encoding utf8
@(
    '# Browser editing smoke','',
    "- Browser: $browser",
    "- Browser version: $($a.browser_version)",
    "- UIA editor: $($a.editor_control_type), AutomationId=$($a.editor_automation_id), framework=$($a.editor_framework)",
    "- Phase frames: $($phase.Count)",
    "- UIA Text2 / UIA Text / Win32 caret: $uia2 / $uiaText / $winCaret",
    "- Caret present: $caretPresent / $($phase.Count) ($([math]::Round(100*$caretPresenceRatio,1))%)",
    "- Caret selected: $caretSelected / $($phase.Count) ($([math]::Round(100*$caretSelectedRatio,1))%)",
    "- Focus / pointer: $focus / $pointer",
    "- Fresh-pointer frames (<100 ms): $pointerFresh",
    "- Locator frames: $locator",
    "- Present failures: $fail",
    "- Forced Vision cleanup: $forcedVisionCleanup",
    "- Pass: $pass"
)-join"`r`n"|Out-File (Join-Path $run 'SUMMARY.md') -Encoding utf8
if(-not$pass){throw "Browser editing smoke failed: $run"}
Write-Host "Browser editing smoke complete: $run"
Get-Content (Join-Path $run 'SUMMARY.md')
