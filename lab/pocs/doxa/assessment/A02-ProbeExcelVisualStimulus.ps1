# A02 disposable Excel alternating-marker stimulus; independent source truth.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -TypeDefinition @"
using System;using System.Runtime.InteropServices;
public static class VisionExcelVisualNative {
 [StructLayout(LayoutKind.Sequential)]public struct RECT {public int Left,Top,Right,Bottom;}
 [StructLayout(LayoutKind.Sequential)]public struct POINT {public int X,Y;}
 [DllImport("user32.dll")]public static extern bool SetProcessDpiAwarenessContext(IntPtr c);
 [DllImport("user32.dll")]public static extern uint GetWindowThreadProcessId(IntPtr h,out uint pid);
 [DllImport("user32.dll")]public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")]public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")]public static extern bool SetWindowPos(IntPtr h,IntPtr after,int x,int y,int w,int ht,uint flags);
 [DllImport("user32.dll")]public static extern bool GetWindowRect(IntPtr h,out RECT r);
 [DllImport("user32.dll")]public static extern bool GetCursorPos(out POINT p);
 [DllImport("user32.dll")]public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")]public static extern void mouse_event(uint flags,uint x,uint y,uint data,UIntPtr extra);
}
"@
[void][VisionExcelVisualNative]::SetProcessDpiAwarenessContext([IntPtr](-4))
. (Join-Path $PSScriptRoot 'Restore-VisionForeground.ps1')
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$run=Join-Path $root ('artifacts\vision-poc-a-graphics-20261017\excel-marker-stimulus-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,6))
[void][IO.Directory]::CreateDirectory($run)
$original=[VisionExcelVisualNative]::GetForegroundWindow()
$pointer=New-Object VisionExcelVisualNative+POINT
[void][VisionExcelVisualNative]::GetCursorPos([ref]$pointer)
$result=[ordered]@{scenario='A02-Excel-4x-visible-cell-marker';status='INCONCLUSIVE';source_role='RIGHT';observations=@();workbook_saved=$false;focus_restored=$false;marker_cells=@('B2','H4','J26','C31','I8','B42')}
$excel=$null;$book=$null;$sheet=$null;$pidExcel=[uint32]0;$previous=$null
try{
 if(@(Get-Process EXCEL -ErrorAction SilentlyContinue).Count){throw 'BLOCKED: existing Excel session'}
 & python.exe 'lab\pocs\doxa\assessment\A02_display_preflight.py' |Out-Null
 if($LASTEXITCODE -ne 0){throw 'BLOCKED: three-or-four-screen physical console unavailable'}
 $screens=@([Windows.Forms.Screen]::AllScreens|Where-Object{-not $_.Primary}|Sort-Object{$_.Bounds.Left})
 if($screens.Count -lt 2){throw 'BLOCKED: fewer than two external monitors'}
 $right=$screens[-1].Bounds
 $result['physical_right_bounds']=@{left=$right.Left;top=$right.Top;right=$right.Right;bottom=$right.Bottom}
 $excel=New-Object -ComObject Excel.Application
 $excel.Visible=$true
 $excel.DisplayAlerts=$false
 $book=$excel.Workbooks.Add()
 $sheet=$book.Worksheets.Item(1)
 $sheet.Columns.Item('A:L').ColumnWidth=14
 $sheet.Rows.Item('1:54').RowHeight=25
 # Restrict content to an unsaved, newly-created and uniquely identifiable fixture.
 foreach($row in 1..48){
   foreach($column in 1..12){
     $sheet.Cells.Item($row,$column).Value2=('VISION CELL '+$row+' '+$column)
   }
 }
 $hwnd=[IntPtr]::Zero
 for($attempt=0;$attempt -lt 48;$attempt++){
  $id=0
  try{$id=[long]$excel.Hwnd}catch{}
  if($id -ne 0){$hwnd=[IntPtr]$id;break}
  Start-Sleep -Milliseconds 250
 }
 $tid=[VisionExcelVisualNative]::GetWindowThreadProcessId($hwnd,[ref]$pidExcel)
 if($tid -eq 0 -or $pidExcel -eq 0){throw 'Excel window did not appear'}
 $result['spawned_excel_pid']=$pidExcel
 $excel.WindowState=-4143
 [void][VisionExcelVisualNative]::SetWindowPos($hwnd,[IntPtr]::Zero,$right.Left+40,$right.Top+70,[Math]::Min(1740,$right.Width-80),[Math]::Min(890,$right.Height-130),0x0040)
 [void][VisionExcelVisualNative]::SetForegroundWindow($hwnd)
 Start-Sleep -Milliseconds 250
 $window=New-Object VisionExcelVisualNative+RECT
 [void][VisionExcelVisualNative]::GetWindowRect($hwnd,[ref]$window)
 $result['excel_window_bounds']=@{left=$window.Left;top=$window.Top;right=$window.Right;bottom=$window.Bottom}
 $fg=[uint32]0
 [void][VisionExcelVisualNative]::GetWindowThreadProcessId([VisionExcelVisualNative]::GetForegroundWindow(),[ref]$fg)
 if($fg -ne $pidExcel){
   [void][VisionExcelVisualNative]::SetCursorPos($window.Left+260,$window.Top+12)
   Start-Sleep -Milliseconds 100
   [VisionExcelVisualNative]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
   Start-Sleep -Milliseconds 80
   [VisionExcelVisualNative]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
   Start-Sleep -Milliseconds 220
 }
 Start-Sleep -Seconds 7 # allow other process to start independent GDI capture
 foreach($step in 0..5){
   $id=[string]$result.marker_cells[$step]
   if($previous){$previous.Interior.Pattern=-4142}
   $target=$sheet.Range($id)
   $lastColumn=[Math]::Min(12,[int]$target.Column+2)
   $marker=$sheet.Range($target,$sheet.Cells.Item(([int]$target.Row+1),$lastColumn))
   $marker.Interior.Color=if($step%2 -eq 0){65535}else{65280} # Excel OLE yellow/lime
   $previous=$marker
   [void]$excel.Goto($target,$false)
   [void][VisionExcelVisualNative]::SetForegroundWindow($hwnd)
   $phaseStart=[long]([Diagnostics.Stopwatch]::GetTimestamp()*1.0e9/[Diagnostics.Stopwatch]::Frequency)
   Start-Sleep -Milliseconds 3900
   $obs=[ordered]@{step=$step;target_cell=$id;phase_start_qpc_ns=$phaseStart;phase_qpc_ns=[long]([Diagnostics.Stopwatch]::GetTimestamp()*1.0e9/[Diagnostics.Stopwatch]::Frequency);com_active_cell=[string]$excel.ActiveCell.Address($false,$false);uia_focus_pid=$null;uia_focus_cell=$null;uia_bounds=$null;source_role='RIGHT';excel_pid=$pidExcel}
   try{
     $focused=[Windows.Automation.AutomationElement]::FocusedElement
     if($focused -and $focused.Current.ProcessId -eq $pidExcel){
       $obs.uia_focus_pid=$focused.Current.ProcessId
       $obs.uia_focus_cell=[string]$focused.Current.Name
       $box=$focused.Current.BoundingRectangle
       if(-not $box.IsEmpty -and $box.Width -gt 0 -and $box.Height -gt 0){
         $obs.uia_bounds=@{left=$box.Left;top=$box.Top;right=$box.Right;bottom=$box.Bottom}
       }
     }
   }catch{}
   $result.observations+=,$obs
 }
 $valid=@($result.observations|Where-Object{$_.com_active_cell -eq $_.target_cell -and $_.uia_focus_cell -eq $_.target_cell -and $null -ne $_.uia_bounds})
 $within=@($valid|Where-Object{$_.uia_bounds.left -ge $right.Left -and $_.uia_bounds.right -le $right.Right -and $_.uia_bounds.top -ge $right.Top -and $_.uia_bounds.bottom -le $right.Bottom})
 $result['verified_cell_steps']=$valid.Count
 $result['inside_right_steps']=$within.Count
 $result.status=if($valid.Count -eq 6 -and $within.Count -eq 6){'PASS_SOURCE_CELL_IDENTITY'}else{'INCONCLUSIVE'}
}catch{
 $msg=$_.Exception.Message
 $result['error']=$msg
 $result.status=if($msg.StartsWith('BLOCKED:')){'BLOCKED'}else{'INCONCLUSIVE'}
}finally{
 try{if($book){$book.Close($false)}}catch{}
 try{if($excel){$excel.Quit()}}catch{}
 foreach($obj in @($previous,$sheet,$book,$excel)){if($obj){try{[void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($obj)}catch{}}}
 [GC]::Collect();[GC]::WaitForPendingFinalizers()
 [void][VisionExcelVisualNative]::SetCursorPos($pointer.X,$pointer.Y)
 $restore=Restore-VisionForeground -OriginalHwnd $original
 $result.focus_restored=[bool]$restore.restored
 $result['focus_restore_method']=$restore.status
 $result['finished_utc']=[DateTime]::UtcNow.ToString('o')
 [IO.File]::WriteAllText((Join-Path $run 'result.json'),($result|ConvertTo-Json -Depth 7),[Text.UTF8Encoding]::new($false))
}
$result|ConvertTo-Json -Depth 5
if($result.status -eq 'PASS_SOURCE_CELL_IDENTITY'){exit 0}else{exit 3}
