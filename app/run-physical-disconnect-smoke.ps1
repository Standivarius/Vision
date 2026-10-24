param(
    [ValidateRange(30,300)][int]$DisconnectTimeoutSeconds = 120,
    [ValidateRange(30,300)][int]$ReconnectTimeoutSeconds = 120
)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class VisualPhysicalDisconnectNative {
  [DllImport("kernel32.dll")] public static extern uint WTSGetActiveConsoleSessionId();
}
'@ -ErrorAction SilentlyContinue

$repo=Resolve-Path (Join-Path $PSScriptRoot '..')
$exe=Join-Path $PSScriptRoot 'build\Release\visual_app.exe'
if(-not(Test-Path $exe)){throw "Visual app not built: $exe"}
$processSession=[Diagnostics.Process]::GetCurrentProcess().SessionId
$consoleSession=[VisualPhysicalDisconnectNative]::WTSGetActiveConsoleSessionId()
if($processSession-ne$consoleSession){throw "Physical disconnect smoke requires active console session. Process=$processSession Console=$consoleSession"}
$initialScreens=@([Windows.Forms.Screen]::AllScreens)
if($initialScreens.Count-lt2){throw "Physical disconnect smoke requires at least two displays; found $($initialScreens.Count)"}

$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$run=Join-Path $repo ("lab\benchmarks\integrated_app\runs\${stamp}__physical_disconnect_smoke")
New-Item -ItemType Directory -Force -Path $run|Out-Null
$telemetry=Join-Path $run 'visual_app_telemetry.csv'
$status=Join-Path $run 'status.json'
$vp=$null

function Write-Status([string]$phase,[hashtable]$extra=@{}){
  $obj=[ordered]@{phase=$phase;updated_at=(Get-Date).ToString('o');run_dir=$run;initial_display_count=$initialScreens.Count}
  foreach($k in $extra.Keys){$obj[$k]=$extra[$k]}
  $obj|ConvertTo-Json -Depth 5|Set-Content -Encoding UTF8 $status
}

