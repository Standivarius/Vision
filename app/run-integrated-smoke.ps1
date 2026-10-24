param([ValidateRange(1,4)][int]$Zoom=2)
$ErrorActionPreference='Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class VisualSmokeNative {
  [DllImport("kernel32.dll")] public static extern uint WTSGetActiveConsoleSessionId();
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);
}
'@ -ErrorAction SilentlyContinue

$repo=Resolve-Path (Join-Path $PSScriptRoot '..')
$exe=Join-Path $PSScriptRoot 'build\Release\visual_app.exe'
if(-not(Test-Path $exe)){throw "Visual app not built: $exe"}
$processSession=[System.Diagnostics.Process]::GetCurrentProcess().SessionId
$consoleSession=[VisualSmokeNative]::WTSGetActiveConsoleSessionId()
if($processSession -ne $consoleSession){throw "Integrated physical smoke requires active console session. Process=$processSession Console=$consoleSession"}
$screens=@([System.Windows.Forms.Screen]::AllScreens)
if($screens.Count -lt 2){throw "Integrated smoke requires at least two displays; found $($screens.Count)"}
$primary=$screens|Where-Object{$_.Primary}|Select-Object -First 1
if(-not$primary){throw 'Primary display not found'}

$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$run=Join-Path $repo ("lab\benchmarks\integrated_app\runs\${stamp}__mouse_viewport_smoke")
New-Item -ItemType Directory -Force -Path $run|Out-Null
$telemetry=Join-Path $run 'visual_app_telemetry.csv'
$stdout=Join-Path $run 'stdout.txt';$stderr=Join-Path $run 'stderr.txt'

$centerX=$primary.Bounds.X+[int]($primary.Bounds.Width/2)
$centerY=$primary.Bounds.Y+[int]($primary.Bounds.Height/2)
[System.Windows.Forms.Cursor]::Position=New-Object Drawing.Point($centerX,$centerY)

$p=Start-Process -FilePath $exe -ArgumentList @('--zoom',[string]$Zoom,'--log',$telemetry) -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
$deadline=(Get-Date).AddSeconds(6)
while((Get-Date)-lt$deadline -and $p.MainWindowHandle -eq 0){Start-Sleep -Milliseconds 150;$p.Refresh()}
if($p.HasExited){throw "Visual app exited early: $($p.ExitCode)"}

$b=$primary.Bounds
$inset=80
$points=@(
  [Drawing.Point]::new($centerX,$centerY),
  [Drawing.Point]::new($b.Left+$inset,$centerY),
  [Drawing.Point]::new($b.Right-$inset-1,$centerY),
  [Drawing.Point]::new($centerX,$b.Top+$inset),
  [Drawing.Point]::new($centerX,$b.Bottom-$inset-1),
  [Drawing.Point]::new($b.Left+$inset,$b.Top+$inset),
  [Drawing.Point]::new($b.Right-$inset-1,$b.Bottom-$inset-1),
  [Drawing.Point]::new($centerX,$centerY)
)
foreach($pt in $points){[System.Windows.Forms.Cursor]::Position=$pt;Start-Sleep -Milliseconds 750}

$p.Refresh()
if(-not$p.HasExited){$w=New-Object -ComObject WScript.Shell;$w.SendKeys('^%q')}
if(-not$p.WaitForExit(5000)){Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue;throw 'Vision app did not close through Ctrl+Alt+Q'}
$p.Refresh()

$rows=@(Import-Csv $telemetry|Where-Object{$_.frame-match'^\d+$'})
if($rows.Count -eq 0){throw 'No integrated app telemetry frames'}
$presentFailures=@($rows|Where-Object{[uint64]$_.present_hr -ne 0}).Count
$holds=@($rows|Where-Object{[int]$_.viewport_action -eq 1}).Count
$pans=@($rows|Where-Object{[int]$_.viewport_action -eq 2}).Count
$jumps=@($rows|Where-Object{[int]$_.viewport_action -eq 3}).Count
$invalid=@($rows|Where-Object{[int]$_.viewport_action -eq 0}).Count
$pointerSource=@($rows|Where-Object{[int]$_.poi_source -eq 5}).Count
$locatorFrames=@($rows|Where-Object{[int]$_.locator_visible -eq 1}).Count
$pass=($rows.Count -gt 0 -and $presentFailures -eq 0 -and $invalid -eq 0 -and $pointerSource -gt 0 -and $locatorFrames -gt 0)
$summary=[ordered]@{
  captured_at=(Get-Date).ToString('o');machine=$env:COMPUTERNAME;process_session_id=$processSession;active_console_session_id=$consoleSession
  display_count=$screens.Count;primary_bounds="$($b.X),$($b.Y),$($b.Width),$($b.Height)";zoom=$Zoom
  visual_exit=$p.ExitCode;frames=$rows.Count;present_failures=$presentFailures
  viewport_hold_frames=$holds;viewport_pan_frames=$pans;viewport_jump_frames=$jumps;viewport_invalid_frames=$invalid;pointer_source_frames=$pointerSource;locator_frames=$locatorFrames;pass=$pass
}
$summary|ConvertTo-Json -Depth 4|Set-Content -Encoding UTF8 (Join-Path $run 'analysis.json')
@(
 '# Integrated Visual mouse/viewport smoke','',
 "- Visual exit: $($p.ExitCode)",
 "- Frames: $($rows.Count)",
 "- Present failures: $presentFailures",
 "- Hold / Pan / Jump / Invalid: $holds / $pans / $jumps / $invalid",
 "- Pointer-source frames: $pointerSource",
 "- Locator-visible frames: $locatorFrames",
 "- Pass: $pass",
 "- Displays: $($screens.Count)",
 "- Zoom: ${Zoom}x"
) -join "`r`n"|Set-Content -Encoding UTF8 (Join-Path $run 'SUMMARY.md')
if(-not$pass){throw "Integrated Visual mouse/viewport smoke failed. See $run"}
Write-Host "Integrated Visual smoke complete: $run"
Get-Content (Join-Path $run 'SUMMARY.md')
