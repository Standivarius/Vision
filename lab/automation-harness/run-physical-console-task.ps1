$ErrorActionPreference='Stop'
$repo='C:\dev\Visual'
$log=Join-Path $repo 'artifacts\pointer_visibility_task.log'
Remove-Item $log -Force -ErrorAction SilentlyContinue
function Log([string]$s){"$(Get-Date -Format o) $s"|Add-Content -Encoding UTF8 $log}
try{
  Log "task_start session=$([System.Diagnostics.Process]::GetCurrentProcess().SessionId) user=$env:USERNAME"
  $sessionText=@(& query session 2>&1)
  $sessionText|ForEach-Object{Log ([string]$_)}
  $current=$sessionText|Where-Object{$_ -match '^>'}|Select-Object -First 1
  if($current -and $current -match '^>console\s+'){
    Log 'already_on_console=true'
  } else {
    $sid=[System.Diagnostics.Process]::GetCurrentProcess().SessionId
    Log "tscon_start session=$sid"
    & "$env:SystemRoot\System32\tscon.exe" $sid /dest:console 2>&1|ForEach-Object{Log ([string]$_)}
    Log "tscon_exit=$LASTEXITCODE"
    if($LASTEXITCODE-ne0){throw "tscon failed with $LASTEXITCODE"}
    Start-Sleep -Seconds 5
  }

  $buildScript=Join-Path $repo 'app\build.ps1'
  $mainSource=Join-Path $repo 'app\src\main.cpp'
  $visualExe=Join-Path $repo 'app\build\Release\visual_app.exe'
  $buildRequired=(-not(Test-Path $visualExe))
  if(-not$buildRequired-and(Test-Path $mainSource)){
    $buildRequired=(Get-Item $mainSource).LastWriteTimeUtc -gt (Get-Item $visualExe).LastWriteTimeUtc
  }
  Log "build_required=$buildRequired"
  if($buildRequired){
    Log "build_start=$buildScript"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $buildScript -Configuration Release 2>&1|ForEach-Object{Log ([string]$_)}
    Log "build_exit=$LASTEXITCODE"
    if($LASTEXITCODE-ne0){throw "Visual Release build/tests failed with $LASTEXITCODE"}
    if(-not(Test-Path $visualExe)){throw "Visual executable missing after successful build: $visualExe"}
    Log "build_complete exe_utc=$((Get-Item $visualExe).LastWriteTimeUtc.ToString('o'))"
  }

  Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class PhysicalConsoleNative {
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr value);
}
'@
  try{[void][PhysicalConsoleNative]::SetProcessDpiAwarenessContext([IntPtr](-4))}catch{}
  Add-Type -AssemblyName System.Windows.Forms
  $screens=@([System.Windows.Forms.Screen]::AllScreens)
  Log "display_count=$($screens.Count)"
  foreach($s in $screens){Log ("display={0};primary={1};x={2};y={3};w={4};h={5}" -f $s.DeviceName,$s.Primary,$s.Bounds.X,$s.Bounds.Y,$s.Bounds.Width,$s.Bounds.Height)}
  if($screens.Count-lt2){throw "Need two physical displays; found $($screens.Count)."}

  $h=Join-Path $repo 'lab\automation-harness\run-pointer-visibility.ps1'
  Log "harness_start=$h"
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $h -VideoFps 30 -SkipFfmpegDownload 2>&1|ForEach-Object{Log ([string]$_)}
  Log "harness_exit=$LASTEXITCODE"
  if($LASTEXITCODE-ne0){throw "Pointer visibility harness failed with $LASTEXITCODE"}
}catch{Log "ERROR=$($_.Exception.Message)";Log $_.ScriptStackTrace;exit 1}
Log 'task_end'
