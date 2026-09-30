param(
    [ValidateRange(5,100)][int]$SampleMs = 25
)
$ErrorActionPreference='Stop'

$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$repo=Resolve-Path (Join-Path $root '..\..\..')
$probe=Join-Path $root 'build\Release\visual_spike3_probe.exe'
$stimulus=Join-Path $root 'build\Release\visual_spike3_stimulus.exe'
if(-not (Test-Path $probe)){throw "Missing probe: $probe"}
if(-not (Test-Path $stimulus)){throw "Missing stimulus: $stimulus"}

$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$run=Join-Path $repo ("lab\benchmarks\spike3_focus_caret_evidence\runs\${stamp}__native_baseline")
New-Item -ItemType Directory -Force -Path $run | Out-Null
$scenario=Join-Path $run 'scenario_events.jsonl'
$probeOut=Join-Path $run 'probe_stdout.txt'
$probeErr=Join-Path $run 'probe_stderr.txt'
$probeMarker=Join-Path $run 'probe_completed.txt'

$stim=Start-Process -FilePath $stimulus -ArgumentList @($scenario) -PassThru
Start-Sleep -Milliseconds 250
$probeProc=Start-Process -FilePath $probe -ArgumentList @('--out',$run,'--duration-ms','11500','--sample-ms',[string]$SampleMs) -WindowStyle Hidden -RedirectStandardOutput $probeOut -RedirectStandardError $probeErr -PassThru

$probeProc.WaitForExit()
$stim.WaitForExit()
$probeProc.Refresh()
$stim.Refresh()
$stimExit=$stim.ExitCode
$probeExit=$probeProc.ExitCode
$probeCompleted=Test-Path $probeMarker

$manifest=[ordered]@{
  captured_at=(Get-Date).ToString('o')
  machine=$env:COMPUTERNAME
  process_session_id=[System.Diagnostics.Process]::GetCurrentProcess().SessionId
  inherited_session_name=$env:SESSIONNAME
  run_type='native_deterministic_baseline'
  sample_ms=$SampleMs
  stimulus_pid=$stim.Id
  stimulus_exit=$stimExit
  probe_pid=$probeProc.Id
  probe_exit=$probeExit
  probe_completed_marker=$probeCompleted
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $run 'manifest.json')

if($stimExit -ne 0){throw "Stimulus failed: $stimExit"}
if(-not $probeCompleted){throw "Probe did not write completion marker. Exit=$probeExit. See $probeErr"}
if($null -ne $probeExit -and $probeExit -ne 0){throw "Probe failed: $probeExit. See $probeErr"}

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'analyze-run.ps1') -RunDir $run
if($LASTEXITCODE -ne 0){throw "Analysis failed: $LASTEXITCODE"}
Write-Host "Spike 3 baseline complete: $run"
