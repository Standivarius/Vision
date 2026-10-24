# PID-scoped Win32 native POC controller probe/actuator. Disposable test controller only.
param(
 [Parameter(Mandatory=$true)][int]$TargetPid,
 [Parameter(Mandatory=$true)][ValidateSet('Show LEFT in Detail','Show RIGHT in Detail','Follow active app','Stop Vision preview')][string]$Control,
 [switch]$Click
)
$ErrorActionPreference='Stop'
Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class VisionNativeControllerControl {
 public delegate bool CB(IntPtr hwnd,IntPtr state);
 [DllImport("user32.dll")]public static extern bool EnumWindows(CB cb,IntPtr state);
 [DllImport("user32.dll")]public static extern bool EnumChildWindows(IntPtr p,CB cb,IntPtr state);
 [DllImport("user32.dll")]public static extern uint GetWindowThreadProcessId(IntPtr h,out uint p);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]public static extern int GetWindowText(IntPtr h,StringBuilder text,int capacity);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]public static extern int GetClassName(IntPtr h,StringBuilder text,int capacity);
 [DllImport("user32.dll",SetLastError=true)]public static extern IntPtr SendMessageTimeout(IntPtr h,uint m,UIntPtr w,IntPtr l,uint flags,uint timeout,out UIntPtr result);
 public static long[] Find(uint pid,string fragment) {
  var list=new List<long>();
  EnumWindows((hwnd,s)=>{
   uint actual;GetWindowThreadProcessId(hwnd,out actual);
   if(actual!=pid)return true;
   var title=new StringBuilder(200);GetWindowText(hwnd,title,title.Capacity);
   if(!title.ToString().Contains("Doxa Shared Detail POC"))return true;
   EnumChildWindows(hwnd,(child,e)=>{
    var name=new StringBuilder(250);GetWindowText(child,name,name.Capacity);
    var cls=new StringBuilder(100);GetClassName(child,cls,cls.Capacity);
    if(cls.ToString().Contains("WindowsForms10.BUTTON")&&name.ToString().StartsWith(fragment))
       list.Add(child.ToInt64());
    return true;
   },IntPtr.Zero);
   return true;
  },IntPtr.Zero);
  return list.ToArray();
 }
 public static int Send(long handle,uint message){
  UIntPtr result;
  var ok=SendMessageTimeout(new IntPtr(handle),message,UIntPtr.Zero,IntPtr.Zero,2,1800,out result);
  if(ok==IntPtr.Zero)throw new InvalidOperationException("SendMessageTimeout failed "+Marshal.GetLastWin32Error());
  return unchecked((int)result.ToUInt64());
 }
}
"@
$proc=Get-Process -Id $TargetPid -ErrorAction Stop
$matches=@([VisionNativeControllerControl]::Find([uint32]$TargetPid,$Control))
if($matches.Count -ne 1){throw ('Expected one named POC button, found '+$matches.Count)}
$handle=[long]$matches[0]
$before=[VisionNativeControllerControl]::Send($handle,0xF0) # BM_GETCHECK
if($Click){[void][VisionNativeControllerControl]::Send($handle,0xF5)} # BM_CLICK
$after=[VisionNativeControllerControl]::Send($handle,0xF0)
[pscustomobject]@{pid=$proc.Id;control=$Control;clicked=[bool]$Click;before=$before;after=$after}|ConvertTo-Json -Compress

