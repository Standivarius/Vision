param(
 [Parameter(Mandatory=$true)][string]$OutputDir,
 [ValidateRange(1.0,16.0)][double]$TestZoom=4.0,
 [ValidateRange(8,80)][int]$Steps=32,
 [ValidateRange(75,1000)][int]$SettleMs=180
)
$ErrorActionPreference='Stop'
if([IntPtr]::Size -ne 4){throw 'Run this harness with 32-bit Windows PowerShell (SysWOW64) for ZoomText COM registration.'}
$ztProcess=Get-Process Zt -ErrorAction SilentlyContinue | Select-Object -First 1
if(-not$ztProcess){throw 'ZoomText must already be running in the current user session. The harness will not start it automatically.'}

$out=[IO.Path]::GetFullPath($OutputDir)
New-Item -ItemType Directory -Force $out|Out-Null
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

function Rect-ToObject($rect){
 if($null-eq$rect){return $null}
 [pscustomobject]@{left=[int]$rect.left;top=[int]$rect.top;right=[int]$rect.right;bottom=[int]$rect.bottom}
}
function Get-UiaCaret {
 try{
  $e=[System.Windows.Automation.AutomationElement]::FocusedElement
  if(-not$e){return $null}
  $patterns=@($e.GetSupportedPatterns()|ForEach-Object{$_.ProgrammaticName})
  if(-not($patterns -contains 'TextPatternIdentifiers.Pattern')){return $null}
  $tp=$e.GetCurrentPattern([System.Windows.Automation.TextPattern]::Pattern)
  $sel=@($tp.GetSelection())
  if(-not$sel.Count){return $null}
  $rects=@($sel[0].GetBoundingRectangles())
  if(-not$rects.Count){return $null}
  $r=$rects[0]
  return [pscustomobject]@{
   process_id=[int]$e.Current.ProcessId
   control_type=$e.Current.ControlType.ProgrammaticName
   left=[double]$r.Left
   top=[double]$r.Top
   width=[double]$r.Width
   height=[double]$r.Height
   right=[double]$r.Right
   bottom=[double]$r.Bottom
  }
 }catch{return $null}
}

