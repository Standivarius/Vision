<#
.SYNOPSIS
  Guarded physical-console Doxa AT test adapter using the existing 10-Nov scripts.
.DESCRIPTION
  Defaults to plan only. Execute requires TWO explicit switches, physical
  preflight, and writes to a new evidence folder. Never restarts Windows,
  changes display topology/drivers, or overwrites historical evidence.
#>
[CmdletBinding()]
param(
 [ValidateSet('WideNone','WideMagnifier','WideNVDA','WideZoomText','AppsMagnifier','AppsNVDA','AppsZoomText')]
 [string]$Case='WideNone',
 [switch]$Preflight,
 [switch]$Execute,
 [switch]$PhysicalApproval,
 [ValidateRange(45,360)][int]$TimeoutSeconds=220
)
$ErrorActionPreference='Stop'
$repo='C:\dev\Vision'
$sourceDir=Join-Path $repo 'artifacts\2026-11-10__sm770_closure'
$runRoot=Join-Path $repo 'artifacts\doxa-at-pipeline-runs'
$inspect=Join-Path $repo 'lab\pocs\doxa\assessment\A02_display_preflight.py'
$env:PYTHONDONTWRITEBYTECODE='1'
$scriptFile=if($Case -like 'Wide*'){'run_wide_interaction_v1.ps1'}else{'run_three_real_apps_v4.ps1'}
$mode=if($Case -match 'None$'){'NONE'}elseif($Case -match 'Magnifier$'){'MAGNIFIER'}elseif($Case -match 'NVDA$'){'NVDA'}else{'ZOOMTEXT'}
Write-Output ('CASE='+$Case+' MODE='+$mode+' SCRIPT='+$scriptFile)
Write-Output ('WRITE_MODE='+$(if($Execute){'LIVE'}else{'PLAN_ONLY'}))
Write-Output 'ORIGINAL_HISTORICAL_EVIDENCE=IMMUTABLE'
Write-Output 'REBOOT_DRIVER_DISPLAY_CONFIGURATION=NOT_PERMITTED'

