param(
  [Parameter(Mandatory=$true)][ValidateSet('Vision','ZoomText','SuperNova','Other')][string]$Product,
  [Parameter(Mandatory=$true)][ValidateSet('pointer_sweep','caret_navigation','focus_navigation','cross_monitor','manual_feature')][string]$Scenario,
  [string]$ProcessName='',
  [string]$Notes='',
  [ValidateRange(8,120)][int]$DurationSec=18
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=Resolve-Path (Join-Path $PSScriptRoot '..\..')
$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$run=Join-Path $repo ("lab\benchmarks\incumbent_research\runs\${stamp}__"+$Product.ToLowerInvariant()+'__'+$Scenario)
New-Item -ItemType Directory -Force $run|Out-Null
$vision=$null
if($Product-eq'Vision'){
  $exe=Join-Path $repo 'app\build\Release\visual_app.exe';if(-not(Test-Path $exe)){throw "Vision executable missing: $exe"}
  Get-Process visual_app -ErrorAction SilentlyContinue|Where-Object{try{$_.Path-eq$exe}catch{$false}}|Stop-Process -Force -ErrorAction SilentlyContinue
  $vision=Start-Process $exe -ArgumentList @('--zoom','2','--log',(Join-Path $run 'vision_telemetry.csv')) -PassThru
  Start-Sleep -Milliseconds 1200
  if($vision.HasExited){throw "Vision exited early: $($vision.ExitCode)"}
  $ProcessName='visual_app'
}
$obsArgs=@('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $PSScriptRoot 'run-observation.ps1'),'-Product',$Product,'-DurationSec',[string]$DurationSec,'-OutputDir',$run)
if($ProcessName){$obsArgs+=@('-ProcessName',$ProcessName)}
$obsOut=Join-Path $run 'observer_child_stdout.log'
$obsErr=Join-Path $run 'observer_child_stderr.log'
$obs=Start-Process powershell.exe -ArgumentList $obsArgs -RedirectStandardOutput $obsOut -RedirectStandardError $obsErr -PassThru
Start-Sleep -Milliseconds 1200
$driverError=$null
try {& (Join-Path $PSScriptRoot 'drive-scenario.ps1') -Scenario $Scenario -RunDirectory $run -StartDelayMs 700} catch {$driverError=$_.Exception.Message}
$obs.WaitForExit([math]::Max(30000,($DurationSec+15)*1000))|Out-Null
if(-not$obs.HasExited){Stop-Process -Id $obs.Id -Force -ErrorAction SilentlyContinue;throw 'Observer did not exit in time'}
if($vision){
  try{(New-Object -ComObject WScript.Shell).SendKeys('^%q')}catch{}
  if(-not$vision.WaitForExit(4000)){Stop-Process -Id $vision.Id -Force -ErrorAction SilentlyContinue}
}
$profile=Join-Path $run 'edge_profile';if(Test-Path $profile){Remove-Item $profile -Recurse -Force -ErrorAction SilentlyContinue}
$analysisPath=Join-Path $run 'observer_analysis.json';$analysis=$null;if(Test-Path $analysisPath){$analysis=Get-Content $analysisPath -Raw|ConvertFrom-Json}
$stimulus=Join-Path $run 'stimulus_events.csv';$stimulusRows=if(Test-Path $stimulus){@(Import-Csv $stimulus).Count}else{0}
$obs.Refresh();$obsExit=if($obs.HasExited){$obs.ExitCode}else{$null};$summary=[ordered]@{product=$Product;scenario=$Scenario;observer_exit=$obsExit;driver_error=$driverError;stimulus_events=$stimulusRows;video_present=(Test-Path (Join-Path $run 'desktop.mp4'));observer_samples=if($analysis){$analysis.samples}else{0};product_process_observed=if($analysis){$analysis.product_process_observed}else{$false}}
$summary|ConvertTo-Json -Depth 4|Set-Content -Encoding UTF8 (Join-Path $run 'comparison_analysis.json')
@("# Comparative scenario","","- Product: $Product","- Scenario: $Scenario","- Observer exit: $obsExit","- Driver error: $driverError","- Stimulus events: $stimulusRows","- Observer samples: $($summary.observer_samples)","- Product process observed: $($summary.product_process_observed)","- Video present: $($summary.video_present)") -join "`r`n" | Set-Content -Encoding UTF8 (Join-Path $run 'SUMMARY.md')
if(-not(Test-Path $analysisPath)){ $detail=if(Test-Path $obsErr){Get-Content $obsErr -Raw}else{''}; throw "Observer evidence missing: $detail ($run)" }
if($driverError){throw "Stimulus driver failed: $driverError ($run)"}
Write-Output $run
