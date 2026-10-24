# A03 mixed Word/Excel 4x source stimulus, generated documents only.
# The selection/edit commands are native Office COM, not physical keyboard input.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -TypeDefinition @"
using System;using System.Runtime.InteropServices;
public static class VisionMixedNative {
 [StructLayout(LayoutKind.Sequential)]public struct RECT {public int Left,Top,Right,Bottom;}
 [StructLayout(LayoutKind.Sequential)]public struct POINT {public int X,Y;}
 [StructLayout(LayoutKind.Sequential)]public struct GUITHREADINFO {
  public uint cbSize, flags;public IntPtr hwndActive,hwndFocus,hwndCapture,hwndMenuOwner,hwndMoveSize,hwndCaret;public RECT rcCaret;
 }
 [DllImport("user32.dll")]public static extern bool SetProcessDpiAwarenessContext(IntPtr c);
 [DllImport("user32.dll")]public static extern uint GetWindowThreadProcessId(IntPtr h,out uint pid);
 [DllImport("user32.dll")]public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")]public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")]public static extern bool SetWindowPos(IntPtr h,IntPtr after,int x,int y,int w,int ht,uint flags);
 [DllImport("user32.dll")]public static extern bool GetWindowRect(IntPtr h,out RECT r);
 [DllImport("user32.dll")]public static extern bool GetCursorPos(out POINT p);
 [DllImport("user32.dll")]public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")]public static extern bool GetGUIThreadInfo(uint id,ref GUITHREADINFO info);
 [DllImport("user32.dll")]public static extern bool ClientToScreen(IntPtr h,ref POINT pt);
}
"@
[void][VisionMixedNative]::SetProcessDpiAwarenessContext([IntPtr](-4))
. (Join-Path $PSScriptRoot 'Restore-VisionForeground.ps1')
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$run=Join-Path $root ('artifacts\vision-poc-a-graphics-20261017\mixed-office-stimulus-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,6))
[void][IO.Directory]::CreateDirectory($run)
$original=[VisionMixedNative]::GetForegroundWindow()
$pointer=New-Object VisionMixedNative+POINT
[void][VisionMixedNative]::GetCursorPos([ref]$pointer)
$report=[ordered]@{
 scenario='A03-Word-Excel-4x-focus-and-edit';status='INCONCLUSIVE'
 source_role='RIGHT';source_original_hwnd=$original.ToInt64();observations=@()
 documents_saved=$false;focus_restored=$false
}
function Set-MixedOwnedForeground {
 param([IntPtr]$Window,[uint32]$ProcessId)
 $result=Restore-VisionForeground -OriginalHwnd $Window
 $actual=[uint32]0
 [void][VisionMixedNative]::GetWindowThreadProcessId([VisionMixedNative]::GetForegroundWindow(),[ref]$actual)
 if(-not $result.restored -or $actual -ne $ProcessId){
   throw ('OWNED_OFFICE_FOCUS_REJECTED expected '+$ProcessId+' actual '+$actual+' method '+$result.status)
 }
}
$word=$null;$doc=$null;$excel=$null;$book=$null;$sheet=$null
$wordPid=[uint32]0;$excelPid=[uint32]0
try{
 if(@(Get-Process WINWORD,EXCEL -ErrorAction SilentlyContinue).Count){throw 'BLOCKED: existing Office process'}
 if(@(Get-Process visual_app -ErrorAction SilentlyContinue).Count){throw 'BLOCKED: preexisting Vision preview'}
 & python.exe 'lab\pocs\doxa\assessment\A02_display_preflight.py' |Out-Null
 if($LASTEXITCODE -ne 0){throw 'BLOCKED: physical console unavailable'}
 $screens=@([Windows.Forms.Screen]::AllScreens|Where-Object{-not $_.Primary}|Sort-Object{$_.Bounds.Left})
 if($screens.Count -notin @(2,3)){throw 'BLOCKED: expected 3 or 4 active displays'}
 $right=$screens[-1].Bounds
 $report['right_bounds']=@{left=$right.Left;top=$right.Top;right=$right.Right;bottom=$right.Bottom}
 $word=New-Object -ComObject Word.Application
 $word.Visible=$true
 $word.DisplayAlerts=0
 $doc=$word.Documents.Add()
 $lines=@()
 foreach($i in 1..48){$lines+=('VISION MIXED OFFICE GENERATED LINE '+$i+' :: ALPHA BETA GAMMA DELTA EPSILON')}
 $doc.Content.Text=($lines -join [Environment]::NewLine)
 $doc.Content.Font.Name='Calibri';$doc.Content.Font.Size=15
 $excel=New-Object -ComObject Excel.Application
 $excel.Visible=$true
 $excel.DisplayAlerts=$false
 $book=$excel.Workbooks.Add()
 $sheet=$book.Worksheets.Item(1)
 $sheet.Columns.Item('A:L').ColumnWidth=14
 $sheet.Rows.Item('1:52').RowHeight=25
 foreach($i in 1..46){foreach($j in 1..12){$sheet.Cells.Item($i,$j).Value2=('VISION MIXED '+$i+' '+$j)}}
 $whwnd=[IntPtr]::Zero;$ehwnd=[IntPtr]::Zero
 for($attempt=0;$attempt -lt 80;$attempt++){
   $wValue=[long]0;$eValue=[long]0
   try{$wValue=[long]$word.Hwnd}catch{}
   try{$eValue=[long]$excel.Hwnd}catch{}
   if($wValue -ne 0){$whwnd=[IntPtr]$wValue}
   if($eValue -ne 0){$ehwnd=[IntPtr]$eValue}
   if($whwnd -eq [IntPtr]::Zero){
     $wp=@(Get-Process WINWORD -ErrorAction SilentlyContinue|Where-Object{$_.MainWindowHandle -ne [IntPtr]::Zero})
     if($wp.Count -eq 1){$whwnd=$wp[0].MainWindowHandle}
   }
   if($ehwnd -eq [IntPtr]::Zero){
     $ep=@(Get-Process EXCEL -ErrorAction SilentlyContinue|Where-Object{$_.MainWindowHandle -ne [IntPtr]::Zero})
     if($ep.Count -eq 1){$ehwnd=$ep[0].MainWindowHandle}
   }
   if($whwnd -ne [IntPtr]::Zero -and $ehwnd -ne [IntPtr]::Zero){break}
   Start-Sleep -Milliseconds 250
 }
 $report['word_hwnd']=$whwnd.ToInt64()
 $report['excel_hwnd']=$ehwnd.ToInt64()
 $wordThread=[VisionMixedNative]::GetWindowThreadProcessId($whwnd,[ref]$wordPid)
 $excelThread=[VisionMixedNative]::GetWindowThreadProcessId($ehwnd,[ref]$excelPid)
 if($wordThread -eq 0 -or $excelThread -eq 0){throw 'Office top-level window unavailable'}
 $report['word_pid']=$wordPid;$report['excel_pid']=$excelPid
 $excel.WindowState=-4143
 [void][VisionMixedNative]::SetWindowPos($whwnd,[IntPtr]::Zero,$right.Left+55,$right.Top+70,1660,830,0x0040)
 [void][VisionMixedNative]::SetWindowPos($ehwnd,[IntPtr]::Zero,$right.Left+75,$right.Top+75,1660,830,0x0040)
 # Leave both freshly spawned Office windows ready before parent starts GDI recorders.
 Start-Sleep -Seconds 8
 # Setup-only activation warmup: not eligible for PASS. Windows Terminal
 # occasionally takes the first foreground slot as Office initialises.
 # We do not conceal this transition or count it as tested behaviour.
 $word.Activate()
 Set-MixedOwnedForeground -Window $whwnd -ProcessId $wordPid
 Start-Sleep -Milliseconds 2200
 $book.Activate()
 Set-MixedOwnedForeground -Window $ehwnd -ProcessId $excelPid
 [void]$excel.Goto($sheet.Range('A1'),$false)
 Start-Sleep -Milliseconds 2200
 $report['warmup_not_scored']=@('WORD','EXCEL')
 $targets=@(
  @{app='WORD';offset=185;colour='YELLOW'},
  @{app='EXCEL';cell='H4';colour='GREEN'},
  @{app='WORD';offset=1410;colour='YELLOW'},
  @{app='EXCEL';cell='B32';colour='GREEN'},
  @{app='WORD';offset=520;colour='YELLOW'},
  @{app='EXCEL';cell='J8';colour='GREEN'}
 )
 $oldWord=$null;$oldExcel=$null
 for($step=0;$step -lt $targets.Count;$step++){
   $phase=$targets[$step]
   $active=[string]$phase.app
   if($active -eq 'WORD'){
     $word.Activate()
     Set-MixedOwnedForeground -Window $whwnd -ProcessId $wordPid
     if($oldWord){$oldWord.HighlightColorIndex=0}
     $pos=[Math]::Min([int]$phase.offset,[Math]::Max(0,$doc.Content.End-36))
     $word.Selection.SetRange($pos,$pos)
     $word.Selection.TypeText((' VISION EDIT STEP '+$step+' '))
     $selection=$word.Selection.Range
     $highlight=$doc.Range([Math]::Max(0,[int]$selection.Start-17),[int]$selection.Start)
     $highlight.HighlightColorIndex=7
     $oldWord=$highlight
     try{$word.ActiveWindow.ScrollIntoView($word.Selection.Range,$true)}catch{}
     Set-MixedOwnedForeground -Window $whwnd -ProcessId $wordPid
   }else{
     $book.Activate()
     Set-MixedOwnedForeground -Window $ehwnd -ProcessId $excelPid
     if($oldExcel){$oldExcel.Interior.Pattern=-4142}
     $target=$sheet.Range([string]$phase.cell)
     $target.Value2=('VISION EDITED STEP '+$step)
     $endColumn=[Math]::Min(12,[int]$target.Column+2)
     $marker=$sheet.Range($target,$sheet.Cells.Item(([int]$target.Row+1),$endColumn))
     $marker.Interior.Color=65280
     $oldExcel=$marker
     [void]$excel.Goto($target,$false)
     Set-MixedOwnedForeground -Window $ehwnd -ProcessId $excelPid
   }
   Start-Sleep -Milliseconds 250
   $from=[long]([Diagnostics.Stopwatch]::GetTimestamp()*1.0e9/[Diagnostics.Stopwatch]::Frequency)
   Start-Sleep -Milliseconds 4400
   $until=[long]([Diagnostics.Stopwatch]::GetTimestamp()*1.0e9/[Diagnostics.Stopwatch]::Frequency)
   $fg=[uint32]0
   [void][VisionMixedNative]::GetWindowThreadProcessId([VisionMixedNative]::GetForegroundWindow(),[ref]$fg)
   $record=[ordered]@{
     step=$step;app=$active;colour=[string]$phase.colour
     target_cell=if($active -eq 'EXCEL'){$phase.cell}else{$null}
     phase_start_qpc_ns=$from;phase_end_qpc_ns=$until
     expected_pid=if($active -eq 'WORD'){$wordPid}else{$excelPid}
     foreground_pid=$fg;foreground_matches=($fg -eq $(if($active -eq 'WORD'){$wordPid}else{$excelPid}))
     com_cell=$null;uia_focus_pid=$null;uia_focus_name=$null;uia_bounds=$null;word_caret=$null
   }
   if($active -eq 'EXCEL'){
      $record.com_cell=[string]$excel.ActiveCell.Address($false,$false)
      try{
       $elem=[Windows.Automation.AutomationElement]::FocusedElement
       if($elem){
        $record.uia_focus_pid=$elem.Current.ProcessId
        $record.uia_focus_name=[string]$elem.Current.Name
        $bounds=$elem.Current.BoundingRectangle
        if(-not $bounds.IsEmpty -and $bounds.Width -gt 0 -and $bounds.Height -gt 0){
         $record.uia_bounds=@{left=$bounds.Left;top=$bounds.Top;right=$bounds.Right;bottom=$bounds.Bottom}
        }
       }
      }catch{}
   }else{
      $info=New-Object VisionMixedNative+GUITHREADINFO
      $info.cbSize=[Runtime.InteropServices.Marshal]::SizeOf([type][VisionMixedNative+GUITHREADINFO])
      if([VisionMixedNative]::GetGUIThreadInfo($wordThread,[ref]$info) -and $info.hwndCaret -ne [IntPtr]::Zero){
        $caretPid=[uint32]0
        [void][VisionMixedNative]::GetWindowThreadProcessId($info.hwndCaret,[ref]$caretPid)
        if($caretPid -eq $wordPid){
          $pt=New-Object VisionMixedNative+POINT
          $pt.X=$info.rcCaret.Left;$pt.Y=$info.rcCaret.Top
          if([VisionMixedNative]::ClientToScreen($info.hwndCaret,[ref]$pt)){
           $record.word_caret=@{left=$pt.X;top=$pt.Y;right=$pt.X+($info.rcCaret.Right-$info.rcCaret.Left);bottom=$pt.Y+($info.rcCaret.Bottom-$info.rcCaret.Top)}
          }
        }
      }
   }
   $report.observations+=,$record
 }
 $valid=@($report.observations|Where-Object{$_.foreground_matches -and (
   ($_.app -eq 'WORD' -and $null -ne $_.word_caret) -or
   ($_.app -eq 'EXCEL' -and $_.com_cell -eq $_.target_cell -and
    $_.uia_focus_pid -eq $excelPid -and $_.uia_focus_name -eq $_.target_cell -and
    $null -ne $_.uia_bounds)
 )})
 $report['provenanced_phases']=$valid.Count
 $report.status=if($valid.Count -eq $targets.Count){'PASS_SOURCE_MIXED_OFFICE'}else{'INCONCLUSIVE'}
}catch{
 $message=$_.Exception.Message
 $report['error']=$message
 $report.status=if($message.StartsWith('BLOCKED:')){'BLOCKED'}else{'INCONCLUSIVE'}
}finally{
 try{if($doc){$doc.Close(0)}}catch{}
 try{if($book){$book.Close($false)}}catch{}
 try{if($word){$word.Quit()}}catch{}
 try{if($excel){$excel.Quit()}}catch{}
 foreach($o in @($oldWord,$oldExcel,$sheet,$book,$doc,$word,$excel)){
  if($o){try{[void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($o)}catch{}}
 }
 [GC]::Collect();[GC]::WaitForPendingFinalizers()
 [void][VisionMixedNative]::SetCursorPos($pointer.X,$pointer.Y)
 $restore=Restore-VisionForeground -OriginalHwnd $original
 $report.focus_restored=[bool]$restore.restored
 $report['focus_restore_method']=$restore.status
 $report['finished_utc']=[DateTime]::UtcNow.ToString('o')
 [IO.File]::WriteAllText((Join-Path $run 'result.json'),($report|ConvertTo-Json -Depth 7),[Text.UTF8Encoding]::new($false))
}
$report|ConvertTo-Json -Depth 5
if($report.status -eq 'PASS_SOURCE_MIXED_OFFICE'){exit 0}else{exit 3}