try {
  Write-Status 'starting_visual'
  $vp=Start-Process $exe -ArgumentList @('--zoom','2','--log',$telemetry) -PassThru
  $deadline=(Get-Date).AddSeconds(8)
  while((Get-Date)-lt$deadline-and$vp.MainWindowHandle-eq0-and-not$vp.HasExited){Start-Sleep -Milliseconds 100;$vp.Refresh()}
  if($vp.HasExited){throw "Visual exited before disconnect test was armed. Exit=$($vp.ExitCode)"}

  # Give WGC time to deliver initial frames, but do not require the buffered CSV stream to have flushed yet.
  Start-Sleep -Milliseconds 1200
  $vp.Refresh()
  if($vp.HasExited){throw "Visual exited before disconnect test was armed. Exit=$($vp.ExitCode)"}
  $preFrames=0
  if(Test-Path $telemetry){
    try{$preFrames=@(Import-Csv $telemetry -ErrorAction Stop).Count}catch{$preFrames=0}
  }

  Write-Status 'ready_for_disconnect' @{visual_pid=$vp.Id;pre_disconnect_frames=$preFrames}
  'SAFE TO UNPLUG HDMI NOW'|Set-Content -Encoding UTF8 (Join-Path $run 'READY_FOR_DISCONNECT.txt')

  $disconnectDeadline=(Get-Date).AddSeconds($DisconnectTimeoutSeconds)
  while((Get-Date)-lt$disconnectDeadline){
    $vp.Refresh()
    if($vp.HasExited){break}
    Start-Sleep -Milliseconds 100
  }
  if(-not$vp.HasExited){
    Write-Status 'disconnect_timeout' @{visual_pid=$vp.Id}
    throw "Visual did not exit within $DisconnectTimeoutSeconds seconds after test was armed"
  }
  $vp.Refresh()
  $exitCode=$vp.ExitCode
  $telemetryRaw=if(Test-Path $telemetry){Get-Content -Raw $telemetry}else{''}
  $eventLines=@(Get-Content $telemetry -ErrorAction SilentlyContinue|Where-Object{$_.StartsWith('# event=')})
  $eventOrder=@($eventLines|ForEach-Object{$_.Substring(8)})
  $screenCountAfterDisconnect=@([Windows.Forms.Screen]::AllScreens).Count
  Write-Status 'ready_for_reconnect' @{visual_exit=$exitCode;display_count_after_disconnect=$screenCountAfterDisconnect;event_order=$eventOrder}
  'SAFE TO RECONNECT HDMI NOW'|Set-Content -Encoding UTF8 (Join-Path $run 'READY_FOR_RECONNECT.txt')

  $reconnectDeadline=(Get-Date).AddSeconds($ReconnectTimeoutSeconds)
  $reconnected=$false
  $reconnectedCount=$screenCountAfterDisconnect
  while((Get-Date)-lt$reconnectDeadline){
    $reconnectedCount=@([Windows.Forms.Screen]::AllScreens).Count
    if($reconnectedCount-ge$initialScreens.Count){$reconnected=$true;break}
    Start-Sleep -Milliseconds 250
  }

  $rows=@(Import-Csv $telemetry -ErrorAction SilentlyContinue)
  $presentFailures=@($rows|Where-Object{[uint64]$_.present_hr-ne0}).Count
  $shutdownTopology=($telemetryRaw -match '# event=shutdown_display_topology_changed')
  $shutdownCaptureClosed=($telemetryRaw -match '# event=shutdown_capture_source_closed')
  $captureItemClosed=($telemetryRaw -match '# event=capture_item_closed')
  $safeExit=($exitCode-eq11-or$exitCode-eq12)
  $pass=($safeExit-and$rows.Count-gt0-and$presentFailures-eq0-and$reconnected)
  $analysis=[ordered]@{
    captured_at=(Get-Date).ToString('o')
    machine=$env:COMPUTERNAME
    process_session_id=$processSession
    active_console_session_id=$consoleSession
    initial_display_count=$initialScreens.Count
    display_count_after_disconnect=$screenCountAfterDisconnect
    display_count_after_reconnect=$reconnectedCount
    reconnected=$reconnected
    visual_exit=$exitCode
    frames=$rows.Count
    present_failures=$presentFailures
    capture_item_closed_event=$captureItemClosed
    shutdown_capture_source_closed_event=$shutdownCaptureClosed
    shutdown_display_topology_changed_event=$shutdownTopology
    event_order=$eventOrder
    pass=$pass
  }
  $analysis|ConvertTo-Json -Depth 6|Set-Content -Encoding UTF8 (Join-Path $run 'analysis.json')
  @(
   '# Integrated Visual physical disconnect/reconnect smoke','',
   "- Initial displays: $($initialScreens.Count)",
   "- Displays after disconnect: $screenCountAfterDisconnect",
   "- Displays after reconnect: $reconnectedCount",
   "- Reconnected within timeout: $reconnected",
   "- Visual exit code: $exitCode",
   "- Frames before shutdown: $($rows.Count)",
   "- Present failures: $presentFailures",
   "- Capture-item Closed observed: $captureItemClosed",
   "- Shutdown capture-source-closed event: $shutdownCaptureClosed",
   "- Shutdown display-topology-change event: $shutdownTopology",
   "- Event order: $($eventOrder -join ' -> ')",
   "- Pass: $pass"
  )-join"`r`n"|Set-Content -Encoding UTF8 (Join-Path $run 'SUMMARY.md')
  Write-Status 'complete' @{visual_exit=$exitCode;reconnected=$reconnected;pass=$pass;analysis=(Join-Path $run 'analysis.json')}
  if(-not$pass){throw "Physical disconnect/reconnect smoke did not meet acceptance criteria. See $run"}
  Write-Host "Physical disconnect/reconnect smoke complete: $run"
  Get-Content (Join-Path $run 'SUMMARY.md')
}
finally {
  if($vp){
    try{$vp.Refresh()}catch{}
    if(-not$vp.HasExited){Stop-Process -Id $vp.Id -Force -ErrorAction SilentlyContinue}
  }
}
