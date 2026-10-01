param(
    [ValidateRange(1,4)][int]$Zoom=2
)
$ErrorActionPreference='Stop'

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class VisionWordSmokeNative {
  [DllImport("kernel32.dll")] public static extern uint WTSGetActiveConsoleSessionId();
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd,IntPtr after,int x,int y,int cx,int cy,uint flags);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint flags,uint dx,uint dy,uint data,UIntPtr extra);
  public static void Click(int x,int y){SetCursorPos(x,y);mouse_event(0x0002,0,0,0,UIntPtr.Zero);mouse_event(0x0004,0,0,0,UIntPtr.Zero);}
}
"@ -ErrorAction SilentlyContinue

function Find-WordDocument([IntPtr]$WordHwnd) {
    $root=[System.Windows.Automation.AutomationElement]::FromHandle($WordHwnd)
    if(-not$root){throw 'Unable to create UIA root for Word'}
    $condition=New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
        [System.Windows.Automation.ControlType]::Document)
    $docs=$root.FindAll([System.Windows.Automation.TreeScope]::Descendants,$condition)
    foreach($candidate in $docs){
        $patterns=@($candidate.GetSupportedPatterns()|ForEach-Object{$_.ProgrammaticName})
        if($candidate.Current.IsKeyboardFocusable -and $patterns -contains 'TextPatternIdentifiers.Pattern'){
            return [pscustomobject]@{Element=$candidate;Patterns=$patterns}
        }
    }
    throw 'No focusable Word document with UIA TextPattern found'
}

function Click-Element([System.Windows.Automation.AutomationElement]$Element) {
    $r=$Element.Current.BoundingRectangle
    if([double]::IsInfinity($r.X) -or $r.Width-lt50 -or $r.Height-lt50){throw 'Word document has unusable UIA geometry'}
    [VisionWordSmokeNative]::Click([int]($r.X+[math]::Min(140,$r.Width/3)),[int]($r.Y+[math]::Min(120,$r.Height/3)))
    Start-Sleep -Milliseconds 350
}

$repo=Resolve-Path (Join-Path $PSScriptRoot '..')
$vision=Join-Path $PSScriptRoot 'build\Release\visual_app.exe'
if(-not(Test-Path $vision -PathType Leaf)){throw "Vision executable not found: $vision"}
if([Diagnostics.Process]::GetCurrentProcess().SessionId-ne[VisionWordSmokeNative]::WTSGetActiveConsoleSessionId()){
    throw 'Word smoke requires the active console session'
}
if(Get-Process WINWORD -ErrorAction SilentlyContinue){throw 'Word smoke requires Word to be fully closed before starting'}
if(Get-Process visual_app -ErrorAction SilentlyContinue){throw 'Word smoke requires no running dev Vision instance'}

$primary=[Windows.Forms.Screen]::AllScreens|Where-Object Primary|Select-Object -First 1
if(-not$primary){throw 'Primary display not found'}
$b=$primary.Bounds

