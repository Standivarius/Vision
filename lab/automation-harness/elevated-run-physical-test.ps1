$ErrorActionPreference='Stop'
$repo='C:\dev\Visual'
$log=Join-Path $repo 'artifacts\elevated_physical_test.log'
function Log([string]$s){"$(Get-Date -Format o) $s"|Add-Content -Encoding UTF8 $log}
try{
  Remove-Item $log -Force -ErrorAction SilentlyContinue
  $sid=[System.Diagnostics.Process]::GetCurrentProcess().SessionId
  Log "start elevated session=$sid"
  (& whoami /groups 2>&1)|ForEach-Object{Log ([string]$_)}
  Log "tscon session=$sid -> console"
  & tscon.exe $sid /dest:console 2>&1 | ForEach-Object{Log ([string]$_)}
  Log "tscon_exit=$LASTEXITCODE"
  if($LASTEXITCODE-ne0){throw "tscon failed with $LASTEXITCODE"}
  Start-Sleep -Seconds 6
  Add-Type -AssemblyName System.Windows.Forms
  $screens=@([System.Windows.Forms.Screen]::AllScreens)
  Log "screen_count=$($screens.Count)"
  foreach($s in $screens){Log ("screen={0};primary={1};x={2};y={3};w={4};h={5}" -f $s.DeviceName,$s.Primary,$s.Bounds.X,$s.Bounds.Y,$s.Bounds.Width,$s.Bounds.Height)}
  if($screens.Count-lt2){throw "Only $($screens.Count) physical display(s) after console transfer"}
  $h=Join-Path $repo 'lab\automation-harness\run-pointer-visibility.ps1'
  Log "run_harness=$h"
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $h -VideoFps 30 2>&1 | ForEach-Object{Log ([string]$_)}
  Log "harness_exit=$LASTEXITCODE"
}catch{
  Log "ERROR=$($_.Exception.Message)"
  Log $_.ScriptStackTrace
}
Log 'end'
