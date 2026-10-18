# A03 one-command guarded physical Office-switch capture + independent PASS/FAIL.
# Create new evidence only. No credential/elevation, no existing user content.
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
Set-Location $root
$runner=Join-Path $PSScriptRoot 'A03-RunOfficeSwitch4xVisualCapture.ps1'
$scorer=Join-Path $PSScriptRoot 'A03-AnalyzeOfficeSwitch.py'
$existing=@(Get-Process WINWORD,EXCEL,visual_app -ErrorAction SilentlyContinue)
if($existing.Count){throw 'BLOCKED: Word, Excel or Vision already running'}
$raw=@(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner 2>&1)
$exitCode=$LASTEXITCODE
$lines=($raw|Out-String).Trim()
if($exitCode -ne 0){Write-Output $lines;throw ('CAPTURE_BLOCKED_OR_FAILED exit '+$exitCode)}
$captured=$lines|ConvertFrom-Json
if($captured.status -ne 'CAPTURED_NOT_YET_SCORED' -or -not $captured.run_directory){
  throw 'Capture did not provide a unique evidence run directory'
}
$dest=[IO.Path]::GetFullPath([string]$captured.run_directory)
$allowed=[IO.Path]::GetFullPath((Join-Path $root 'artifacts\vision-poc-a-graphics-20261017'))+[IO.Path]::DirectorySeparatorChar
if(-not $dest.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase)){throw 'Unexpected evidence path'}
$assessed=@(& python.exe $scorer $dest 2>&1)
$scoreExit=$LASTEXITCODE
Write-Output ($assessed|Out-String)
if($scoreExit -ne 0){exit 3}
exit 0
