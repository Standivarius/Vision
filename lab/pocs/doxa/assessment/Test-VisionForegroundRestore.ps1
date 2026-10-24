# Reversible experiment: restore pre-test user foreground after a disposable
# WinForms fixture owns the foreground, without Alt/keyboard injection or UAC.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class VisionFocusRestoreNative20261018 {
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h,out uint p);
 [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
 [DllImport("user32.dll",SetLastError=true)] public static extern bool AttachThreadInput(uint from,uint to,bool attach);
 [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
}
"@
function Try-Restore([IntPtr]$wanted){
 if($wanted -eq [IntPtr]::Zero -or -not [VisionFocusRestoreNative20261018]::IsWindow($wanted)){return 'NOT_APPLICABLE'}
 if([VisionFocusRestoreNative20261018]::GetForegroundWindow() -eq $wanted){return 'ALREADY_RESTORED'}
 [void][VisionFocusRestoreNative20261018]::SetForegroundWindow($wanted)
 Start-Sleep -Milliseconds 300
 if([VisionFocusRestoreNative20261018]::GetForegroundWindow() -eq $wanted){return 'RESTORED_DIRECT'}
 $fg=[VisionFocusRestoreNative20261018]::GetForegroundWindow()
 $tmp=[uint32]0
 $foregroundTid=[VisionFocusRestoreNative20261018]::GetWindowThreadProcessId($fg,[ref]$tmp)
 $targetTid=[VisionFocusRestoreNative20261018]::GetWindowThreadProcessId($wanted,[ref]$tmp)
 $ownTid=[VisionFocusRestoreNative20261018]::GetCurrentThreadId()
 $attached=@()
 try{
  foreach($tid in @($foregroundTid,$targetTid|Select-Object -Unique)){
    if($tid -ne 0 -and $tid -ne $ownTid){
     if([VisionFocusRestoreNative20261018]::AttachThreadInput($ownTid,$tid,$true)){
       $attached+=,$tid
     }
    }
  }
  [void][VisionFocusRestoreNative20261018]::BringWindowToTop($wanted)
  [void][VisionFocusRestoreNative20261018]::SetForegroundWindow($wanted)
 }finally{
  foreach($tid in $attached){[void][VisionFocusRestoreNative20261018]::AttachThreadInput($ownTid,$tid,$false)}
 }
 Start-Sleep -Milliseconds 350
 if([VisionFocusRestoreNative20261018]::GetForegroundWindow() -eq $wanted){return 'RESTORED_ATTACHED'}
 return 'RESTORE_REJECTED'
}
$original=[VisionFocusRestoreNative20261018]::GetForegroundWindow()
if($original -eq [IntPtr]::Zero){throw 'No valid original foreground'}
$priorPid=[uint32]0
[void][VisionFocusRestoreNative20261018]::GetWindowThreadProcessId($original,[ref]$priorPid)
$form=$null
$result=[ordered]@{original_hwnd=$original.ToInt64();original_pid=$priorPid;fixture_foreground=$false;restore_method='NOT_ATTEMPTED';restored_final=$false}
try{
 $form=New-Object Windows.Forms.Form
 $form.Text='Vision disposable foreground restoration qualification'
 $form.FormBorderStyle='FixedDialog'
 $form.ShowInTaskbar=$false
 $form.TopMost=$false
 $form.Size=New-Object Drawing.Size 520,170
 $form.StartPosition='Manual'
 $form.Location=New-Object Drawing.Point 280,250
 $form.Show()
 [void]$form.Activate()
 for($i=0;$i -lt 12;$i++){
  [Windows.Forms.Application]::DoEvents()
  Start-Sleep -Milliseconds 100
  if([VisionFocusRestoreNative20261018]::GetForegroundWindow() -eq $form.Handle){break}
 }
 $result.fixture_foreground=([VisionFocusRestoreNative20261018]::GetForegroundWindow() -eq $form.Handle)
 if(-not $result.fixture_foreground){throw 'Fixture cannot obtain foreground, invalid test'}
 $result.restore_method=Try-Restore $original
}finally{
 if($form){$form.Close();$form.Dispose()}
 [void](Try-Restore $original)
 $result.restored_final=([VisionFocusRestoreNative20261018]::GetForegroundWindow() -eq $original)
}
$result|ConvertTo-Json -Depth 3
if(-not $result.restored_final){exit 2}
