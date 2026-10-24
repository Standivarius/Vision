$ErrorActionPreference='Stop'
$repo='C:\dev\Visual'
$log=Join-Path $repo 'artifacts\physical_console_pointer_test.log'
function Log([string]$s){"$(Get-Date -Format o) $s"|Add-Content -Encoding UTF8 $log}
try{
  Remove-Item $log -Force -ErrorAction SilentlyContinue
  $sessionId=[System.Diagnostics.Process]::GetCurrentProcess().SessionId
  Log "launcher_start session=$sessionId"
  Log 'query_session_before:'
  (& query session 2>&1)|ForEach-Object{Log ([string]$_)}
  Log "tscon_start session=$sessionId"
  & tscon.exe $sessionId /dest:console 2>&1 | ForEach-Object{Log ([string]$_)}
  Log "tscon_exit=$LASTEXITCODE"
  Start-Sleep -Seconds 6
  Add-Type -AssemblyName System.Windows.Forms
  $screens=@([System.Windows.Forms.Screen]::AllScreens)
  Log "screen_count_after=$($screens.Count)"
  foreach($s in $screens){Log ("screen={0};primary={1};x={2};y={3};w={4};h={5}" -f $s.DeviceName,$s.Primary,$s.Bounds.X,$s.Bounds.Y,$s.Bounds.Width,$s.Bounds.Height)}
  if($screens.Count -lt 2){throw "Physical console still exposes only $($screens.Count) display(s); aborting regression run."}
  $harness=Join-Path $repo 'lab\automation-harness\run-pointer-visibility.ps1'
  Log "harness_start=$harness"
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $harness -VideoFps 30 2>&1 | ForEach-Object{Log ([string]$_)}
  Log "harness_exit=$LASTEXITCODE"
}catch{
  Log "ERROR=$($_.Exception.Message)"
  Log $_.ScriptStackTrace
}
Log 'launcher_end'
