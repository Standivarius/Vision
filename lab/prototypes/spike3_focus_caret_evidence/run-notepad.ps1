param([ValidateRange(10,100)][int]$SampleMs=25)
$ErrorActionPreference='Stop'

$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$repo=Resolve-Path (Join-Path $root '..\..\..')
$probe=Join-Path $root 'build\Release\visual_spike3_probe.exe'
if(-not(Test-Path $probe)){throw "Missing probe: $probe"}

$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$run=Join-Path $repo ("lab\benchmarks\spike3_focus_caret_evidence\runs\${stamp}__notepad")
New-Item -ItemType Directory -Force -Path $run|Out-Null
$fixture=Join-Path $run 'visual_spike3_notepad_fixture.txt'
@(
 'Visual Spike 3 Notepad caret test.',
 'Second line for caret navigation and accessibility evidence.',
 'Third line keeps the test deterministic without editing user files.'
) | Set-Content -Encoding UTF8 $fixture

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Spike3Window {
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
'@ -ErrorAction SilentlyContinue

$np=Start-Process notepad.exe -ArgumentList @($fixture) -PassThru
$deadline=(Get-Date).AddSeconds(8)
$notepad=$null
while((Get-Date)-lt$deadline){
  Start-Sleep -Milliseconds 200
  $candidates=@(Get-Process -Name Notepad -ErrorAction SilentlyContinue | Where-Object {$_.MainWindowHandle -ne 0})
  if($candidates.Count){$notepad=$candidates|Sort-Object StartTime -Descending|Select-Object -First 1;break}
}
if(-not$notepad){throw 'Notepad main window not found'}
[Spike3Window]::ShowWindow($notepad.MainWindowHandle,9)|Out-Null
[Spike3Window]::SetForegroundWindow($notepad.MainWindowHandle)|Out-Null
Start-Sleep -Milliseconds 500

$probeOut=Join-Path $run 'probe_stdout.txt';$probeErr=Join-Path $run 'probe_stderr.txt'
$p=Start-Process $probe -ArgumentList @('--out',$run,'--duration-ms','9000','--sample-ms',[string]$SampleMs) -WindowStyle Hidden -RedirectStandardOutput $probeOut -RedirectStandardError $probeErr -PassThru

$w=New-Object -ComObject WScript.Shell
$sequence=@(
  @{wait=500;keys='^{HOME}'},
  @{wait=700;keys='{RIGHT 8}'},
  @{wait=700;keys='{END}'},
  @{wait=700;keys='{DOWN}'},
  @{wait=700;keys='{HOME}'},
  @{wait=700;keys='{RIGHT 15}'},
  @{wait=700;keys='{DOWN}'},
  @{wait=700;keys='{END}'},
  @{wait=700;keys='{LEFT 12}'},
  @{wait=700;keys='^{END}'},
  @{wait=700;keys='^{HOME}'}
)
foreach($s in $sequence){
  [Spike3Window]::SetForegroundWindow($notepad.MainWindowHandle)|Out-Null
  Start-Sleep -Milliseconds ([int]$s.wait)
  $w.SendKeys([string]$s.keys)
}
$p.WaitForExit();$p.Refresh()
$completed=Test-Path (Join-Path $run 'probe_completed.txt')

$manifest=[ordered]@{
 captured_at=(Get-Date).ToString('o');run_type='notepad_real_app';target_process_name='Notepad';target_pid=$notepad.Id
 fixture=$fixture;probe_completed_marker=$completed;probe_exit=$p.ExitCode;sample_ms=$SampleMs
}
$manifest|ConvertTo-Json -Depth 4|Set-Content -Encoding UTF8 (Join-Path $run 'realapp_manifest.json')

try{[Spike3Window]::SetForegroundWindow($notepad.MainWindowHandle)|Out-Null;$w.SendKeys('%{F4}')}catch{}
if(-not$completed){throw "Probe did not complete. See $probeErr"}

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'analyze-realapp.ps1') -RunDir $run -TargetProcessName 'Notepad'
if($LASTEXITCODE-ne0){throw "Analysis failed: $LASTEXITCODE"}
Write-Host "Spike 3 Notepad run complete: $run"
