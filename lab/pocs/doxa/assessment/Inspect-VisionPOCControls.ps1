# Read-only native Win32 GUI inspector; PID scoped.
param([Parameter(Mandatory=$true)][int]$ProcessId)
$ErrorActionPreference='Stop'
Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class VisionPOCNativeInspect {
 public delegate bool WndCallback(IntPtr hwnd,IntPtr param);
 [DllImport("user32.dll")] public static extern bool EnumWindows(WndCallback callback,IntPtr param);
 [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent,WndCallback callback,IntPtr param);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint pid);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr hwnd,StringBuilder text,int max);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr hwnd,StringBuilder text,int max);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hwnd);
 private static string Describe(IntPtr h) {
  var t=new StringBuilder(250);var c=new StringBuilder(120);
  GetWindowText(h,t,t.Capacity);GetClassName(h,c,c.Capacity);
  return h.ToInt64().ToString()+"|"+(IsWindowVisible(h)?"visible":"hidden")+"|"+c+"|"+t;
 }
 public static string[] Inspect(uint desiredPid){
  var result=new List<string>();
  EnumWindows((hwnd,s)=>{
   uint actual;GetWindowThreadProcessId(hwnd,out actual);
   if(actual!=desiredPid)return true;
   var title=new StringBuilder(200);GetWindowText(hwnd,title,title.Capacity);
   if(!title.ToString().Contains("Doxa Shared Detail POC"))return true;
   result.Add("PARENT|"+Describe(hwnd));
   EnumChildWindows(hwnd,(child,extra)=>{
    result.Add("CHILD|"+Describe(child));return true;
   },IntPtr.Zero);
   return true;
  },IntPtr.Zero);
  return result.ToArray();
 }
}
"@
$items=@([VisionPOCNativeInspect]::Inspect([uint32]$ProcessId))
[pscustomobject]@{target_process=$ProcessId;matches=$items.Count;windows=$items}|ConvertTo-Json -Depth 4

