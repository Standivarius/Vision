# A02 4x Excel caret visual-capture experiment. Disposable Office document only.
# Captures software-visible pixels independently, never claims camera/photons.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Enter-VisionGuiAssessmentLock.ps1')
$visionGuiLock=Enter-VisionGuiAssessmentLock
try {
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
Set-Location $root
$diag=Join-Path $root 'app\build\Release\visual_diagnostics.exe'
$exe=Join-Path $root 'app\build\Release\visual_app.exe'
$stimulus=Join-Path $PSScriptRoot 'A03-ProbeOfficeSwitchStimulus.ps1'
if(@(Get-Process EXCEL,WINWORD -ErrorAction SilentlyContinue).Count){throw 'BLOCKED existing Office process'}
if(@(Get-Process visual_app -ErrorAction SilentlyContinue).Count){throw 'BLOCKED existing Vision preview'}
& python.exe 'lab\pocs\doxa\assessment\A02_display_preflight.py' | Out-Null
if($LASTEXITCODE -ne 0){throw 'BLOCKED 3/4 display console unavailable'}
$mon=@(((& $diag|Out-String)|ConvertFrom-Json).monitors)
$external=@($mon|Where-Object{-not $_.primary}|Sort-Object{$_.bounds.left})
if($mon.Count -lt 3 -or $mon.Count -gt 4 -or $external.Count -lt 2){throw 'BLOCKED roles ambiguous'}
$right=$external[-1]
$centre=$external[-2]
$sourceId=[array]::IndexOf($mon,$right)
$destId=[array]::IndexOf($mon,$centre)
$run=Join-Path $root ('artifacts\vision-poc-a-graphics-20261017\office-switch-4x-visual-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,6))
[void][IO.Directory]::CreateDirectory($run)
Add-Type -TypeDefinition @"
using System; using System.Text; using System.Runtime.InteropServices;
public static class VisionA02OwnedPreviewClose {
 public delegate bool Callback(IntPtr hwnd,IntPtr data);
 [DllImport("user32.dll")] public static extern bool EnumWindows(Callback cb,IntPtr data);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint pid);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr hwnd,StringBuilder buffer,int n);
 [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hwnd,uint msg,UIntPtr wparam,IntPtr lparam);
 public static IntPtr Find(uint owner) {
  IntPtr answer=IntPtr.Zero;int count=0;
  EnumWindows((hwnd,data)=>{
   uint pid;GetWindowThreadProcessId(hwnd,out pid);
   if(pid!=owner)return true;
   var cls=new StringBuilder(120);GetClassName(hwnd,cls,120);
   if(cls.ToString()=="VisualDetailWindow"){count++;answer=hwnd;}
   return true;
  },IntPtr.Zero);
  return count==1?answer:IntPtr.Zero;
 }
}
"@
$report=[ordered]@{scenario='A03-office-4x-switch-visible-targets';run_directory=$run;status='INCONCLUSIVE';display_count=$mon.Count;source_monitor=$right.device_name;destination_monitor=$centre.device_name;zoom_requested=4;source_side_office_result=$null;centre_frames=0;right_frames=0;preview_shutdown='NOT_STARTED';reason='Unscored two-application screenshots require independent oracle'}
$officeRunner=$null;$preview=$null;$centerRecorder=$null;$rightRecorder=$null
$started=(Get-Date)
try{
 $officeRunner=Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$stimulus+'"')) -PassThru -WindowStyle Hidden
 $officeDeadline=[DateTime]::UtcNow.AddSeconds(38)
 while((-not (Get-Process EXCEL -ErrorAction SilentlyContinue)) -and [DateTime]::UtcNow -lt $officeDeadline){if($officeRunner.HasExited){throw 'Office fixture ended before both Office apps started'};Start-Sleep -Milliseconds 250}
 if((-not(Get-Process EXCEL -ErrorAction SilentlyContinue)) -or (-not(Get-Process WINWORD -ErrorAction SilentlyContinue))){throw 'Both disposable Office apps did not open'}
 Start-Sleep -Milliseconds 700
 $telemetry=Join-Path $run 'vision-diagnostic.csv'
 if(@(Get-Process visual_app -ErrorAction SilentlyContinue).Count){throw 'BLOCKED: competing Vision preview detected'}
 $preview=Start-Process -FilePath $exe -ArgumentList @('--source',[string]$sourceId,'--dest',[string]$destId,'--zoom','4','--log',('"'+$telemetry+'"')) -PassThru
 $report['vision_pid']=$preview.Id
 Start-Sleep -Milliseconds 800
 if(-not(Get-Process -Id $preview.Id -ErrorAction SilentlyContinue)){throw 'Vision 4x preview exited before capture'}
 $anchor=[long]((& python.exe -c 'import time;print(time.perf_counter_ns())'|Out-String).Trim())
 $report['anchor_qpc_ns']=$anchor
 $centerRecorder=Start-Process -FilePath 'python.exe' -WorkingDirectory $root -ArgumentList @('lab\pocs\doxa\assessment\A02_frame_recorder.py','--output-dir',(Join-Path $run 'centre'),'--role','CENTRE','--seconds','63','--fps','2','--width','480','--height','270','--anchor-qpc-ns',[string]$anchor,'--confirm-disposable-content') -PassThru -WindowStyle Hidden
 $rightRecorder=Start-Process -FilePath 'python.exe' -WorkingDirectory $root -ArgumentList @('lab\pocs\doxa\assessment\A02_frame_recorder.py','--output-dir',(Join-Path $run 'right'),'--role','RIGHT','--seconds','63','--fps','2','--width','480','--height','270','--anchor-qpc-ns',[string]$anchor,'--confirm-disposable-content') -PassThru -WindowStyle Hidden
 [void]$officeRunner.WaitForExit(110000)
 if(-not $officeRunner.HasExited){throw 'Office switch stimulus timed out'}
 $report['office_script_exit']=$officeRunner.ExitCode
 $docEvidence=Get-ChildItem 'artifacts\vision-poc-a-graphics-20261017' -Directory -Filter 'office-switch-stimulus-*' | Where-Object{$_.CreationTime -ge $started} | Sort-Object LastWriteTime -Descending | Select-Object -First 1
 if(-not $docEvidence){throw 'Office switch stimulus evidence not written'}
 $sourceResult=Get-Content -Raw (Join-Path $docEvidence.FullName 'result.json') |ConvertFrom-Json
 $report.source_side_office_result=$sourceResult.status
 $report['source_report_path']=$docEvidence.FullName
 $report['source_switch_observations']=@($sourceResult.observations).Count
 foreach($recorder in @($centerRecorder,$rightRecorder)){
  [void]$recorder.WaitForExit(80000)
  if(-not $recorder.HasExited){throw 'Independent recorder timeout'}
  if($recorder.ExitCode -ne 0){throw ('Independent recorder exit '+$recorder.ExitCode)}
 }
 $report.centre_frames=@(Get-Content (Join-Path $run 'centre\frame_manifest.jsonl') |Where-Object{$_ -match 'panel_capture'}).Count
 $report.right_frames=@(Get-Content (Join-Path $run 'right\frame_manifest.jsonl') |Where-Object{$_ -match 'panel_capture'}).Count
 $report.status='CAPTURED_NOT_YET_SCORED'
}catch{
 $report['error']=$_.Exception.Message
 $report.status=if($_.Exception.Message.StartsWith('BLOCKED')){'BLOCKED'}else{'INCONCLUSIVE'}
}finally{
 foreach($rec in @($centerRecorder,$rightRecorder,$officeRunner)){
  if($rec -and -not $rec.HasExited){try{Stop-Process -Id $rec.Id -Force -ErrorAction SilentlyContinue}catch{}}
 }
 if($preview){
  $p=Get-Process -Id $preview.Id -ErrorAction SilentlyContinue
  if($p){
   $detailHwnd=[VisionA02OwnedPreviewClose]::Find([uint32]$preview.Id)
   if($detailHwnd -ne [IntPtr]::Zero){
    $report['preview_exit_requested']=[VisionA02OwnedPreviewClose]::PostMessage($detailHwnd,256,[UIntPtr]::new(27),[IntPtr]::Zero)
   }else{$report['preview_exit_requested']=$p.CloseMainWindow()}
   if($p.WaitForExit(10000)){$report.preview_shutdown='NORMAL'}else{
    try{Stop-Process -Id $preview.Id -Force -ErrorAction Stop;$report.preview_shutdown='OWNED_PROCESS_FORCE_AFTER_TIMEOUT'}catch{$report.preview_shutdown='FAILED_TO_CLOSE'}
   }
  }else{$report.preview_shutdown='ALREADY_EXITED'}
 }
 [IO.File]::WriteAllText((Join-Path $run 'result.json'),($report|ConvertTo-Json -Depth 7),[Text.UTF8Encoding]::new($false))
}
$report|ConvertTo-Json -Depth 6
if($report.status -eq 'CAPTURED_NOT_YET_SCORED'){exit 0}else{exit 3}

} finally {
 Exit-VisionGuiAssessmentLock -Mutex $visionGuiLock
}
