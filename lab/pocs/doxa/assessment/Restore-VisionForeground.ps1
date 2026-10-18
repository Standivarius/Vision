# Reversible, explicit foreground restoration for unattended Doxa assessment.
# No password, elevation, keyboard injection, UI changes to the target window.
# Temporarily joins input queues only if Windows refuses direct restoration.
$ErrorActionPreference='Stop'
if(-not ('VisionForegroundRestorationNative' -as [type])){
 Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class VisionForegroundRestorationNative {
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h,out uint p);
 [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
 [DllImport("user32.dll",SetLastError=true)] public static extern bool AttachThreadInput(uint a,uint b,bool on);
 [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
}
"@
}
function Restore-VisionForeground {
 param([Parameter(Mandatory=$true)][IntPtr]$OriginalHwnd)
 $n=[VisionForegroundRestorationNative]
 if($OriginalHwnd -eq [IntPtr]::Zero -or -not [VisionForegroundRestorationNative]::IsWindow($OriginalHwnd)){
   return [pscustomobject]@{status='NOT_APPLICABLE';restored=$false;reason='original window no longer exists'}
 }
 if([VisionForegroundRestorationNative]::GetForegroundWindow() -eq $OriginalHwnd){
   return [pscustomobject]@{status='ALREADY_RESTORED';restored=$true}
 }
 [void][VisionForegroundRestorationNative]::SetForegroundWindow($OriginalHwnd)
 Start-Sleep -Milliseconds 300
 if([VisionForegroundRestorationNative]::GetForegroundWindow() -eq $OriginalHwnd){
   return [pscustomobject]@{status='RESTORED_DIRECT';restored=$true}
 }
 # No keyboard/Alt injection, no mouse clicks on the original user application.
 $current=[VisionForegroundRestorationNative]::GetForegroundWindow()
 $tmp=[uint32]0
 $foregroundTid=[VisionForegroundRestorationNative]::GetWindowThreadProcessId($current,[ref]$tmp)
 $targetTid=[VisionForegroundRestorationNative]::GetWindowThreadProcessId($OriginalHwnd,[ref]$tmp)
 $selfTid=[VisionForegroundRestorationNative]::GetCurrentThreadId()
 $joined=@()
 try {
   foreach($tid in @($foregroundTid,$targetTid|Select-Object -Unique)){
     if($tid -ne 0 -and $tid -ne $selfTid){
       if([VisionForegroundRestorationNative]::AttachThreadInput($selfTid,$tid,$true)){$joined+=,$tid}
     }
   }
   [void][VisionForegroundRestorationNative]::BringWindowToTop($OriginalHwnd)
   [void][VisionForegroundRestorationNative]::SetForegroundWindow($OriginalHwnd)
 }finally{
   foreach($tid in $joined){[void][VisionForegroundRestorationNative]::AttachThreadInput($selfTid,$tid,$false)}
 }
 Start-Sleep -Milliseconds 350
 $restored=([VisionForegroundRestorationNative]::GetForegroundWindow() -eq $OriginalHwnd)
 return [pscustomobject]@{
   status=if($restored){'RESTORED_ATTACHED'}else{'RESTORE_REJECTED'}
   restored=$restored
 }
}
