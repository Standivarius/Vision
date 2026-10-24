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
public static class VisionExcelSmokeNative {
  [DllImport("kernel32.dll")] public static extern uint WTSGetActiveConsoleSessionId();
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd,IntPtr after,int x,int y,int cx,int cy,uint flags);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint flags,uint dx,uint dy,uint data,UIntPtr extra);
  public static void Click(int x,int y){SetCursorPos(x,y);mouse_event(0x0002,0,0,0,UIntPtr.Zero);mouse_event(0x0004,0,0,0,UIntPtr.Zero);}
}
"@ -ErrorAction SilentlyContinue

function Root([IntPtr]$Hwnd) {
    $root=[System.Windows.Automation.AutomationElement]::FromHandle($Hwnd)
    if(-not$root){throw 'Unable to create Excel UIA root'}
    return $root
}

function Find-ById([IntPtr]$Hwnd,[string]$AutomationId) {
    $root=Root $Hwnd
    $condition=New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::AutomationIdProperty,$AutomationId)
    return $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants,$condition)
}

function Click-Element([System.Windows.Automation.AutomationElement]$Element,[string]$Label) {
    if(-not$Element){throw "$Label UIA element not found"}
    $r=$Element.Current.BoundingRectangle
    if([double]::IsInfinity($r.X) -or $r.Width-lt5 -or $r.Height-lt5){throw "$Label has unusable UIA geometry"}
    [VisionExcelSmokeNative]::Click([int]($r.X+[math]::Min(30,$r.Width/2)),[int]($r.Y+[math]::Min(15,$r.Height/2)))
    Start-Sleep -Milliseconds 350
}

$repo=Resolve-Path (Join-Path $PSScriptRoot '..')
$vision=Join-Path $PSScriptRoot 'build\Release\visual_app.exe'
if(-not(Test-Path $vision -PathType Leaf)){throw "Vision executable not found: $vision"}
if([Diagnostics.Process]::GetCurrentProcess().SessionId-ne[VisionExcelSmokeNative]::WTSGetActiveConsoleSessionId()){
    throw 'Excel smoke requires the active console session'
}
if(Get-Process EXCEL -ErrorAction SilentlyContinue){throw 'Excel smoke requires Excel to be fully closed before starting'}
if(Get-Process visual_app -ErrorAction SilentlyContinue){throw 'Excel smoke requires no running dev Vision instance'}

$primary=[Windows.Forms.Screen]::AllScreens|Where-Object Primary|Select-Object -First 1
if(-not$primary){throw 'Primary display not found'}
$b=$primary.Bounds