if(-not $Execute -and -not $Preflight){Write-Output 'PLAN READY. No program launched.';exit 0}
if($Execute -and -not $PhysicalApproval){
  throw 'Physical execution requires both -Execute and -PhysicalApproval.'
}
if(-not(Test-Path $inspect)){throw 'Missing canonical read-only A02 display probe.'}
$probeText=& python.exe $inspect 2>&1
$probeExit=$LASTEXITCODE
if($probeExit -ne 0){throw ('PHYSICAL_PREFLIGHT_FAILED exit='+$probeExit+' details='+($probeText -join ' '))}
$probe=$probeText|Select-Object -Last 1|ConvertFrom-Json
if(-not $probe.physical_console -or -not $probe.topology_ok -or -not $probe.unlocked -or $probe.display_count -ne 4){
  throw 'Physical console, unlocked four-screen topology required.'
}
Write-Output 'PREFLIGHT=PASS physical console/unlocked/four displays'
if(-not $Execute){Write-Output 'PREFLIGHT ONLY; NO AT APPLICATION LAUNCHED';exit 0}
if(@(Get-Process WINWORD,EXCEL -ErrorAction SilentlyContinue).Count -gt 0 -and $Case -like 'Apps*'){
  throw 'Office already running; will not interfere with existing documents.'
}
if(@(Get-Process Magnify,nvda,Zt -ErrorAction SilentlyContinue).Count -gt 0){
  throw 'One or more assistive applications already running. Refusing to interfere.'
}
$camera=Get-Command ffmpeg.exe -ErrorAction SilentlyContinue
if(-not $camera){throw 'FFmpeg/camera evidence tool not installed.'}
$src=Join-Path $sourceDir $scriptFile
if(-not(Test-Path $src)){throw ('Approved source script missing: '+$src)}
if($Case -like 'Apps*' -and -not(Test-Path (Join-Path $sourceDir 'edge_input_readback.html'))){
  throw 'Controlled offline Edge source missing.'
}
$ini='C:\ProgramData\Freedom Scientific\ZoomText\2027\DisplayAdapter.ini'
$iniHash=if(Test-Path $ini){(Get-FileHash $ini -Algorithm SHA256).Hash}else{$null}
$beforeWifi=(Get-NetAdapter -Name 'Wi-Fi' -ErrorAction SilentlyContinue).Status.ToString()
$runId=(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+$Case+'-'+[guid]::NewGuid().ToString('N').Substring(0,8)
$dir=Join-Path $runRoot $runId
$null=New-Item -ItemType Directory -Path $dir -Force
$source=Get-Content $src -Raw
# These checked legacy scripts hard-code their output folder. Redirect only
# output folder; never modify originals or the installed vendor application.
$adapted=$source.Replace($sourceDir,$dir)
if($adapted -eq $source){throw 'Refused: expected output-directory anchor not found.'}
$staged=Join-Path $dir $scriptFile
[IO.File]::WriteAllText($staged,$adapted,[Text.UTF8Encoding]::new($false))
if($Case -like 'Apps*'){
  Copy-Item (Join-Path $sourceDir 'edge_input_readback.html') (Join-Path $dir 'edge_input_readback.html')
}
$log=Join-Path $dir 'stdout.txt'
$err=Join-Path $dir 'stderr.txt'
$state=[ordered]@{
 schema_version='1.0';case=$Case;mode=$mode;started=(Get-Date).ToString('o')
 source_script=$src;source_sha256=(Get-FileHash $src -Algorithm SHA256).Hash
 physical_preflight=$probe;original_zoomtext_ini_sha256=$iniHash
 initial_wifi=$beforeWifi;status='INCOMPLETE';error=$null
}
$exitcode=-1
try {
 $ps="$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
 $arg=@('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',('"'+$staged+'"'),'-Mode',$mode)
 $proc=Start-Process -FilePath $ps -ArgumentList $arg -WorkingDirectory $repo -PassThru -RedirectStandardOutput $log -RedirectStandardError $err
 if(-not $proc.WaitForExit($TimeoutSeconds*1000)){
   & taskkill.exe /PID $proc.Id /T /F 2>&1|Out-Null
   throw 'TIMEOUT: approved runner exceeded limit'
 }
 $exitcode=$proc.ExitCode
 if($exitcode -ne 0){throw ('Runner exited '+$exitcode)}
 $result=if($Case -like 'Wide*'){
   Join-Path $dir ('wide_'+$mode.ToLowerInvariant()+'_result.json')
 }else{
   Join-Path $dir ('three_real_apps_'+$mode.ToLowerInvariant()+'_v4.json')
 }
 if(-not(Test-Path $result)){throw 'The runner returned no structured result.'}
 $outcome=Get-Content $result -Raw | ConvertFrom-Json
 $expected=if($Case -like 'Wide*'){'INPUT_AND_OPTICAL_CAPTURE_PASSED'}else{'THREE_APPS_INPUT_PASSED'}
 if($outcome.status -ne $expected){throw ('Evidence did not meet success oracle: '+$outcome.status)}
 $state.status='PASS'
 $state.result_file=$result
}catch{
 $state.status='FAILED'
 $state.error=$_.Exception.Message
}finally{
 $state.exit_code=$exitcode
 $state.finished=(Get-Date).ToString('o')
 $state.current_wifi=(Get-NetAdapter -Name 'Wi-Fi' -ErrorAction SilentlyContinue).Status.ToString()
 $state.current_zoomtext_ini_sha256=if(Test-Path $ini){(Get-FileHash $ini -Algorithm SHA256).Hash}else{$null}
 if($state.original_zoomtext_ini_sha256 -ne $state.current_zoomtext_ini_sha256){
   $state.status='FAILED'
   $state.error=($state.error+' Configuration hash changed; manual review required.').Trim()
 }
 if($state.current_wifi -ne $state.initial_wifi){
   $state.status='FAILED'
   $state.error=($state.error+' Wi-Fi status changed; manual review required.').Trim()
 }
 $state|ConvertTo-Json -Depth 8|Set-Content (Join-Path $dir 'result.json') -Encoding UTF8
 Write-Output ('RUN_DIR='+$dir)
 Write-Output ('RESULT='+$state.status)
 if($state.error){Write-Output ('REASON='+$state.error)}
}
if($state.status -ne 'PASS'){exit 3}

