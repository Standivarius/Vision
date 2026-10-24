param(
 [Parameter(Mandatory=$true)][ValidateSet('Vision','ZoomText','SuperNova','Other')][string]$Product,
 [Parameter(Mandatory=$true)][ValidateSet('pointer_sweep','caret_navigation','focus_navigation','cross_monitor','manual_feature')][string]$Scenario,
 [string]$ProcessName='',
 [string]$Notes='',
 [ValidateRange(8,120)][int]$DurationSec=20
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Windows.Forms
$repo=Resolve-Path (Join-Path $PSScriptRoot '..\..')
$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$run=Join-Path $repo ("lab\benchmarks\incumbent_research\runs\${stamp}__"+$Product.ToLower()+"__${Scenario}")
New-Item -ItemType Directory -Force $run|Out-Null
$events=Join-Path $run 'scenario_events.csv'
'qpc,event,detail'|Set-Content -Encoding ascii $events
function Ev([string]$e,[string]$d=''){"$([Diagnostics.Stopwatch]::GetTimestamp()),$e,$($d.Replace(',',';'))"|Add-Content -Encoding ascii $events}
$screens=@([Windows.Forms.Screen]::AllScreens)
if($screens.Count-lt2){throw 'Research scenarios currently require two displays'}
$primary=$screens|Where-Object{$_.Primary}|Select-Object -First 1
$secondary=$screens|Where-Object{-not$_.Primary}|Select-Object -First 1
$edge=@('C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe','C:\Program Files\Microsoft\Edge\Application\msedge.exe')|Where-Object{Test-Path $_}|Select-Object -First 1
$browser=$null
if($Scenario-ne'manual_feature'){
 if(-not$edge){throw 'Microsoft Edge not found'}
 $fixture=(Resolve-Path (Join-Path $PSScriptRoot 'fixtures\magnifier_fixture.html')).Path
 $profile=Join-Path $run 'edge_profile';$uri=([Uri]$fixture).AbsoluteUri
 $browser=Start-Process $edge -ArgumentList @("--user-data-dir=$profile",'--no-first-run','--disable-sync','--force-renderer-accessibility',"--app=$uri") -PassThru
 Start-Sleep -Seconds 2;Ev 'fixture_started' "pid=$($browser.Id)"
}
$observer=Join-Path $PSScriptRoot 'run-observation.ps1'
$obsArgs=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$observer,'-Product',$Product,'-DurationSec',[string]$DurationSec,'-OutputDir',$run)
if($ProcessName){$obsArgs+=@('-ProcessName',$ProcessName)}
$op=Start-Process powershell.exe -ArgumentList $obsArgs -PassThru -WindowStyle Hidden
Start-Sleep -Milliseconds 900;Ev 'stimulus_begin' $Scenario
function Set-TestCursor([int]$x,[int]$y,[int]$ms=20){[Windows.Forms.Cursor]::Position=[Drawing.Point]::new($x,$y);Start-Sleep -Milliseconds $ms}
$send=New-Object -ComObject WScript.Shell
$pb=$primary.Bounds;$sb=$secondary.Bounds
switch($Scenario){
 'pointer_sweep' {
  $y=[int](($pb.Top+$pb.Bottom)/2);$l=$pb.Left+80;$r=$pb.Right-80
  for($pass=0;$pass-lt4;$pass++){for($i=0;$i-le100;$i++){$t=$i/100.0;if($pass%2){$t=1-$t};Set-TestCursor ([int]($l+($r-$l)*$t)) $y 8};Start-Sleep -Milliseconds 300}
 }
 'cross_monitor' {
  $x0=[int](($pb.Left+$pb.Right)/2);$y0=[int](($pb.Top+$pb.Bottom)/2);$x1=[int](($sb.Left+$sb.Right)/2);$y1=[int](($sb.Top+$sb.Bottom)/2)
  for($i=0;$i-le100;$i++){$t=$i/100.0;Set-TestCursor ([int]($x0+($x1-$x0)*$t)) ([int]($y0+($y1-$y0)*$t)) 12};Start-Sleep -Seconds 2
  for($i=0;$i-le100;$i++){$t=$i/100.0;Set-TestCursor ([int]($x1+($x0-$x1)*$t)) ([int]($y1+($y0-$y1)*$t)) 12}
 }
 'focus_navigation' {
  $send.AppActivate($browser.Id)|Out-Null;Start-Sleep -Milliseconds 300
  for($i=0;$i-lt14;$i++){$send.SendKeys('{TAB}');Start-Sleep -Milliseconds 220}
 }
 'caret_navigation' {
  $send.AppActivate($browser.Id)|Out-Null;Start-Sleep -Milliseconds 300;$send.SendKeys('^{HOME}');Start-Sleep -Milliseconds 400
  for($i=0;$i-lt45;$i++){$send.SendKeys('{RIGHT}');Start-Sleep -Milliseconds 35}
  $send.SendKeys('{END}');Start-Sleep -Milliseconds 500;$send.SendKeys('{HOME}');Start-Sleep -Milliseconds 500
  for($i=0;$i-lt4;$i++){$send.SendKeys('{DOWN}');Start-Sleep -Milliseconds 250};for($i=0;$i-lt3;$i++){$send.SendKeys('{UP}');Start-Sleep -Milliseconds 250}
 }
 'manual_feature' {Start-Sleep -Seconds ([Math]::Max(2,$DurationSec-3))}
}
Ev 'stimulus_end' $Scenario
$op.WaitForExit(($DurationSec+10)*1000)|Out-Null
if(-not$op.HasExited){Stop-Process -Id $op.Id -Force -ErrorAction SilentlyContinue;throw 'Observer did not exit'}
if($browser){Stop-Process -Id $browser.Id -Force -ErrorAction SilentlyContinue}
@('# Controlled research run','',"- Product: $Product","- Scenario: $Scenario","- Displays: $($screens.Count)","- Run: $run","- Observer exit: $($op.ExitCode)") -join [Environment]::NewLine | Set-Content -Encoding UTF8 (Join-Path $run 'RUN_SUMMARY.md')
if($op.ExitCode-ne0){throw "Observer failed with exit $($op.ExitCode): $run"}
Write-Output $run