$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$run=Join-Path $repo ("lab\benchmarks\integrated_app\runs\"+$stamp+"__word_editing_smoke")
New-Item -ItemType Directory -Force -Path $run|Out-Null
$telemetry=Join-Path $run 'visual_app_telemetry.csv'

$word=$null;$doc=$null;$wp=$null;$vp=$null;$w=$null
$wordControlType='';$wordFramework='';$wordPatterns=@()
$editingStart=0L;$editingEnd=0L;$focusStart=0L;$focusEnd=0L;$returnStart=0L;$returnEnd=0L
$forcedVisionCleanup=$false
try {
    $word=New-Object -ComObject Word.Application
    $word.Visible=$true
    $doc=$word.Documents.Add()
    $nl=[Environment]::NewLine
    $doc.Content.Text=
        ("Vision Word compatibility paragraph. This sentence is deliberately long enough to exercise horizontal text-cursor movement and viewport tracking while editing ordinary Word content. " * 4) + $nl +
        ("Second paragraph provides vertical cursor movement, selection, and return-to-text behaviour for the compatibility task. " * 5) + $nl +
        ("Third paragraph gives another stable semantic editing surface for repeated navigation. " * 6)

    $deadline=(Get-Date).AddSeconds(8)
    while((Get-Date)-lt$deadline){
        Start-Sleep -Milliseconds 150
        $candidate=@(Get-Process WINWORD -ErrorAction SilentlyContinue|Where-Object{$_.MainWindowHandle-ne0}|Select-Object -First 1)
        if($candidate.Count){$wp=$candidate[0];break}
    }
    if(-not$wp){throw 'Disposable Word window was not created'}

    [VisionWordSmokeNative]::SetWindowPos(
        $wp.MainWindowHandle,[IntPtr]::Zero,
        $b.Left+60,$b.Top+50,
        [math]::Min(1200,$b.Width-120),[math]::Min(800,$b.Height-100),0x0040)|Out-Null
    Start-Sleep -Milliseconds 650

    $wordDoc=Find-WordDocument $wp.MainWindowHandle
    $wordControlType=$wordDoc.Element.Current.ControlType.ProgrammaticName
    $wordFramework=$wordDoc.Element.Current.FrameworkId
    $wordPatterns=@($wordDoc.Patterns)
    Click-Element $wordDoc.Element
    $w=New-Object -ComObject WScript.Shell
    $w.SendKeys('^{HOME}')
    Start-Sleep -Milliseconds 350

    $tp=$wordDoc.Element.GetCurrentPattern([System.Windows.Automation.TextPattern]::Pattern)
    $selection=$tp.GetSelection()
    $preBounds=if($selection.Count){@($selection[0].GetBoundingRectangles())}else{@()}
    if($selection.Count-lt1 -or $preBounds.Count-lt1){throw 'Word TextPattern selection exposes no usable geometry before Vision starts'}

    $vp=Start-Process $vision -ArgumentList @('--zoom',[string]$Zoom,'--log',$telemetry) -PassThru
    $deadline=(Get-Date).AddSeconds(7)
    while((Get-Date)-lt$deadline-and$vp.MainWindowHandle-eq0){Start-Sleep -Milliseconds 100;$vp.Refresh()}
    if($vp.HasExited){throw "Vision exited early: $($vp.ExitCode)"}

    Start-Sleep -Milliseconds 650
    $wordDoc=Find-WordDocument $wp.MainWindowHandle
    Click-Element $wordDoc.Element
    $w.SendKeys('^{HOME}')
    Start-Sleep -Milliseconds 300

    $editingStart=[Diagnostics.Stopwatch]::GetTimestamp()
    foreach($keys in @('{RIGHT 18}','{DOWN}','{RIGHT 12}','{END}','{UP}','{LEFT 11}','{DOWN}','{HOME}','{RIGHT 24}','+{RIGHT 6}','{LEFT}')){
        $w.SendKeys($keys)
        Start-Sleep -Milliseconds 240
    }
    $editingEnd=[Diagnostics.Stopwatch]::GetTimestamp()

    $focusStart=[Diagnostics.Stopwatch]::GetTimestamp()
    $w.SendKeys('%h')
    Start-Sleep -Milliseconds 350
    $w.SendKeys('{TAB 3}')
    Start-Sleep -Milliseconds 350
    $focusEnd=[Diagnostics.Stopwatch]::GetTimestamp()

    $returnStart=[Diagnostics.Stopwatch]::GetTimestamp()
    $w.SendKeys('{ESC}')
    Start-Sleep -Milliseconds 220
    Click-Element $wordDoc.Element
    $w.SendKeys('{RIGHT 8}')
    Start-Sleep -Milliseconds 500
    $returnEnd=[Diagnostics.Stopwatch]::GetTimestamp()
}
finally {
    if($vp){
        try{
            $vp.Refresh()
            if(-not$vp.HasExited -and $w){
                $w.SendKeys('^%q')
                $vp.WaitForExit(4000)|Out-Null
                $vp.Refresh()
            }
            if(-not$vp.HasExited){
                Stop-Process -Id $vp.Id -Force -ErrorAction SilentlyContinue
                $forcedVisionCleanup=$true
            }
        }catch{}
    }
    if($doc){try{$doc.Close(0)}catch{}}
    if($word){try{$word.Quit()}catch{}}
    if($doc){try{[void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($doc)}catch{}}
    if($word){try{[void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($word)}catch{}}
    [GC]::Collect();[GC]::WaitForPendingFinalizers()
    Start-Sleep -Milliseconds 500
}

if($editingStart-eq0 -or $editingEnd-le$editingStart){throw "Word editing phase did not complete: $run"}
if(-not(Test-Path $telemetry)){throw "Vision telemetry not created: $telemetry"}

$rows=@(Import-Csv $telemetry|Where-Object{$_.frame-match'^\d+$'})
function Phase([int64]$start,[int64]$end){@($rows|Where-Object{[int64]$_.qpc-ge$start-and[int64]$_.qpc-le$end})}
$editing=Phase $editingStart $editingEnd
$focus=Phase $focusStart $focusEnd
$return=Phase $returnStart $returnEnd

function Summarize($phase){
    $uia2=@($phase|Where-Object{[int]$_.poi_source-eq0}).Count
    $uiaText=@($phase|Where-Object{[int]$_.poi_source-eq1}).Count
    $winCaret=@($phase|Where-Object{[int]$_.poi_source-eq2}).Count
    $uiaFocus=@($phase|Where-Object{[int]$_.poi_source-eq3}).Count
    $winFocus=@($phase|Where-Object{[int]$_.poi_source-eq4}).Count
    $pointer=@($phase|Where-Object{[int]$_.poi_source-eq5}).Count
    $caretPresent=@($phase|Where-Object{[int]$_.uia_caret_present-eq1}).Count
    $focusPresent=@($phase|Where-Object{[int]$_.uia_focus_present-eq1}).Count
    [ordered]@{
        frames=$phase.Count
        uia_text2=$uia2
        uia_text=$uiaText
        win32_caret=$winCaret
        semantic_caret_selected=$uia2+$uiaText+$winCaret
        uia_focus_selected=$uiaFocus
        win32_focus_selected=$winFocus
        pointer_selected=$pointer
        caret_present=$caretPresent
        focus_present=$focusPresent
        locator=@($phase|Where-Object{[int]$_.locator_visible-eq1}).Count
        pan=@($phase|Where-Object{[int]$_.viewport_action-eq2}).Count
        invalid=@($phase|Where-Object{[int]$_.viewport_action-eq0}).Count
    }
}
$editingSummary=Summarize $editing
$focusSummary=Summarize $focus
$returnSummary=Summarize $return
$presentFailures=@($rows|Where-Object{[uint64]$_.present_hr-ne0}).Count

$editingCaretRatio=if($editing.Count){$editingSummary.semantic_caret_selected/[double]$editing.Count}else{0}
$editingPresentRatio=if($editing.Count){$editingSummary.caret_present/[double]$editing.Count}else{0}
$focusSelected=$focusSummary.uia_focus_selected+$focusSummary.win32_focus_selected
$returnCaret=$returnSummary.semantic_caret_selected
$pass=(
    $presentFailures-eq0 -and
    $editing.Count-gt100 -and
    $editingPresentRatio-ge0.60 -and
    $editingCaretRatio-ge0.50 -and
    $focusSelected-gt0 -and
    $returnCaret-gt0 -and
    $editingSummary.locator-gt0
)

$analysis=[ordered]@{
    office_version=(Get-Item 'C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE').VersionInfo.ProductVersion
    zoom=$Zoom
    word_uia_control_type=$wordControlType
    word_uia_framework=$wordFramework
    word_uia_patterns=@($wordPatterns)
    word_prevision_selection_bounds_count=$preBounds.Count
    editing=$editingSummary
    editing_caret_present_ratio=[math]::Round($editingPresentRatio,3)
    editing_caret_selected_ratio=[math]::Round($editingCaretRatio,3)
    ribbon_focus=$focusSummary
    return_to_editing=$returnSummary
    present_failures=$presentFailures
    forced_vision_cleanup=$forcedVisionCleanup
    pass=$pass
}
$analysis|ConvertTo-Json -Depth 6|Set-Content (Join-Path $run 'analysis.json') -Encoding utf8
@(
    '# Vision Word editing compatibility smoke','',
    "- Office/Word version: $($analysis.office_version)",
    "- Word UIA editing surface: $($analysis.word_uia_control_type), framework=$($analysis.word_uia_framework), patterns=$($analysis.word_uia_patterns -join ', ')",
    "- Pre-Vision TextPattern selection bounds: $($preBounds.Count)",
    "- Editing frames: $($editing.Count)",
    "- Editing caret-present ratio: $([math]::Round(100*$editingPresentRatio,1))%",
    "- Editing semantic-caret selected ratio: $([math]::Round(100*$editingCaretRatio,1))%",
    "- Editing locator frames: $($editingSummary.locator)",
    "- Ribbon focus selected frames: $focusSelected",
    "- Return-to-editing semantic-caret frames: $returnCaret",
    "- Present failures: $presentFailures",
    "- Forced Vision cleanup: $forcedVisionCleanup",
    "- Pass: $pass"
)-join[Environment]::NewLine|Set-Content (Join-Path $run 'SUMMARY.md') -Encoding utf8

Write-Host "Word editing smoke complete: $run"
Get-Content (Join-Path $run 'SUMMARY.md')
if(-not$pass){throw "Word editing compatibility smoke failed: $run"}
