param(
 [Parameter(Mandatory=$true)][ValidateSet('Vision','ZoomText','SuperNova','Other')][string]$Product,
 [Parameter(Mandatory=$true)][ValidateSet('caret_focus_native','pointer_sweep','cross_monitor','manual')][string]$Scenario,
 [string]$ProcessName='',
 [string]$Notes=''
)
$ErrorActionPreference='Stop'
$repo=Resolve-Path (Join-Path $PSScriptRoot '..\..')
$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss';$safe=$Product.ToLowerInvariant();$run=Join-Path $repo ('lab\benchmarks\incumbent_research\runs\'+$stamp+'__'+$safe+'__'+$Scenario)
New-Item -ItemType Directory -Force $run|Out-Null
if(-not$ProcessName){switch($Product){'Vision'{$ProcessName='visual_app'} default{$ProcessName=''}}}
$duration=switch($Scenario){'caret_focus_native'{13};'pointer_sweep'{8};'cross_monitor'{9};'manual'{12}}
$observer=Join-Path $PSScriptRoot 'run-observation-native.ps1';$stim=Join-Path $PSScriptRoot 'run-stimulus.ps1'
$args=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$observer,'-Product',$Product,'-DurationSec',[string]$duration,'-FrameIntervalMs','100','-OutputDir',$run)
if($ProcessName){$args+=@('-ProcessName',$ProcessName)}
$obsOut=Join-Path $run 'observer_stdout.log';$obsErr=Join-Path $run 'observer_stderr.log'
$op=Start-Process powershell.exe -ArgumentList $args -RedirectStandardOutput $obsOut -RedirectStandardError $obsErr -PassThru
Start-Sleep -Milliseconds 700
$stimError=$null
try{& $stim -Scenario $Scenario -RunDirectory $run}catch{$stimError=$_.Exception.Message}
$op.WaitForExit(30000)|Out-Null; $op.Refresh()
if(-not$op.HasExited){Stop-Process -Id $op.Id -Force -ErrorAction SilentlyContinue;throw 'Observer did not exit'}
if($op.ExitCode-ne0){$err=if(Test-Path $obsErr){Get-Content $obsErr -Raw}else{''};throw "Observer failed exit=$($op.ExitCode): $err"}
if($stimError){throw "Stimulus failed: $stimError"}
$meta=[ordered]@{product=$Product;scenario=$Scenario;process_name=$ProcessName;notes=$Notes;run_dir=$run;observer_exit=$op.ExitCode;completed_at=(Get-Date).ToString('o')}
$meta|ConvertTo-Json -Depth 4|Set-Content -Encoding UTF8 (Join-Path $run 'run_summary.json')
Write-Output $run
