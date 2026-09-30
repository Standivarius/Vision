param([ValidateRange(10,100)][int]$SampleMs=25)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$repo=Resolve-Path (Join-Path $root '..\..\..')
$probe=Join-Path $root 'build\Release\visual_spike3_probe.exe'
$chrome='C:\Program Files\Google\Chrome\Application\chrome.exe'
if(-not(Test-Path $chrome)){throw "Chrome not found: $chrome"}

$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$run=Join-Path $repo ("lab\benchmarks\spike3_focus_caret_evidence\runs\${stamp}__chrome")
New-Item -ItemType Directory -Force -Path $run|Out-Null
$html=Join-Path $run 'fixture.html';$profile=Join-Path $run 'chrome_profile'
@'
<!doctype html><meta charset="utf-8"><title>Visual Spike 3 Chrome Fixture</title>
<style>body{font:24px sans-serif;margin:40px}textarea,input,[contenteditable]{display:block;width:850px;margin:24px 0;padding:12px;font:24px sans-serif}textarea{height:180px}</style>
<textarea id="ta">Visual Chrome textarea caret baseline. Second line of text for navigation.
Third line continues the deterministic fixture.</textarea>
<input id="in" value="Visual Chrome input caret baseline">
<div id="ce" contenteditable="true">Visual contenteditable caret baseline for UI Automation testing.</div>
<script>
const ta=document.getElementById('ta'), input=document.getElementById('in'), ce=document.getElementById('ce');
function pos(el,n){el.focus(); if('selectionStart' in el) el.setSelectionRange(n,n);}
function cePos(n){ce.focus();const node=ce.firstChild;const r=document.createRange();r.setStart(node,Math.min(n,node.length));r.collapse(true);const s=getSelection();s.removeAllRanges();s.addRange(r)}
const steps=[()=>pos(ta,0),()=>pos(ta,12),()=>pos(ta,45),()=>pos(ta,ta.value.length),()=>pos(input,0),()=>pos(input,14),()=>pos(input,input.value.length),()=>cePos(0),()=>cePos(18),()=>cePos(ce.textContent.length),()=>pos(ta,20)];
let i=0;steps[0]();setInterval(()=>{i=(i+1)%steps.length;steps[i]()},700);
</script>
'@ | Set-Content -Encoding UTF8 $html
$uri=([uri]$html).AbsoluteUri

Add-Type -TypeDefinition @'
using System;using System.Runtime.InteropServices;
public static class Spike3ChromeWindow {
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h,int n);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h,out uint pid);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h,IntPtr p);
 [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
 [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a,uint b,bool attach);
 public static bool ForceForeground(IntPtr h){
   if(h==IntPtr.Zero) return false;
   var fg=GetForegroundWindow();
   uint current=GetCurrentThreadId();
   uint fgTid=fg==IntPtr.Zero?0:GetWindowThreadProcessId(fg,IntPtr.Zero);
   bool attached=false;
   if(fgTid!=0 && fgTid!=current) attached=AttachThreadInput(current,fgTid,true);
   ShowWindow(h,9);
   bool ok=SetForegroundWindow(h);
   if(attached) AttachThreadInput(current,fgTid,false);
   return ok;
 }
 public static uint ForegroundPid(){var h=GetForegroundWindow();uint pid=0;if(h!=IntPtr.Zero)GetWindowThreadProcessId(h,out pid);return pid;}
}
'@ -ErrorAction SilentlyContinue

$originalForeground=[Spike3ChromeWindow]::GetForegroundWindow()
$before=@(Get-Process chrome -ErrorAction SilentlyContinue|ForEach-Object{$_.Id})
$cp=Start-Process $chrome -ArgumentList @("--user-data-dir=$profile",'--no-first-run','--disable-default-apps',"--app=$uri") -PassThru
try {
  $deadline=(Get-Date).AddSeconds(12);$browser=$null
  while((Get-Date)-lt$deadline){
   Start-Sleep -Milliseconds 250
   $c=@(Get-Process chrome -ErrorAction SilentlyContinue|Where-Object{$_.MainWindowHandle-ne0 -and $before -notcontains $_.Id}|Sort-Object StartTime -Descending)
   if($c.Count){$browser=$c|Select-Object -First 1;break}
  }
  if(-not$browser){throw 'Chrome fixture window not found'}

  # Windows normally prevents a background process from stealing foreground focus.
  # Temporarily minimize the previous foreground window, then foreground the isolated test window.
  if($originalForeground -ne [IntPtr]::Zero -and $originalForeground -ne $browser.MainWindowHandle){
    [Spike3ChromeWindow]::ShowWindow($originalForeground,6)|Out-Null
    Start-Sleep -Milliseconds 250
  }

  $foregroundOk=$false
  for($i=0;$i-lt20;$i++){
   [Spike3ChromeWindow]::ForceForeground($browser.MainWindowHandle)|Out-Null
   Start-Sleep -Milliseconds 150
   $fgPid=[int][Spike3ChromeWindow]::ForegroundPid()
   $fgProc=Get-Process -Id $fgPid -ErrorAction SilentlyContinue
   if($fgProc -and $fgProc.ProcessName -ieq 'chrome'){$foregroundOk=$true;break}
  }
  if(-not$foregroundOk){throw "Chrome fixture never became foreground; last foreground PID=$fgPid"}
  Start-Sleep -Milliseconds 500

  $probeOut=Join-Path $run 'probe_stdout.txt';$probeErr=Join-Path $run 'probe_stderr.txt'
  $p=Start-Process $probe -ArgumentList @('--out',$run,'--duration-ms','9000','--sample-ms',[string]$SampleMs) -WindowStyle Hidden -RedirectStandardOutput $probeOut -RedirectStandardError $probeErr -PassThru
  $p.WaitForExit();$p.Refresh();$completed=Test-Path(Join-Path $run 'probe_completed.txt')
  $manifest=[ordered]@{captured_at=(Get-Date).ToString('o');run_type='chrome_local_fixture';target_process_name='chrome';browser_pid=$browser.Id;probe_completed_marker=$completed;probe_exit=$p.ExitCode;sample_ms=$SampleMs;fixture=$html}
  $manifest|ConvertTo-Json -Depth 4|Set-Content -Encoding UTF8 (Join-Path $run 'realapp_manifest.json')
  if(-not$completed){throw "Probe did not complete. See $probeErr"}
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'analyze-realapp.ps1') -RunDir $run -TargetProcessName 'chrome'
  if($LASTEXITCODE-ne0){throw "Analysis failed: $LASTEXITCODE"}
  Write-Host "Spike 3 Chrome run complete: $run"
}
finally {
  @(Get-Process chrome -ErrorAction SilentlyContinue|Where-Object{$before -notcontains $_.Id})|Stop-Process -Force -ErrorAction SilentlyContinue
  if($originalForeground -ne [IntPtr]::Zero){
    [Spike3ChromeWindow]::ShowWindow($originalForeground,9)|Out-Null
    [Spike3ChromeWindow]::ForceForeground($originalForeground)|Out-Null
  }
}
