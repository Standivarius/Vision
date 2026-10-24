param([int]$Seconds=4)
$ErrorActionPreference='Stop'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class VisualCadenceSmokeNative {
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd,uint msg,IntPtr wParam,IntPtr lParam);
}
'@ -ErrorAction SilentlyContinue
$repo=Resolve-Path (Join-Path $PSScriptRoot '..')
$exe=Join-Path $PSScriptRoot 'build\Release\visual_app.exe'
$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$run=Join-Path $repo ("lab\benchmarks\integrated_app\runs\${stamp}__interaction_cadence_smoke")
New-Item -ItemType Directory -Force -Path $run|Out-Null
$telemetry=Join-Path $run 'visual_app_telemetry.csv'
$p=Start-Process $exe -ArgumentList @('--zoom','2','--log',$telemetry) -PassThru
$deadline=(Get-Date).AddSeconds(8)
while((Get-Date)-lt$deadline-and$p.MainWindowHandle-eq0-and-not$p.HasExited){Start-Sleep -Milliseconds 100;$p.Refresh()}
if($p.HasExited){throw "Visual exited early: $($p.ExitCode)"}
Start-Sleep -Seconds $Seconds
$p.Refresh()
if(-not$p.HasExited-and$p.MainWindowHandle-ne0){[VisualCadenceSmokeNative]::PostMessage($p.MainWindowHandle,0x0010,[IntPtr]::Zero,[IntPtr]::Zero)|Out-Null}
if(-not$p.WaitForExit(5000)){Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue;throw 'Visual did not close'}
$rows=@(Import-Csv $telemetry|Where-Object{$_.frame -match '^\d+$'})
if($rows.Count-lt2){throw "Too few telemetry rows: $($rows.Count)"}
$freq=[double][Diagnostics.Stopwatch]::Frequency
$span=([int64]$rows[-1].qpc-[int64]$rows[0].qpc)/$freq
$fps=($rows.Count-1)/$span
$gaps=@();for($i=1;$i-lt$rows.Count;$i++){$gaps+=1000.0*([int64]$rows[$i].qpc-[int64]$rows[$i-1].qpc)/$freq}
$sorted=@($gaps|Sort-Object);$p95=$sorted[[Math]::Min($sorted.Count-1,[Math]::Floor(($sorted.Count-1)*.95))]
$max=$sorted[-1]
$presentFailures=@($rows|Where-Object{[uint64]$_.present_hr-ne0}).Count
$headers=(Get-Content $telemetry -First 1).Split(',')
$required=@('pointer_age_ms','uia_snapshot_age_ms','uia_caret_present','uia_focus_present','selected_poi_age_ms','selected_left','selected_top','selected_right','selected_bottom')
$missing=@($required|Where-Object{$headers-notcontains$_})
$pass=($p.ExitCode-eq0-and$presentFailures-eq0-and$fps-ge45-and$missing.Count-eq0)
$analysis=[ordered]@{frames=$rows.Count;span_seconds=[Math]::Round($span,3);fps=[Math]::Round($fps,2);gap_p95_ms=[Math]::Round($p95,3);gap_max_ms=[Math]::Round($max,3);present_failures=$presentFailures;missing_diagnostic_columns=$missing;visual_exit=$p.ExitCode;pass=$pass}
$analysis|ConvertTo-Json -Depth 4|Out-File (Join-Path $run 'analysis.json') -Encoding utf8
@('# Interaction cadence smoke','',"- Frames: $($rows.Count)","- Span: $([Math]::Round($span,3)) s","- Effective cadence: $([Math]::Round($fps,2)) fps","- Gap p95 / max: $([Math]::Round($p95,3)) / $([Math]::Round($max,3)) ms","- Present failures: $presentFailures","- Missing diagnostic columns: $($missing -join ', ')","- Exit: $($p.ExitCode)","- Pass: $pass") -join "`r`n" | Out-File (Join-Path $run 'SUMMARY.md') -Encoding utf8
if(-not$pass){throw "Interaction cadence smoke failed: $run"}
Write-Host "Interaction cadence smoke complete: $run"
Get-Content (Join-Path $run 'SUMMARY.md')
