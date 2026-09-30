param(
    [int]$Source = -1,
    [int]$Dest = -1,
    [ValidateSet(2,4)][int]$Zoom = 2
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = Resolve-Path (Join-Path $root '..\..\..')
$exe = Join-Path $root 'build\Release\visual_spike1_wgc_detail.exe'
if (-not (Test-Path $exe)) { throw "Spike executable not found. Run build.ps1 first: $exe" }

$benchmarkDir = Join-Path $repo 'lab\benchmarks\spike1_wgc_d3d11_detail'
New-Item -ItemType Directory -Force -Path $benchmarkDir | Out-Null
$stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$log = Join-Path $benchmarkDir ("${stamp}__telemetry.csv")

$args = @('--zoom', [string]$Zoom, '--log', $log)
if ($Source -ge 0) { $args += @('--source', [string]$Source) }
if ($Dest -ge 0) { $args += @('--dest', [string]$Dest) }

Write-Host "Launching Visual Spike 1"
Write-Host "Executable: $exe"
Write-Host "Telemetry:  $log"
Write-Host "Source:     $(if($Source -ge 0){$Source}else{'auto/primary'})"
Write-Host "Destination:$(if($Dest -ge 0){$Dest}else{'auto/first non-primary'})"
Write-Host "Zoom:       ${Zoom}x"
Write-Host "Controls:   2 / 4 change zoom, Esc exits"

$p = Start-Process -FilePath $exe -ArgumentList $args -PassThru -Wait
Write-Host "Exit code: $($p.ExitCode)"
exit $p.ExitCode
