# User-level Vision OpenAI tunnel keeper. Does not request elevation.
# Does not affect the separate project-dev tunnel.
param([switch]$Probe)
$ErrorActionPreference='Stop'
$service='VisionOpenAITunnelKeepalive'
$log=Join-Path $env:LOCALAPPDATA 'Standivarius\Vision\vision-bridge-watch.log'
function Note([string]$message){
 try{
  $dir=Split-Path $log -Parent
  if(-not(Test-Path $dir)){[void][IO.Directory]::CreateDirectory($dir)}
  if((Test-Path $log) -and (Get-Item $log).Length -gt 1048576){
   Move-Item $log ($log+'.previous') -Force
  }
  [IO.File]::AppendAllText($log,((Get-Date -Format o)+' '+$message+[Environment]::NewLine))
 }catch{}
}
try{
 $task=Get-ScheduledTask -TaskName $service -ErrorAction SilentlyContinue
 if(-not $task){Note 'NO_KEEPALIVE_TASK';exit 3}
 $state=[string]$task.State
 if($Probe){
  [pscustomobject]@{service=$service;state=$state;action=if($state -eq 'Ready'){'would_start'}elseif($state -eq 'Running'){'none'}else{'none_unexpected_state'}}|ConvertTo-Json -Compress
  exit 0
 }
 if($state -eq 'Ready'){
  Start-ScheduledTask -TaskName $service -ErrorAction Stop
  Note 'VISION_KEEPALIVE_RESTART_REQUESTED'
 }elseif($state -ne 'Running'){
  Note ('NO_ACTION_STATE_'+$state)
 }
}catch{
 Note ('WATCH_ERROR '+$_.Exception.Message)
 exit 5
}

