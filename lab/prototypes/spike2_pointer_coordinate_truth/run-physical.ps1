param(
    [switch]$NoPointerMove,
    [ValidateRange(1,600)][int]$ObserveSeconds = 15,
    [ValidateRange(1,1000)][int]$SampleMs = 16
)
$ErrorActionPreference='Stop'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class VisualSessionProbe {
    [DllImport("kernel32.dll")]
    public static extern uint WTSGetActiveConsoleSessionId();
}
'@ -ErrorAction SilentlyContinue

$processSessionId = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
$activeConsoleSessionId = [VisualSessionProbe]::WTSGetActiveConsoleSessionId()
if ($processSessionId -ne $activeConsoleSessionId) {
    throw "Spike 2 physical validation refused: process session $processSessionId is not the active console session $activeConsoleSessionId. Disconnect RDP or launch the test in the physical console session."
}

$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$repo=Resolve-Path (Join-Path $root '..\..\..')
$exe=Join-Path $root 'build\Release\visual_spike2_coordinate_truth.exe'
if (-not (Test-Path $exe)) { throw "Spike 2 executable not found. Build first: $exe" }

$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$run=Join-Path $repo ("lab\benchmarks\spike2_pointer_coordinate_truth\runs\${stamp}__spike2_coordinate_truth")
New-Item -ItemType Directory -Force -Path $run | Out-Null

Write-Host 'Visual Spike 2 — pointer and coordinate truth'
Write-Host "Process session: $processSessionId"
Write-Host "Active console session: $activeConsoleSessionId"
Write-Host "Inherited SESSIONNAME: $env:SESSIONNAME"
Write-Host "Output: $run"
if ($NoPointerMove) {
    Write-Host 'Observation-only mode: the tool will NOT move the pointer.'
    & $exe --no-pointer-move --observe-seconds $ObserveSeconds --sample-ms $SampleMs --out $run
} else {
    Write-Warning 'The deterministic scenario WILL CONTROL THE REAL WINDOWS POINTER for roughly 10 seconds. Do not try to use the mouse while it runs.'
    & $exe --sample-ms $SampleMs --out $run
}
$code=$LASTEXITCODE
if ($code -ne 0) { throw "Spike 2 executable failed: $code" }

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'analyze-run.ps1') -RunDir $run
if ($LASTEXITCODE -ne 0) { throw "Spike 2 analysis failed: $LASTEXITCODE" }

Write-Host ''
Write-Host "Spike 2 run complete: $run"
