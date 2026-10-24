# A02 scoped Excel active-cell provenance only. Does not assert Doxa Centre visibility.
# Disposable workbook and unsaved test cells. Does not attach to existing Excel.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -TypeDefinition @"
using System;using System.Runtime.InteropServices;
public static class VisionExcelCellProbeNative {
 [StructLayout(LayoutKind.Sequential)]public struct RECT{public int Left,Top,Right,Bottom;}
 [StructLayout(LayoutKind.Sequential)]public struct POINT{public int X,Y;}
 [DllImport("user32.dll")]public static extern bool SetProcessDpiAwarenessContext(IntPtr context);
 [DllImport("user32.dll")]public static extern bool GetWindowRect(IntPtr h,out RECT rect);
 [DllImport("user32.dll")]public static extern uint GetWindowThreadProcessId(IntPtr h,out uint pid);
 [DllImport("user32.dll")]public static extern bool SetWindowPos(IntPtr h,IntPtr after,int x,int y,int width,int height,uint flags);
 [DllImport("user32.dll")]public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")]public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")]public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")]public static extern bool GetCursorPos(out POINT pt);
 [DllImport("user32.dll")]public static extern void mouse_event(uint flags,uint x,uint y,uint data,UIntPtr extra);
}
"@
[void][VisionExcelCellProbeNative]::SetProcessDpiAwarenessContext([IntPtr](-4))
. (Join-Path $PSScriptRoot 'Restore-VisionForeground.ps1')
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$stamp=[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')
$run=Join-Path $root ('artifacts\vision-poc-a-graphics-20261017\cell-identity-'+$stamp+'-'+[Guid]::NewGuid().ToString('N').Substring(0,6))
[void][IO.Directory]::CreateDirectory($run)
$original=[VisionExcelCellProbeNative]::GetForegroundWindow()
$originalPointer=New-Object VisionExcelCellProbeNative+POINT
[void][VisionExcelCellProbeNative]::GetCursorPos([ref]$originalPointer)
$result=[ordered]@{scenario='A02-Excel-verified-cell-identity-without-forced-scroll';status='INCONCLUSIVE';source='RIGHT';observations=@();viewport_verified=$false;documents_touched=$false;workbook_saved=$false;focus_restored=$false}
$excel=$null;$book=$null;$sheet=$null;$pidExcel=[uint32]0
try{
 if(@(Get-Process EXCEL -ErrorAction SilentlyContinue).Count){throw 'BLOCKED: Excel is running; refuse to touch existing workbooks'}
 if(@(Get-Process visual_app -ErrorAction SilentlyContinue).Count){throw 'BLOCKED: Vision preview is running'}
 & python.exe 'lab\pocs\doxa\assessment\win_observer.py' --preflight | Out-Null
 if($LASTEXITCODE -ne 0){throw 'BLOCKED: four-screen unlocked physical console required'}
 $screens=@([Windows.Forms.Screen]::AllScreens|Where-Object{-not $_.Primary}|Sort-Object {$_.Bounds.Left})
 if($screens.Count -ne 3){throw 'BLOCKED: three external monitors not present'}
 $right=$screens[2].Bounds
 $result['physical_right_bounds']=@{left=$right.Left;top=$right.Top;right=$right.Right;bottom=$right.Bottom}
 $excel=New-Object -ComObject Excel.Application
 $excel.Visible=$true
 $excel.DisplayAlerts=$false
 $book=$excel.Workbooks.Add()
 $sheet=$book.Worksheets.Item(1)
 foreach($row in 1..37){
  foreach($column in 1..9){
   $sheet.Cells.Item($row,$column).Value2=('VISION TEST '+$row+' '+$column)
  }
 }
 $hwnd=[IntPtr]::Zero
 for($attempt=0;$attempt -lt 48;$attempt++){
  $numeric=0
  try{$numeric=[long]$excel.Hwnd}catch{}
  if($numeric -ne 0){$hwnd=[IntPtr]$numeric;break}
  $candidates=@(Get-Process EXCEL -ErrorAction SilentlyContinue|Where-Object{$_.MainWindowHandle -ne [IntPtr]::Zero})
  if($candidates.Count -eq 1){$hwnd=$candidates[0].MainWindowHandle;break}
  Start-Sleep -Milliseconds 250
 }
 $thread=[VisionExcelCellProbeNative]::GetWindowThreadProcessId($hwnd,[ref]$pidExcel)
 if($thread -eq 0 -or $pidExcel -eq 0){throw 'Excel top-level window did not become ready'}
 $result['spawned_excel_pid']=$pidExcel
 [void][VisionExcelCellProbeNative]::SetWindowPos($hwnd,[IntPtr]::Zero,$right.Left+40,$right.Top+70,[Math]::Min(1740,$right.Width-80),[Math]::Min(900,$right.Height-130),0x0040)
 $excel.WindowState=-4143 # xlNormal
 $book.Activate()
 [void][VisionExcelCellProbeNative]::SetForegroundWindow($hwnd)
 Start-Sleep -Milliseconds 300
 $winrect=New-Object VisionExcelCellProbeNative+RECT
 [void][VisionExcelCellProbeNative]::GetWindowRect($hwnd,[ref]$winrect)
 $result['excel_window_bounds']=@{left=$winrect.Left;top=$winrect.Top;right=$winrect.Right;bottom=$winrect.Bottom}
 $fgPid=[uint32]0
 [void][VisionExcelCellProbeNative]::GetWindowThreadProcessId([VisionExcelCellProbeNative]::GetForegroundWindow(),[ref]$fgPid)
 if($fgPid -ne $pidExcel){
  [void][VisionExcelCellProbeNative]::SetCursorPos($winrect.Left+260,$winrect.Top+12)
  Start-Sleep -Milliseconds 160
  [VisionExcelCellProbeNative]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
  Start-Sleep -Milliseconds 70
  [VisionExcelCellProbeNative]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
  Start-Sleep -Milliseconds 300
  [void][VisionExcelCellProbeNative]::GetWindowThreadProcessId([VisionExcelCellProbeNative]::GetForegroundWindow(),[ref]$fgPid)
 }
 $result['excel_owned_foreground_before_sampling']=($fgPid -eq $pidExcel)
 $cells=@('A1','H1','H26','D12','A35','I33','B5','G23','A1')
 foreach($id in $cells){
  $target=$sheet.Range($id)
  $excel.Goto($target,$false) # select without forcing target to visible-range top-left
  Start-Sleep -Milliseconds 650
  $obs=[ordered]@{target=$id;excel_pid=$pidExcel;com_active_cell=[string]$excel.ActiveCell.Address($false,$false);uia_focus_pid=$null;uia_control_type=$null;uia_name_length=$null;uia_identity_matches=$false;uia_bounds=$null}
  $obs['com_cell_rect_points']=@{
   left=[double]$target.Left;top=[double]$target.Top;
   width=[double]$target.Width;height=[double]$target.Height
  }
  try{
    $w=$excel.ActiveWindow
    $p0x=[double]$w.PointsToScreenPixelsX([double]$target.Left)
    $p0y=[double]$w.PointsToScreenPixelsY([double]$target.Top)
    $p1x=[double]$w.PointsToScreenPixelsX([double]($target.Left+$target.Width))
    $p1y=[double]$w.PointsToScreenPixelsY([double]($target.Top+$target.Height))
    $obs['excel_screen_geometry'] = @{left=$p0x;top=$p0y;right=$p1x;bottom=$p1y}
    $obs['excel_visible_range']=[string]$w.VisibleRange.Address($false,$false)
  }catch{
    $obs['excel_geometry_error']=$_.Exception.Message
  }

  try{
   $e=[Windows.Automation.AutomationElement]::FocusedElement
   if($e){
    $obs.uia_focus_pid=$e.Current.ProcessId
    $obs.uia_control_type=[string]$e.Current.ControlType.ProgrammaticName
    # Generated cell address only; do not read or store any spreadsheet content.
    $obs.uia_name_length=([string]$e.Current.Name).Length
    $obs.uia_identity_matches=(([string]$e.Current.Name).Trim() -eq $id)
    if($e.Current.ProcessId -eq $pidExcel){
     $r=$e.Current.BoundingRectangle
     if(-not $r.IsEmpty -and $r.Width -gt 0 -and $r.Height -gt 0){
      $obs.uia_bounds=@{left=$r.Left;top=$r.Top;right=$r.Right;bottom=$r.Bottom}
     }
    }
   }
  }catch{}
  $result.observations+=,$obs
 }
 $valid=@($result.observations|Where-Object{$null -ne $_.uia_bounds})
 $within=@($valid|Where-Object{$_.uia_bounds.left -ge $right.Left -and $_.uia_bounds.right -le $right.Right -and $_.uia_bounds.top -ge $right.Top -and $_.uia_bounds.bottom -le $right.Bottom})
 $distinct=@($valid|ForEach-Object{'{0}:{1}:{2}:{3}' -f [math]::Round($_.uia_bounds.left),[math]::Round($_.uia_bounds.top),[math]::Round($_.uia_bounds.right),[math]::Round($_.uia_bounds.bottom)}|Select-Object -Unique)
 $result['uia_cell_rectangles']=$valid.Count
 $result['rectangles_inside_right']=$within.Count
 $result['distinct_rectangles']=$distinct.Count
 $identities=@($result.observations|Where-Object{$_.uia_identity_matches -and $_.com_active_cell -eq $_.target})
 $result['matched_cell_addresses']=$identities.Count
 $result.status=if($identities.Count -eq $result.observations.Count -and $valid.Count -ge 3 -and $within.Count -eq $valid.Count -and $distinct.Count -ge 2 -and $result.excel_owned_foreground_before_sampling){'PASS_SOURCE_CELL_IDENTITY'}else{'INCONCLUSIVE'}
}catch{
 $msg=$_.Exception.Message
 $result['error']=$msg
 $result.status=if($msg.StartsWith('BLOCKED:')){'BLOCKED'}else{'INCONCLUSIVE'}
}finally{
 try{if($book){$book.Close($false)}}catch{}
 try{if($excel){$excel.Quit()}}catch{}
 foreach($obj in @($sheet,$book,$excel)){if($obj){try{[void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($obj)}catch{}}}
 [GC]::Collect();[GC]::WaitForPendingFinalizers()
 [void][VisionExcelCellProbeNative]::SetCursorPos($originalPointer.X,$originalPointer.Y)
 $restore=Restore-VisionForeground -OriginalHwnd $original
 $result.focus_restored=[bool]$restore.restored
 $result['focus_restore_method']=$restore.status
 $result['finished_utc']=[DateTime]::UtcNow.ToString('o')
 [IO.File]::WriteAllText((Join-Path $run 'result.json'),($result|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
}
$result|ConvertTo-Json -Depth 8
if($result.status -eq 'PASS_SOURCE_CELL_IDENTITY'){exit 0}else{exit 3}
