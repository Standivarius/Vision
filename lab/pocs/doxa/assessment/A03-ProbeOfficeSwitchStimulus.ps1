# A03 ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â disposable Word/Excel application switching with selected-target proof.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -TypeDefinition @"
using System;using System.Runtime.InteropServices;
public static class VisionA03Native {
 [StructLayout(LayoutKind.Sequential)]public struct RECT{public int Left,Top,Right,Bottom;}
 [StructLayout(LayoutKind.Sequential)]public struct POINT{public int X,Y;}
 [StructLayout(LayoutKind.Sequential)]public struct GUITHREADINFO{
  public uint cbSize,flags;public IntPtr hwndActive,hwndFocus,hwndCapture,hwndMenuOwner,hwndMoveSize,hwndCaret;public RECT rcCaret;
 }
 [DllImport("user32.dll")]public static extern bool SetProcessDpiAwarenessContext(IntPtr c);
 [DllImport("user32.dll")]public static extern uint GetWindowThreadProcessId(IntPtr h,out uint pid);
 [DllImport("user32.dll")]public static extern bool GetGUIThreadInfo(uint tid,ref GUITHREADINFO info);
 [DllImport("user32.dll")]public static extern bool ClientToScreen(IntPtr hwnd,ref POINT p);
 [DllImport("user32.dll")]public static extern bool SetWindowPos(IntPtr h,IntPtr after,int x,int y,int width,int height,uint flags);
 [DllImport("user32.dll")]public static extern bool GetWindowRect(IntPtr h,out RECT rect);
 [DllImport("user32.dll")]public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")]public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")]public static extern bool GetCursorPos(out POINT p);
 [DllImport("user32.dll")]public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")]public static extern void mouse_event(uint flags,uint x,uint y,uint data,UIntPtr extra);
}
"@
[void][VisionA03Native]::SetProcessDpiAwarenessContext([IntPtr](-4))
. (Join-Path $PSScriptRoot 'Restore-VisionForeground.ps1')
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
Set-Location $root
$run=Join-Path $root ('artifacts\vision-poc-a-graphics-20261017\office-switch-stimulus-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,6))
[void][IO.Directory]::CreateDirectory($run)
$originalForeground=[VisionA03Native]::GetForegroundWindow()
$originalPointer=New-Object VisionA03Native+POINT
[void][VisionA03Native]::GetCursorPos([ref]$originalPointer)
$result=[ordered]@{scenario='A03-Word-Excel-4x-switch';status='INCONCLUSIVE';observations=@();workbook_saved=$false;document_saved=$false;focus_restored=$false;pointer_restored=$false}
$excel=$null;$book=$null;$sheet=$null;$word=$null;$doc=$null
function Get-AppWindow {
 param($com,[string]$name)
 $hwnd=[IntPtr]::Zero
 for($i=0;$i -lt 72;$i++){
   try{$v=[long]$com.Hwnd;if($v -ne 0){$hwnd=[IntPtr]$v;break}}catch{}
   $fallback=@(Get-Process -Name $(if($name -eq 'Word'){'WINWORD'}else{'EXCEL'}) -ErrorAction SilentlyContinue | Where-Object {$_.MainWindowHandle -ne [IntPtr]::Zero})
   if($fallback.Count -eq 1){$hwnd=$fallback[0].MainWindowHandle;break}
   Start-Sleep -Milliseconds 250
 }
 if($hwnd -eq [IntPtr]::Zero){throw ('No '+$name+' HWND')}
 $appPid=[uint32]0;$tid=[VisionA03Native]::GetWindowThreadProcessId($hwnd,[ref]$appPid)
 if($appPid -eq 0 -or $tid -eq 0){throw ('No '+$name+' PID')}
 return [pscustomobject]@{handle=$hwnd;pid=$appPid;tid=$tid}
}
function Activate-OnlyOwn {
 param([IntPtr]$hwnd,[uint32]$appPid)
 [void][VisionA03Native]::SetForegroundWindow($hwnd)
 Start-Sleep -Milliseconds 200
 $active=[uint32]0
 [void][VisionA03Native]::GetWindowThreadProcessId([VisionA03Native]::GetForegroundWindow(),[ref]$active)
 for($attempt=0;$active -ne $appPid -and $attempt -lt 4;$attempt++){
   # Reuse the verified bounded input-queue attachment method; clicking a
   # covered title bar risks activating the *other* Office application.
   $recovery=Restore-VisionForeground -OriginalHwnd $hwnd
   Start-Sleep -Milliseconds 230
   [void][VisionA03Native]::GetWindowThreadProcessId([VisionA03Native]::GetForegroundWindow(),[ref]$active)
 }
 return ($active -eq $appPid)
}
try{
 if(@(Get-Process EXCEL,WINWORD -ErrorAction SilentlyContinue).Count){throw 'BLOCKED: existing Word or Excel'}
 & python.exe 'lab\pocs\doxa\assessment\A02_display_preflight.py'|Out-Null
 if($LASTEXITCODE -ne 0){throw 'BLOCKED: three/four unlocked physical displays required'}
 $screens=@([Windows.Forms.Screen]::AllScreens|Where-Object{-not $_.Primary}|Sort-Object{$_.Bounds.Left})
 if($screens.Count -lt 2 -or $screens.Count -gt 3){throw 'BLOCKED: unexpected source screen count'}
 $right=$screens[-1].Bounds
 $result['right_bounds']=@{left=$right.Left;top=$right.Top;right=$right.Right;bottom=$right.Bottom}
 # Two completely new, unsaved test documents. Never attach existing sessions.
 $word=New-Object -ComObject Word.Application
 $word.Visible=$true;$word.DisplayAlerts=0
 $doc=$word.Documents.Add()
 $lines=@(1..70|ForEach-Object{'VISION SWITCH TEST LINE '+$_+' ; reading selection ALPHA BETA GAMMA DELTA EPSILON'})
 $doc.Content.Text=($lines -join [Environment]::NewLine)
 $doc.Content.Font.Name='Calibri';$doc.Content.Font.Size=16
 $wp=Get-AppWindow $word 'Word'
 [void][VisionA03Native]::SetWindowPos($wp.handle,[IntPtr]::Zero,$right.Left+50,$right.Top+65,[Math]::Min(1720,$right.Width-100),[Math]::Min(900,$right.Height-110),0x0040)
 $excel=New-Object -ComObject Excel.Application
 $excel.Visible=$true;$excel.DisplayAlerts=$false
 $book=$excel.Workbooks.Add();$sheet=$book.Worksheets.Item(1)
 $sheet.Columns.Item('A:L').ColumnWidth=15
 $sheet.Rows.Item('1:50').RowHeight=24
 foreach($r in 1..47){foreach($c in 1..12){$sheet.Cells.Item($r,$c).Value2=('VISION CELL '+$r+' '+$c)}}
 $excel.WindowState=-4143
 $ep=Get-AppWindow $excel 'Excel'
 [void][VisionA03Native]::SetWindowPos($ep.handle,[IntPtr]::Zero,$right.Left+45,$right.Top+65,[Math]::Min(1700,$right.Width-100),[Math]::Min(900,$right.Height-110),0x0040)
 $result['word_pid']=$wp.pid;$result['excel_pid']=$ep.pid
 $result['word_window_on_right']=(($wp.pid -ne $ep.pid) -and $wp.pid -gt 0)
 $result['excel_window_on_right']=($ep.pid -gt 0)
 $wordMarkers=@(50,1450,2800)
 $excelTargets=@('B2','J24','C41')
 $lastWord=$null;$lastExcel=$null
 Start-Sleep -Seconds 9 # independent capture startup
 foreach($step in 0..5){
   $isWord=($step%2 -eq 0)
   $color=if($isWord){'YELLOW'}else{'GREEN'}
   $obs=[ordered]@{step=$step;app=if($isWord){'WORD'}else{'EXCEL'};colour=$color;phase_start_qpc_ns=$null;phase_end_qpc_ns=$null;expected_pid=if($isWord){$wp.pid}else{$ep.pid};foreground_owned=$false;window_on_right=$false;target_verified=$false;target=$null;source_rect=$null}
   if($isWord){
     $position=$wordMarkers[[int]($step/2)]
     if($lastWord){$lastWord.HighlightColorIndex=0}
     $highlight=$doc.Range($position,$position+18)
     $highlight.HighlightColorIndex=7
     $lastWord=$highlight
     $word.Activate()
     $word.Selection.SetRange($position+8,$position+8)
     $word.Selection.Collapse(1)
     try{$word.ActiveWindow.ScrollIntoView($word.Selection.Range,$true)}catch{}
     $obs.target=$position
     $obs.foreground_owned=Activate-OnlyOwn $wp.handle $wp.pid
   }else{
     $targetId=$excelTargets[[int](($step-1)/2)]
     if($lastExcel){$lastExcel.Interior.Pattern=-4142}
     $target=$sheet.Range($targetId)
     $lastColumn=[Math]::Min(12,[int]$target.Column+2)
     $highlight=$sheet.Range($target,$sheet.Cells.Item(([int]$target.Row+1),$lastColumn))
     $highlight.Interior.Color=65280 # bright lime marker, unlike Word yellow
     $lastExcel=$highlight
     $book.Activate()
     [void]$excel.Goto($target,$false)
     $obs.target=$targetId
     $obs.foreground_owned=Activate-OnlyOwn $ep.handle $ep.pid
   }
   $obs.phase_start_qpc_ns=[long]([Diagnostics.Stopwatch]::GetTimestamp()*1e9/[Diagnostics.Stopwatch]::Frequency)
   Start-Sleep -Milliseconds 3900
   if($isWord){
     $info=New-Object VisionA03Native+GUITHREADINFO
     $info.cbSize=[Runtime.InteropServices.Marshal]::SizeOf([type][VisionA03Native+GUITHREADINFO])
     if([VisionA03Native]::GetGUIThreadInfo($wp.tid,[ref]$info)){
       $caretp=[uint32]0
       [void][VisionA03Native]::GetWindowThreadProcessId($info.hwndCaret,[ref]$caretp)
       if($info.hwndCaret -ne [IntPtr]::Zero -and $caretp -eq $wp.pid){
         $pt=New-Object VisionA03Native+POINT
         $pt.X=$info.rcCaret.Left;$pt.Y=$info.rcCaret.Top
         if([VisionA03Native]::ClientToScreen($info.hwndCaret,[ref]$pt)){
           $obs.source_rect=@{left=$pt.X;top=$pt.Y;right=$pt.X+($info.rcCaret.Right-$info.rcCaret.Left);bottom=$pt.Y+($info.rcCaret.Bottom-$info.rcCaret.Top)}
         }
       }
     }
     $obs.target_verified=($obs.foreground_owned -and $null -ne $obs.source_rect)
   }else{
     $active=[string]$excel.ActiveCell.Address($false,$false)
     $obs['com_active_cell']=$active
     try{
       $focused=[Windows.Automation.AutomationElement]::FocusedElement
       if($focused -and $focused.Current.ProcessId -eq $ep.pid){
         $obs['uia_name']=[string]$focused.Current.Name
         $bounds=$focused.Current.BoundingRectangle
         if(-not $bounds.IsEmpty -and $bounds.Width -gt 0 -and $bounds.Height -gt 0){
           $obs.source_rect=@{left=$bounds.Left;top=$bounds.Top;right=$bounds.Right;bottom=$bounds.Bottom}
         }
       }
     }catch{}
     $obs.target_verified=($obs.foreground_owned -and $active -eq $obs.target -and $obs.uia_name -eq $obs.target -and $null -ne $obs.source_rect)
   }
   $obs.window_on_right=($null -ne $obs.source_rect -and $obs.source_rect.left -ge $right.Left -and $obs.source_rect.right -le $right.Right -and $obs.source_rect.top -ge $right.Top -and $obs.source_rect.bottom -le $right.Bottom)
   $obs.phase_end_qpc_ns=[long]([Diagnostics.Stopwatch]::GetTimestamp()*1e9/[Diagnostics.Stopwatch]::Frequency)
   $result.observations+=,$obs
 }
 $valid=@($result.observations|Where-Object{$_.foreground_owned -and $_.target_verified -and $_.window_on_right})
 $result['source_verified_steps']=$valid.Count
 $result.status=if($valid.Count -eq 6){'PASS_SOURCE_SWITCH_TRUTH'}else{'INCONCLUSIVE'}
}catch{
 $msg=$_.Exception.Message;$result['error']=$msg
 $result.status=if($msg.StartsWith('BLOCKED:')){'BLOCKED'}else{'INCONCLUSIVE'}
}finally{
 try{if($doc){$doc.Close(0)}}catch{}
 try{if($word){$word.Quit()}}catch{}
 try{if($book){$book.Close($false)}}catch{}
 try{if($excel){$excel.Quit()}}catch{}
 foreach($o in @($lastWord,$lastExcel,$doc,$word,$sheet,$book,$excel)){
   if($o){try{[void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($o)}catch{}}
 }
 [GC]::Collect();[GC]::WaitForPendingFinalizers()
 [void][VisionA03Native]::SetCursorPos($originalPointer.X,$originalPointer.Y)
 $after=New-Object VisionA03Native+POINT
 [void][VisionA03Native]::GetCursorPos([ref]$after)
 $result.pointer_restored=($after.X -eq $originalPointer.X -and $after.Y -eq $originalPointer.Y)
 $restored=Restore-VisionForeground -OriginalHwnd $originalForeground
 $result.focus_restored=[bool]$restored.restored
 $result['focus_restore_method']=$restored.status
 $result['finished_utc']=[DateTime]::UtcNow.ToString('o')
 [IO.File]::WriteAllText((Join-Path $run 'result.json'),($result|ConvertTo-Json -Depth 7),[Text.UTF8Encoding]::new($false))
}
$result|ConvertTo-Json -Depth 5
if($result.status -eq 'PASS_SOURCE_SWITCH_TRUTH'){exit 0}else{exit 3}
