param(
    [ValidateRange(10,600)][int]$DurationSeconds = 20,
    [ValidateSet(2,4)][int]$Zoom = 2,
    [switch]$Record
)
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
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
$isActiveConsole = ($processSessionId -eq $activeConsoleSessionId)
if (-not $isActiveConsole) {
    throw "Physical cross-monitor validation refused: process session $processSessionId is not the active console session $activeConsoleSessionId. Disconnect RDP or launch the test in the physical console session."
}

$screens = @([System.Windows.Forms.Screen]::AllScreens)
if ($screens.Count -lt 2) {
    throw "Physical cross-monitor validation requires at least two active Windows displays; detected $($screens.Count)."
}

$primary = $screens | Where-Object { $_.Primary } | Select-Object -First 1
if (-not $primary) {
    throw 'Could not identify the Windows primary display.'
}

# The stimulus selects the monitor containing the cursor at startup. Put the cursor
# at the center of the primary/source display immediately before the scenario starts,
# making the automated physical test deterministic for the current two-monitor spike.
$centerX = $primary.Bounds.X + [int]($primary.Bounds.Width / 2)
$centerY = $primary.Bounds.Y + [int]($primary.Bounds.Height / 2)
[System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point($centerX, $centerY)

Write-Host 'Visual Spike 1 physical cross-monitor validation'
Write-Host "Process session: $processSessionId"
Write-Host "Active console session: $activeConsoleSessionId"
Write-Host "Inherited SESSIONNAME: $env:SESSIONNAME"
Write-Host "Displays detected: $($screens.Count)"
foreach ($s in $screens) {
    Write-Host ("  {0} primary={1} bounds=({2},{3}) {4}x{5}" -f $s.DeviceName,$s.Primary,$s.Bounds.X,$s.Bounds.Y,$s.Bounds.Width,$s.Bounds.Height)
}
Write-Host "Primary/source display: $($primary.DeviceName)"
Write-Host 'Expected: stimulus full-screen on the primary/source display; magnified Detail full-screen on the other display.'
Write-Host ''

$runner = Join-Path $PSScriptRoot 'run-automated.ps1'
$args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$runner,'-DurationSeconds',[string]$DurationSeconds,'-Zoom',[string]$Zoom)
if ($Record) { $args += '-Record' }

& powershell.exe @args
exit $LASTEXITCODE
