# Independent Win32/UIA caret provenance from an unsaved disposable Word doc.
# See A02-caret-truth-charter.md. Not Vision viewport acceptance.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -TypeDefinition @"
using System;using System.Runtime.InteropServices;
public static class VisionWordCaretProbeNative {
 [StructLayout(LayoutKind.Sequential)]public struct RECT{public int Left,Top,Right,Bottom;}
 [StructLayout(LayoutKind.Sequential)]public struct POINT{public int X,Y;}
 [StructLayout(LayoutKind.Sequential)]public struct GUITHREADINFO{
  public uint cbSize;public uint flags;public IntPtr hwndActive,hwndFocus,hwndCapture,hwndMenuOwner,hwndMoveSize,hwndCaret;public RECT rcCaret;
 }
 [DllImport("user32.dll")]public static extern uint GetWindowThreadProcessId(IntPtr h,out uint p);
 [DllImport("user32.dll")]public static extern bool GetGUIThreadInfo(uint thread,ref GUITHREADINFO info);
 [DllImport("user32.dll")]public static extern bool ClientToScreen(IntPtr h,ref POINT point);
 [DllImport("user32.dll")]public static extern bool SetWindowPos(IntPtr h,IntPtr after,int x,int y,int w,int ht,uint flags);
 [DllImport("user32.dll")]public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")]public static extern bool SetProcessDpiAwarenessContext(IntPtr context);
 [DllImport("user32.dll")]public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")]public static extern bool GetCursorPos(out POINT p);
 [DllImport("user32.dll")]public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")]public static extern void mouse_event(uint flags,uint x,uint y,uint data,UIntPtr extra);
 [DllImport("user32.dll")]public static extern bool GetWindowRect(IntPtr h,out RECT rect);
}
"@
[void][VisionWordCaretProbeNative]::SetProcessDpiAwarenessContext([IntPtr](-4))
. (Join-Path $PSScriptRoot 'Restore-VisionForeground.ps1')
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$now=[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')
$target=Join-Path $root ('artifacts\vision-poc-a-graphics-20261017\caret-truth-'+$now+'-'+[Guid]::NewGuid().ToString('N').Substring(0,6))
[void][IO.Directory]::CreateDirectory($target)
$result=[ordered]@{scenario='A02-Word-semantic-caret-source-provenance';status='INCONCLUSIVE';start_utc=[DateTime]::UtcNow.ToString('o');independent_source_provenance_only=$true;physical_viewport_verified=$false;observations=@();focus_restored=$false;documents_touched=$false;document_saved=$false}
$original=[VisionWordCaretProbeNative]::GetForegroundWindow()
$originalPointer=New-Object VisionWordCaretProbeNative+POINT
[void][VisionWordCaretProbeNative]::GetCursorPos([ref]$originalPointer)
$word=$null;$doc=$null;$wordPid=0
try {
 $preexisting=@(Get-Process WINWORD -ErrorAction SilentlyContinue)
 if($preexisting.Count){throw 'BLOCKED: Word is already running. Refusing to attach to any existing document.'}
 if(@(Get-Process visual_app -ErrorAction SilentlyContinue).Count){throw 'BLOCKED: Vision preview currently running.'}
 $p=@(Get-Process powershell -ErrorAction SilentlyContinue)
 $preflight=@(& python.exe 'lab\pocs\doxa\assessment\win_observer.py' --preflight 2>&1)
 if($LASTEXITCODE -ne 0){throw 'BLOCKED: physical four-screen console preflight failed'}
 $screens=@([Windows.Forms.Screen]::AllScreens|Where-Object{-not $_.Primary}|Sort-Object{$_.Bounds.Left})
 if($screens.Count -ne 3){throw 'BLOCKED: exactly three nonprimary physical displays needed'}
 $left=$screens[0].Bounds
 $result['physical_left_bounds']=@{left=$left.Left;top=$left.Top;right=$left.Right;bottom=$left.Bottom}
 $word=New-Object -ComObject Word.Application
 $word.Visible=$true
 $word.DisplayAlerts=0
 $doc=$word.Documents.Add()
 $words=@()
 foreach($line in (1..32)){
   $words+=('VISION INTERNAL CARET FIXTURE LINE '+$line+' : ALPHA BETA GAMMA DELTA EPSILON KAPPA')
 }
 $doc.Content.Text=($words -join [Environment]::NewLine)
 $doc.Content.Font.Name='Calibri';$doc.Content.Font.Size=14
 $hwnd=[IntPtr]::Zero
 # Office can expose its COM application before its top-level GUI HWND exists.
 for($attempt=0;$attempt -lt 48;$attempt++){
   $numeric=0
   try{$numeric=[long]$word.Hwnd}catch{}
   if($numeric -ne 0){$hwnd=[IntPtr]$numeric;break}
   $candidates=@(Get-Process WINWORD -ErrorAction SilentlyContinue|Where-Object{$_.MainWindowHandle -ne [IntPtr]::Zero})
   if($candidates.Count -eq 1){$hwnd=$candidates[0].MainWindowHandle;break}
   Start-Sleep -Milliseconds 250
 }
 $pidValue=[uint32]0
 $wordTid=[VisionWordCaretProbeNative]::GetWindowThreadProcessId($hwnd,[ref]$pidValue)
 $wordPid=$pidValue
 $result['spawned_word_pid']=$wordPid
 if($wordTid -eq 0 -or $wordPid -eq 0){throw 'Cannot identify spawned Word window PID'}
 [void][VisionWordCaretProbeNative]::SetWindowPos($hwnd,[IntPtr]::Zero,$left.Left+50,$left.Top+80,[Math]::Min(1700,$left.Width-90),[Math]::Min(890,$left.Height-140),0x0040)
 $word.Activate()
 [void][VisionWordCaretProbeNative]::SetForegroundWindow($hwnd)
 Start-Sleep -Milliseconds 220
 $actual=New-Object VisionWordCaretProbeNative+RECT
 [void][VisionWordCaretProbeNative]::GetWindowRect($hwnd,[ref]$actual)
 $result['word_window_bounds']=@{left=$actual.Left;top=$actual.Top;right=$actual.Right;bottom=$actual.Bottom}
 $foregroundPid=[uint32]0
 [void][VisionWordCaretProbeNative]::GetWindowThreadProcessId([VisionWordCaretProbeNative]::GetForegroundWindow(),[ref]$foregroundPid)
 if($foregroundPid -ne $wordPid){
   # Only click the known title bar of our own unsaved Word test window.
   [void][VisionWordCaretProbeNative]::SetCursorPos($actual.Left+260,$actual.Top+13)
   Start-Sleep -Milliseconds 150
   [VisionWordCaretProbeNative]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
   Start-Sleep -Milliseconds 80
   [VisionWordCaretProbeNative]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
   Start-Sleep -Milliseconds 300
   [void][VisionWordCaretProbeNative]::GetWindowThreadProcessId([VisionWordCaretProbeNative]::GetForegroundWindow(),[ref]$foregroundPid)
 }
 $result['word_owned_foreground_before_sampling']=($foregroundPid -eq $wordPid)
 $positions=@(0,120,420,900,1650,2200,450,1680,80)
 foreach($index in (0..($positions.Count-1))){
   $position=[Math]::Min([int]$positions[$index],[Math]::Max(0,$doc.Content.End-2))
   $word.Selection.SetRange($position,$position)
   $word.Selection.Collapse(1)
   try{$word.ActiveWindow.ScrollIntoView($word.Selection.Range,$true)}catch{}
   Start-Sleep -Milliseconds 650
   $o=[ordered]@{step=$index;requested_caret_offset=$position;target_pid=$wordPid;source_role='LEFT';uia_caret=$null;uia_selection=$null;win32_caret=$null;uia_focus_pid=$null;win32_focus_pid=$null}
   try{
     $focused=[Windows.Automation.AutomationElement]::FocusedElement
     if($focused){
       $o.uia_focus_pid=$focused.Current.ProcessId
       if($focused.Current.ProcessId -eq $wordPid){
         try{
           $pt=[Windows.Automation.TextPattern2]$focused.GetCurrentPattern([Windows.Automation.TextPattern2]::Pattern)
           $active=$false
           $range=$pt.GetCaretRange([ref]$active)
           $rects=@($range.GetBoundingRectangles())
           if($active -and $rects.Count){
             $r=$rects[0]
             $o.uia_caret=@{left=$r.Left;top=$r.Top;right=$r.Right;bottom=$r.Bottom}
           }
         }catch{}
         try{
           $tp=[Windows.Automation.TextPattern]$focused.GetCurrentPattern([Windows.Automation.TextPattern]::Pattern)
           $selections=@($tp.GetSelection())
           if($selections.Count){
             $rects=@($selections[0].GetBoundingRectangles())
             if($rects.Count){
               $r=$rects[0];$o.uia_selection=@{left=$r.Left;top=$r.Top;right=$r.Right;bottom=$r.Bottom}
             }
           }
         }catch{}
       }
     }
   }catch{}
   $info=New-Object VisionWordCaretProbeNative+GUITHREADINFO
   $info.cbSize=[Runtime.InteropServices.Marshal]::SizeOf([type][VisionWordCaretProbeNative+GUITHREADINFO])
   if([VisionWordCaretProbeNative]::GetGUIThreadInfo($wordTid,[ref]$info)){
     $proc=[uint32]0
     [void][VisionWordCaretProbeNative]::GetWindowThreadProcessId($info.hwndFocus,[ref]$proc)
     $o.win32_focus_pid=$proc
     if($info.hwndCaret -ne [IntPtr]::Zero){
       $caretProcess=[uint32]0
       [void][VisionWordCaretProbeNative]::GetWindowThreadProcessId($info.hwndCaret,[ref]$caretProcess)
       if($caretProcess -eq $wordPid){
         $pt=New-Object VisionWordCaretProbeNative+POINT
         $pt.X=$info.rcCaret.Left;$pt.Y=$info.rcCaret.Top
         if([VisionWordCaretProbeNative]::ClientToScreen($info.hwndCaret,[ref]$pt)){
           $o.win32_caret=@{left=$pt.X;top=$pt.Y;right=$pt.X+($info.rcCaret.Right-$info.rcCaret.Left);bottom=$pt.Y+($info.rcCaret.Bottom-$info.rcCaret.Top)}
         }
       }
     }
   }
   $result.observations+=,$o
 }
 $candidate=@()
 foreach($r in $result.observations){
   if($r.uia_caret){$candidate+=,$r.uia_caret}
   elseif($r.uia_selection){$candidate+=,$r.uia_selection}
   elseif($r.win32_caret){$candidate+=,$r.win32_caret}
 }
 $inLeft=@($candidate|Where-Object{$_.left -ge $left.Left -and $_.right -le $left.Right -and $_.top -ge $left.Top -and $_.bottom -le $left.Bottom})
 $distinct=@($candidate|ForEach-Object{'{0}:{1}' -f [math]::Round($_.left),[math]::Round($_.top)}|Select-Object -Unique)
 $result['provenanced_caret_rectangles']=$candidate.Count
 $result['caret_rectangles_inside_left']=$inLeft.Count
 $result['distinct_screen_positions']=$distinct.Count
 $result.status=if($candidate.Count -ge 3 -and $inLeft.Count -eq $candidate.Count -and $distinct.Count -ge 2){'PASS_SOURCE_CARET'}else{'INCONCLUSIVE'}
}
catch{
 $msg=$_.Exception.Message
 $result['error']=$msg
 $result.status=if($msg.StartsWith('BLOCKED:')){'BLOCKED'}else{'INCONCLUSIVE'}
}
finally{
 try{if($doc){$doc.Close(0)}}catch{}
 try{if($word){$word.Quit()}}catch{}
 foreach($obj in @($doc,$word)){if($obj){try{[void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($obj)}catch{}}}
 [GC]::Collect();[GC]::WaitForPendingFinalizers()
 [void][VisionWordCaretProbeNative]::SetCursorPos($originalPointer.X,$originalPointer.Y)
 $restore=Restore-VisionForeground -OriginalHwnd $original
 $result.focus_restored=[bool]$restore.restored
 $result['focus_restore_method']=$restore.status
 $result['finished_utc']=[DateTime]::UtcNow.ToString('o')
 $output=Join-Path $target 'result.json'
 [IO.File]::WriteAllText($output,($result|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
}
$result|ConvertTo-Json -Depth 8
if($result.status -eq 'PASS_SOURCE_CARET'){exit 0}else{exit 3}
