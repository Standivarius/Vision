# Short real-console acceptance. Two disposable GUI windows, no personal documents.
# Verifies optional focus-follow without mouse activity or global focus hooks.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class VisionAutoFocusTestNative {
 public static long[] FindControls(uint pid,string desired,bool rootOnly) {
   var items=new System.Collections.Generic.List<long>();
   EnumWindows((h,data)=>{
     uint actual;GetWindowThreadProcessId(h,out actual);
     if(actual!=pid)return true;
     var title=new System.Text.StringBuilder(256);
     GetWindowText(h,title,256);
     if(!title.ToString().Contains("Doxa Shared Detail POC"))return true;
     if(rootOnly){items.Add(h.ToInt64());return true;}
     EnumChildWindows(h,(child,other)=>{
       var name=new System.Text.StringBuilder(256);var cls=new System.Text.StringBuilder(128);
       GetWindowText(child,name,256);GetClassName(child,cls,128);
       if(cls.ToString().Contains("WindowsForms10.BUTTON")&&name.ToString().Contains(desired)) items.Add(child.ToInt64());
       return true;
     },IntPtr.Zero);
     return true;
   },IntPtr.Zero);
   return items.ToArray();
 }
 public delegate bool EnumProc(IntPtr hwnd,IntPtr extra);
 [DllImport("user32.dll")]public static extern bool EnumWindows(EnumProc cb,IntPtr state);
 [DllImport("user32.dll")]public static extern bool EnumChildWindows(IntPtr parent,EnumProc cb,IntPtr state);
 [DllImport("user32.dll")]public static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint pid);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]public static extern int GetWindowText(IntPtr hwnd,System.Text.StringBuilder b,int n);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]public static extern int GetClassName(IntPtr hwnd,System.Text.StringBuilder b,int n);

 [DllImport("user32.dll")]public static extern bool SetForegroundWindow(IntPtr hwnd);
 [DllImport("user32.dll")]public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")]public static extern bool GetCursorPos(out POINT p);
 [DllImport("user32.dll")]public static extern void mouse_event(uint f,uint dx,uint dy,uint data,UIntPtr extra);
 [StructLayout(LayoutKind.Sequential)]public struct POINT{public int X,Y;}
 [DllImport("user32.dll")]public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")]public static extern bool SetProcessDpiAwarenessContext(IntPtr value);
 [DllImport("user32.dll",SetLastError=true)]public static extern IntPtr SendMessageTimeout(IntPtr hwnd,uint msg,UIntPtr w,IntPtr l,uint flags,uint timeoutMs,out UIntPtr output);
 [DllImport("user32.dll")]public static extern bool PostMessage(IntPtr hwnd,uint msg,UIntPtr w,IntPtr l);
}
"@
[void][VisionAutoFocusTestNative]::SetProcessDpiAwarenessContext([IntPtr](-4))
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$originalForeground=[VisionAutoFocusTestNative]::GetForegroundWindow()
$originalPointer=New-Object VisionAutoFocusTestNative+POINT
[void][VisionAutoFocusTestNative]::GetCursorPos([ref]$originalPointer)
if(@(Get-Process visual_app -ErrorAction SilentlyContinue).Count){throw 'Vision already running. Cannot interfere with existing instance'}
$panels=@([Windows.Forms.Screen]::AllScreens|Where-Object{-not $_.Primary}|Sort-Object {$_.Bounds.Left})
if($panels.Count -ne 3){throw 'Expected 3 Doxa panels'}
# A lock screen is a real OS security boundary. Do not try to drive input
# through it, and do not mislabel lack of input as a magnifier failure.
. (Join-Path $PSScriptRoot '..\VisionFocusWorkspaceProbe.ps1')
$probeX=[int]($panels[2].Bounds.Left+$panels[2].Bounds.Width/2)
$probeY=[int]($panels[2].Bounds.Top+$panels[2].Bounds.Height/2)
if(Test-VisionLockScreenOccludesPoint $probeX $probeY){
 $blocked=[ordered]@{
   status='BLOCKED_LOCK_SCREEN'
   reason='Windows LockScreenInputOcclusionFrame occludes the Doxa input desktop'
   test='Opt-in source follows foreground application'
   actual_foreground_activity_tested=$false
   software_or_driver_changed=$false
   user_action_needed='Unlock Dell before attended focus-switch acceptance'
 }
 $out=Join-Path $root 'artifacts\vision-poc-a-graphics-20261017\poc-a-focus-follow-lock-preflight-v0.1.json'
 if(-not(Test-Path $out)){
  [IO.File]::WriteAllText($out,($blocked|ConvertTo-Json -Depth 4),[Text.UTF8Encoding]::new($false))
 }
 $blocked|ConvertTo-Json -Compress -Depth 4
 exit 3
}
$controllerScript=Join-Path $PSScriptRoot '..\Start-VisionSharedDetailPOC.ps1'
$controller=$null;$fixtures=@()
$results=[ordered]@{test='Manual LEFT / RIGHT / LEFT switching via Win32 native controls';start_utc=[DateTime]::UtcNow.ToString('o');status='INCOMPLETE';follow_default_off=$false;checkbox_enabled=$false;right_auto_requested=$false;left_auto_requested=$false;renderer_rebinds=0;single_preview_process=$false;graceful_shutdown=$false;display_or_driver_changes=$false;documents_touched=$false;focus_restored=$false}
function Pump([int]$ms=120){Start-Sleep -Milliseconds $ms;[Windows.Forms.Application]::DoEvents()}
function Get-Controller{
 if(-not $script:controller){return $null}
 if(-not(Get-Process -Id $script:controller.Id -ErrorAction SilentlyContinue)){return $null}
 $handles=@([VisionAutoFocusTestNative]::FindControls([uint32]$script:controller.Id,'',$true))
 if($handles.Count -ne 1){return $null}
 return [pscustomobject]@{Current=[pscustomobject]@{NativeWindowHandle=[IntPtr][long]$handles[0]}}
}
function Find-Control([string]$pattern){
 $w=Get-Controller
 if(-not $w){throw 'POC controller window absent'}
 $matches=@([VisionAutoFocusTestNative]::FindControls([uint32]$script:controller.Id,$pattern,$false))
 if($matches.Count -ne 1){throw ('POC native child ambiguous: '+$pattern+' count='+$matches.Count)}
 return [pscustomobject]@{Current=[pscustomobject]@{NativeWindowHandle=[IntPtr][long]$matches[0]}}
}
function Click-Button([string]$name){
 $b=Find-Control $name
 $answer=[UIntPtr]::Zero
 $ok=[VisionAutoFocusTestNative]::SendMessageTimeout([IntPtr]$b.Current.NativeWindowHandle,0xF5,[UIntPtr]::Zero,[IntPtr]::Zero,2,5000,[ref]$answer)
 if($ok -eq [IntPtr]::Zero){throw ('Native click refused '+$name)}
}
function Check-State([string]$name){
 $w=Find-Control $name
 $answer=[UIntPtr]::Zero
 $ok=[VisionAutoFocusTestNative]::SendMessageTimeout([IntPtr]$w.Current.NativeWindowHandle,0xF0,[UIntPtr]::Zero,[IntPtr]::Zero,2,1500,[ref]$answer)
 if($ok -eq [IntPtr]::Zero){throw ('Native check refused '+$name)}
 return [int]$answer.ToUInt64()
}
function Make-Fixture([string]$name,[int]$left,[int]$top){
 $window=New-Object Windows.Forms.Form
 $window.Text='Vision POC focus fixture '+$name
 $window.FormBorderStyle='FixedSingle'
 $window.StartPosition='Manual'
 $window.Location=New-Object Drawing.Point($left,$top)
 $window.Size=New-Object Drawing.Size(850,610)
 $window.ShowInTaskbar=$false
 $window.TopMost=$false
 $lbl=New-Object Windows.Forms.Label
 $lbl.Text='Temporary '+$name+' focus test. No files opened.'
 $lbl.SetBounds(40,55,700,120)
 $window.Controls.Add($lbl)
 $window.Show()
 [Windows.Forms.Application]::DoEvents()
 return $window
}
function Click-FixtureTitle($window){
 # Only bring OUR OWN disposable WinForms fixture to the front.
 # Windows can otherwise deliver the pointer click to an overlapping
 # unrelated owner window, falsely blaming Vision for an OS focus miss.
 $window.BringToFront()
 [void]$window.Activate()
 Pump 220
 $px=[int]($window.Left+330)
 $py=[int]($window.Top+15)
 [void][VisionAutoFocusTestNative]::SetCursorPos($px,$py)
 Pump 170
 [VisionAutoFocusTestNative]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
 Pump 65
 [VisionAutoFocusTestNative]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
 Pump 300
 return ([VisionAutoFocusTestNative]::GetForegroundWindow() -eq $window.Handle)
}
function Active-Run-Directory{
 $folder=Join-Path $root 'artifacts\vision-poc-a-graphics-20261017\operator-poc'
 return Get-ChildItem $folder -Directory|Sort-Object LastWriteTime -Descending|Select-Object -First 1
}
function Wait-Event([string]$name,[int]$seconds=7){
 $start=[DateTime]::UtcNow
 while(([DateTime]::UtcNow-$start).TotalSeconds -lt $seconds){
  Pump 180
  $latest=Active-Run-Directory
  if($latest){
   $p=Join-Path $latest.FullName 'controller-events.log'
   if((Test-Path $p) -and (Select-String -Path $p -SimpleMatch $name -Quiet)){return $true}
  }
 }
 return $false
}
try{
 # Create disposable windows first, so the controller starts after them.
 $fixtures+=Make-Fixture 'LEFT' ($panels[0].Bounds.Left+150) ($panels[0].Bounds.Top+130)
 $fixtures+=Make-Fixture 'RIGHT' ($panels[2].Bounds.Left+150) ($panels[2].Bounds.Top+130)
 $controller=Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$controllerScript+'"')) -WorkingDirectory $root -PassThru
 $ready=$false
 for($i=0;$i -lt 42;$i++){Pump 170;if(Get-Controller){$ready=$true;break}}
 if(-not $ready){throw 'POC controller did not start'}
 $results.follow_default_off=((Check-State 'Follow active app') -eq 0)
 if(-not $results.follow_default_off){throw 'Auto-follow must be off by default'}
 Click-Button 'Show LEFT in Detail'
 Pump 2200
 if(@(Get-Process visual_app -ErrorAction SilentlyContinue).Count -ne 1){throw 'Expected one Vision preview'}
 $previewPid=@(Get-Process visual_app)[0].Id
 Click-Button 'Show RIGHT in Detail'
 if(-not (Wait-Event 'source_message_sent=RIGHT' 9)){throw 'No RIGHT source send'}
 Pump 1100
 Click-Button 'Show LEFT in Detail'
 Pump 1500
 $latest=Active-Run-Directory
 $controllerLog=Join-Path $latest.FullName 'controller-events.log'
 $sent=@(Get-Content $controllerLog)
 $leftMessages=@($sent|Where-Object{$_ -match 'source_message_sent=LEFT'})
 $rightMessages=@($sent|Where-Object{$_ -match 'source_message_sent=RIGHT'})
 $results.manual_left_messages=$leftMessages.Count
 $results.manual_right_messages=$rightMessages.Count
 if($leftMessages.Count -lt 2 -or $rightMessages.Count -lt 1){throw 'Manual LEFT/RIGHT/LEFT messages incomplete'}
 $results.single_preview_process=(@(Get-Process visual_app -ErrorAction SilentlyContinue).Count -eq 1 -and @(Get-Process visual_app)[0].Id -eq $previewPid)
 $telemetry=Join-Path $latest.FullName 'live-telemetry.csv'
 $results.renderer_rebinds=@(Select-String -Path $telemetry -SimpleMatch 'poc_source_switch_started').Count
 Click-Button 'Stop Vision preview'
 for($i=0;$i -lt 50;$i++){Pump 180;if(@(Get-Process visual_app -ErrorAction SilentlyContinue).Count -eq 0){break}}
 $results.graceful_shutdown=(@(Get-Process visual_app -ErrorAction SilentlyContinue).Count -eq 0)
 if(-not $results.graceful_shutdown){throw 'Preview did not exit normally'}
 $results.status=if($results.single_preview_process -and $results.renderer_rebinds -ge 2){'PASS'}else{'FAIL'}
}catch{$results.status='FAIL';$results.error=$_.Exception.Message}
finally{
 $w=Get-Controller
 if($w){[void][VisionAutoFocusTestNative]::PostMessage([IntPtr]$w.Current.NativeWindowHandle,0x10,[UIntPtr]::Zero,[IntPtr]::Zero)}
 foreach($f in $fixtures){try{$f.Close();$f.Dispose()}catch{}}
 [void][VisionAutoFocusTestNative]::SetCursorPos($originalPointer.X,$originalPointer.Y)
 $after=New-Object VisionAutoFocusTestNative+POINT
 [void][VisionAutoFocusTestNative]::GetCursorPos([ref]$after)
 $results.pointer_restored=($after.X -eq $originalPointer.X -and $after.Y -eq $originalPointer.Y)
 [void][VisionAutoFocusTestNative]::SetForegroundWindow($originalForeground)
 $results.focus_restored=([VisionAutoFocusTestNative]::GetForegroundWindow() -eq $originalForeground)
 $output=Join-Path $root ('artifacts\vision-poc-a-graphics-20261017\poc-a-manual-switch-native-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'.json')
 if(Test-Path $output){throw 'Evidence path exists; refuse overwrite'}
 [IO.File]::WriteAllText($output,($results|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
}
$results|ConvertTo-Json -Depth 8
if($results.status -ne 'PASS'){exit 2}