$zt=$null;$word=$null;$doc=$null;$shell=$null
$original=$null
$samples=New-Object System.Collections.Generic.List[object]
$sw=[Diagnostics.Stopwatch]::StartNew()
try{
 $zt=New-Object -ComObject 'ZoomText.Application'
 $mag=$zt.Magnification
 $window=$mag.PrimaryWindow
 $tracking=$mag.Tracking
 $power=$window.Power
 $original=[ordered]@{
   zoom=[double]$power.Level
   tracking_enabled=[bool]$tracking.Enabled
   text_cursor_enabled=[bool]$tracking.TextCursorEnabled
   mouse_pointer_enabled=[bool]$tracking.MousePointerEnabled
   view=Rect-ToObject $window.View
 }
 $original|ConvertTo-Json -Depth 4|Set-Content -Encoding UTF8 (Join-Path $out 'zoomtext_state_before.json')

 $power.Level=[single]$TestZoom
 $tracking.Enabled=$true
 $tracking.TextCursorEnabled=$true
 $tracking.MousePointerEnabled=$false
 Start-Sleep -Milliseconds 500

 $word=New-Object -ComObject Word.Application
 $word.Visible=$true
 $word.DisplayAlerts=0
 $doc=$word.Documents.Add()
 $paragraphs=New-Object System.Text.StringBuilder
 for($i=1;$i-le60;$i++){
   [void]$paragraphs.Append(('Vision ZoomText caret pilot line {0:00} - synthetic text for controlled tracking observation.' -f $i))
   [void]$paragraphs.Append([Environment]::NewLine)
 }
 $doc.Content.Text=$paragraphs.ToString()
 $word.Activate()
 $doc.Activate()
 $sel=$word.Selection
 $sel.SetRange(0,0)
 $sel.Collapse(1)
 $shell=New-Object -ComObject WScript.Shell
 [void]$shell.AppActivate($word.Caption)
 Start-Sleep -Milliseconds 650

 for($i=0;$i-lt$Steps;$i++){
   if($i-gt0){
     $shell.SendKeys('{DOWN}')
     Start-Sleep -Milliseconds $SettleMs
   }
   $view=$window.View
   $caret=Get-UiaCaret
   $samples.Add([pscustomobject]@{
     step=$i
     elapsed_ms=[math]::Round($sw.Elapsed.TotalMilliseconds,1)
     zoom=[double]$power.Level
     tracking_enabled=[bool]$tracking.Enabled
     text_cursor_enabled=[bool]$tracking.TextCursorEnabled
     mouse_pointer_enabled=[bool]$tracking.MousePointerEnabled
     view_left=[int]$view.left
     view_top=[int]$view.top
     view_right=[int]$view.right
     view_bottom=[int]$view.bottom
     caret_pid=if($caret){$caret.process_id}else{0}
     caret_type=if($caret){$caret.control_type}else{$null}
     caret_left=if($caret){$caret.left}else{$null}
     caret_top=if($caret){$caret.top}else{$null}
     caret_right=if($caret){$caret.right}else{$null}
     caret_bottom=if($caret){$caret.bottom}else{$null}
   })
 }
 $samples|Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $out 'caret_view_samples.csv')

 $viewChanges=0
 for($i=1;$i-lt$samples.Count;$i++){
   if($samples[$i].view_left-ne$samples[$i-1].view_left -or
      $samples[$i].view_top-ne$samples[$i-1].view_top -or
      $samples[$i].view_right-ne$samples[$i-1].view_right -or
      $samples[$i].view_bottom-ne$samples[$i-1].view_bottom){$viewChanges++}
 }
 $caretSamples=@($samples|Where-Object{$null-ne$_.caret_left})
 $summary=[ordered]@{
   zoomtext_pid=$ztProcess.Id
   word_pid=if($word){$word.Hwnd}else{0}
   test_zoom=$TestZoom
   steps=$Steps
   sample_count=$samples.Count
   uia_caret_sample_count=$caretSamples.Count
   viewport_change_steps=$viewChanges
   initial_view=if($samples.Count){[ordered]@{left=$samples[0].view_left;top=$samples[0].view_top;right=$samples[0].view_right;bottom=$samples[0].view_bottom}}else{$null}
   final_view=if($samples.Count){[ordered]@{left=$samples[-1].view_left;top=$samples[-1].view_top;right=$samples[-1].view_right;bottom=$samples[-1].view_bottom}}else{$null}
   interpretation_boundary='Viewport changes are observed through ZoomText public COM state. This harness does not by itself prove which internal provider caused each movement.'
 }
 $summary|ConvertTo-Json -Depth 5|Set-Content -Encoding UTF8 (Join-Path $out 'summary.json')
 $summary|ConvertTo-Json -Depth 5
}
finally{
 try{
   if($original -and $zt){
     $mag=$zt.Magnification;$window=$mag.PrimaryWindow;$tracking=$mag.Tracking;$power=$window.Power
     $power.Level=[single]$original.zoom
     $tracking.Enabled=[bool]$original.tracking_enabled
     $tracking.TextCursorEnabled=[bool]$original.text_cursor_enabled
     $tracking.MousePointerEnabled=[bool]$original.mouse_pointer_enabled
   }
 }catch{}
 try{if($doc){$doc.Close(0)}}catch{}
 try{if($word){$word.Quit()}}catch{}
 foreach($obj in @($doc,$word,$zt,$shell)){
   if($obj){try{[void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($obj)}catch{}}
 }
 [GC]::Collect();[GC]::WaitForPendingFinalizers()
 if($original){$original|ConvertTo-Json -Depth 4|Set-Content -Encoding UTF8 (Join-Path $out 'zoomtext_state_restored_target.json')}
}