$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$run=Join-Path $repo ("lab\benchmarks\integrated_app\runs\"+$stamp+"__excel_editing_smoke")
New-Item -ItemType Directory -Force -Path $run|Out-Null
$telemetry=Join-Path $run 'visual_app_telemetry.csv'

$excel=$null;$book=$null;$sheet=$null;$ep=$null;$vp=$null;$w=$null
$cellControlType='';$cellClass='';$cellPatterns=@();$formulaControlType='';$formulaClass='';$formulaPatterns=@()
$gridStart=0L;$gridEnd=0L;$formulaStart=0L;$formulaEnd=0L;$returnStart=0L;$returnEnd=0L
$forcedVisionCleanup=$false
try {
    $excel=New-Object -ComObject Excel.Application
    $excel.Visible=$true
    $excel.DisplayAlerts=$false
    $book=$excel.Workbooks.Add()
    $sheet=$book.Worksheets.Item(1)

    for($row=1;$row-le35;$row++){
        for($col=1;$col-le12;$col++){
            $sheet.Cells.Item($row,$col).Value2=('R'+$row+'C'+$col)
        }
    }
    $sheet.Range('H2').Formula='=SUM(1,2,3)'
    $sheet.Range('A1').Select()|Out-Null

    $deadline=(Get-Date).AddSeconds(8)
    while((Get-Date)-lt$deadline){
        Start-Sleep -Milliseconds 150
        $candidate=@(Get-Process EXCEL -ErrorAction SilentlyContinue|Where-Object{$_.MainWindowHandle-ne0}|Select-Object -First 1)
        if($candidate.Count){$ep=$candidate[0];break}
    }
    if(-not$ep){throw 'Disposable Excel window was not created'}

    [VisionExcelSmokeNative]::SetWindowPos(
        $ep.MainWindowHandle,[IntPtr]::Zero,
        $b.Left+60,$b.Top+50,
        [math]::Min(1200,$b.Width-120),[math]::Min(800,$b.Height-100),0x0040)|Out-Null
    Start-Sleep -Milliseconds 700

    $a1=Find-ById $ep.MainWindowHandle 'A1'
    Click-Element $a1 'A1'
    $w=New-Object -ComObject WScript.Shell
    Start-Sleep -Milliseconds 250

    $a1Patterns=@($a1.GetSupportedPatterns()|ForEach-Object{$_.ProgrammaticName})
    $cellControlType=$a1.Current.ControlType.ProgrammaticName
    $cellClass=$a1.Current.ClassName
    $cellPatterns=@($a1Patterns)
    if(-not($a1Patterns -contains 'GridItemPatternIdentifiers.Pattern')){throw 'Excel A1 lacks GridItem pattern'}
    if(-not($a1Patterns -contains 'TextPatternIdentifiers.Pattern')){throw 'Excel A1 lacks TextPattern'}

    $vp=Start-Process $vision -ArgumentList @('--zoom',[string]$Zoom,'--log',$telemetry) -PassThru
    $deadline=(Get-Date).AddSeconds(7)
    while((Get-Date)-lt$deadline-and$vp.MainWindowHandle-eq0){Start-Sleep -Milliseconds 100;$vp.Refresh()}
    if($vp.HasExited){throw "Vision exited early: $($vp.ExitCode)"}

    Start-Sleep -Milliseconds 650
    $a1=Find-ById $ep.MainWindowHandle 'A1'
    Click-Element $a1 'A1'
    Start-Sleep -Milliseconds 250

    $gridStart=[Diagnostics.Stopwatch]::GetTimestamp()
    foreach($keys in @('{RIGHT 6}','{DOWN 5}','{LEFT 3}','{DOWN 4}','{RIGHT 5}','{UP 3}','^{HOME}','{RIGHT 7}','{DOWN}')){
        $w.SendKeys($keys)
        Start-Sleep -Milliseconds 260
    }
    $gridEnd=[Diagnostics.Stopwatch]::GetTimestamp()

    $sheet.Range('H2').Select()|Out-Null
    Start-Sleep -Milliseconds 250
    $formulaBar=Find-ById $ep.MainWindowHandle 'FormulaBar'
    if(-not$formulaBar){throw 'Excel formula bar UIA element not found'}
    $formulaPatterns=@($formulaBar.GetSupportedPatterns()|ForEach-Object{$_.ProgrammaticName})
    $formulaControlType=$formulaBar.Current.ControlType.ProgrammaticName
    $formulaClass=$formulaBar.Current.ClassName
    $formulaPatterns=@($formulaPatterns)
    Click-Element $formulaBar 'Formula Bar'
    $w.SendKeys('{END}')
    Start-Sleep -Milliseconds 200

    $formulaStart=[Diagnostics.Stopwatch]::GetTimestamp()
    foreach($keys in @('{LEFT 3}','{RIGHT 2}','{HOME}','{RIGHT 5}','+{RIGHT 2}','{LEFT}','{END}','{LEFT 4}')){
        $w.SendKeys($keys)
        Start-Sleep -Milliseconds 260
    }
    $formulaEnd=[Diagnostics.Stopwatch]::GetTimestamp()

    $returnStart=[Diagnostics.Stopwatch]::GetTimestamp()
    $w.SendKeys('{ESC}')
    Start-Sleep -Milliseconds 250
    $h2=Find-ById $ep.MainWindowHandle 'H2'
    Click-Element $h2 'H2'
    $w.SendKeys('{DOWN}{RIGHT}{LEFT}')
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
    if($book){try{$book.Close($false)}catch{}}
    if($excel){try{$excel.Quit()}catch{}}
    foreach($o in @($sheet,$book,$excel)){
        if($o){try{[void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($o)}catch{}}
    }
    [GC]::Collect();[GC]::WaitForPendingFinalizers()
    Start-Sleep -Milliseconds 500
}

if($gridStart-eq0 -or $gridEnd-le$gridStart){throw "Excel grid phase did not complete: $run"}
if($formulaStart-eq0 -or $formulaEnd-le$formulaStart){throw "Excel formula phase did not complete: $run"}
if(-not(Test-Path $telemetry)){throw "Vision telemetry not created: $telemetry"}

$rows=@(Import-Csv $telemetry|Where-Object{$_.frame-match'^\d+$'})
function Phase([int64]$start,[int64]$end){@($rows|Where-Object{[int64]$_.qpc-ge$start-and[int64]$_.qpc-le$end})}
function Summarize($phase){
    $uia2=@($phase|Where-Object{[int]$_.poi_source-eq0}).Count
    $uiaText=@($phase|Where-Object{[int]$_.poi_source-eq1}).Count
    $winCaret=@($phase|Where-Object{[int]$_.poi_source-eq2}).Count
    $uiaFocus=@($phase|Where-Object{[int]$_.poi_source-eq3}).Count
    $winFocus=@($phase|Where-Object{[int]$_.poi_source-eq4}).Count
    [ordered]@{
        frames=$phase.Count
        uia_text2=$uia2
        uia_text=$uiaText
        win32_caret=$winCaret
        semantic_caret_selected=$uia2+$uiaText+$winCaret
        uia_focus_selected=$uiaFocus
        win32_focus_selected=$winFocus
        focus_selected=$uiaFocus+$winFocus
        pointer_selected=@($phase|Where-Object{[int]$_.poi_source-eq5}).Count
        caret_present=@($phase|Where-Object{[int]$_.uia_caret_present-eq1}).Count
        focus_present=@($phase|Where-Object{[int]$_.uia_focus_present-eq1}).Count
        locator=@($phase|Where-Object{[int]$_.locator_visible-eq1}).Count
        pan=@($phase|Where-Object{[int]$_.viewport_action-eq2}).Count
        invalid=@($phase|Where-Object{[int]$_.viewport_action-eq0}).Count
    }
}

$grid=Phase $gridStart $gridEnd
$formula=Phase $formulaStart $formulaEnd
$return=Phase $returnStart $returnEnd
$gridSummary=Summarize $grid
$formulaSummary=Summarize $formula
$returnSummary=Summarize $return
$presentFailures=@($rows|Where-Object{[uint64]$_.present_hr-ne0}).Count

$gridTracked=$gridSummary.semantic_caret_selected+$gridSummary.focus_selected
$gridTrackedRatio=if($grid.Count){$gridTracked/[double]$grid.Count}else{0}
$gridRects=@($grid|Where-Object{[int]$_.poi_source-in0,1,2,3,4}|ForEach-Object{"$($_.selected_left),$($_.selected_top),$($_.selected_right),$($_.selected_bottom)"}|Sort-Object -Unique)
$formulaCaretRatio=if($formula.Count){$formulaSummary.semantic_caret_selected/[double]$formula.Count}else{0}
$formulaPresentRatio=if($formula.Count){$formulaSummary.caret_present/[double]$formula.Count}else{0}
$returnFocus=$returnSummary.focus_selected+$returnSummary.semantic_caret_selected

$pass=(
    $presentFailures-eq0 -and
    $grid.Count-gt100 -and
    $gridTrackedRatio-ge0.75 -and
    $gridRects.Count-ge5 -and
    $formula.Count-gt80 -and
    $formulaPresentRatio-ge0.40 -and
    $formulaCaretRatio-ge0.35 -and
    $returnFocus-gt0 -and
    $gridSummary.locator-gt0 -and
    $formulaSummary.locator-gt0
)

$analysis=[ordered]@{
    office_version=(Get-Item 'C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE').VersionInfo.ProductVersion
    zoom=$Zoom
    cell_control_type=$cellControlType
    cell_class=$cellClass
    cell_patterns=@($cellPatterns)
    formula_bar_control_type=$formulaControlType
    formula_bar_class=$formulaClass
    formula_bar_patterns=@($formulaPatterns)
    grid_navigation=$gridSummary
    grid_tracked_ratio=[math]::Round($gridTrackedRatio,3)
    grid_distinct_tracked_rectangles=$gridRects.Count
    formula_editing=$formulaSummary
    formula_caret_present_ratio=[math]::Round($formulaPresentRatio,3)
    formula_caret_selected_ratio=[math]::Round($formulaCaretRatio,3)
    return_to_grid=$returnSummary
    present_failures=$presentFailures
    forced_vision_cleanup=$forcedVisionCleanup
    pass=$pass
}
$analysis|ConvertTo-Json -Depth 6|Set-Content (Join-Path $run 'analysis.json') -Encoding utf8
@(
    '# Vision Excel editing compatibility smoke','',
    "- Office/Excel version: $($analysis.office_version)",
    "- Cell UIA surface: $($analysis.cell_control_type), class=$($analysis.cell_class), patterns=$($analysis.cell_patterns -join ', ')",
    "- Formula bar UIA surface: $($analysis.formula_bar_control_type), class=$($analysis.formula_bar_class), patterns=$($analysis.formula_bar_patterns -join ', ')",
    "- Grid frames: $($grid.Count)",
    "- Grid tracked-target ratio: $([math]::Round(100*$gridTrackedRatio,1))%",
    "- Grid distinct tracked rectangles: $($gridRects.Count)",
    "- Grid locator frames: $($gridSummary.locator)",
    "- Formula frames: $($formula.Count)",
    "- Formula caret-present ratio: $([math]::Round(100*$formulaPresentRatio,1))%",
    "- Formula semantic-caret selected ratio: $([math]::Round(100*$formulaCaretRatio,1))%",
    "- Formula locator frames: $($formulaSummary.locator)",
    "- Return-to-grid tracked frames: $returnFocus",
    "- Present failures: $presentFailures",
    "- Forced Vision cleanup: $forcedVisionCleanup",
    "- Pass: $pass"
)-join[Environment]::NewLine|Set-Content (Join-Path $run 'SUMMARY.md') -Encoding utf8

Write-Host "Excel editing smoke complete: $run"
Get-Content (Join-Path $run 'SUMMARY.md')
if(-not$pass){throw "Excel editing compatibility smoke failed: $run"}
