# A03 guarded Office switch with independent frame acceptance and strict caret exclusion veto.
# Create new evidence only. No credential/elevation, no existing user content.
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
Set-Location $root
$runner=Join-Path $PSScriptRoot 'A04-RunOfficeEdit4xVisualCapture.ps1'
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
# Additional negative-only veto: a Word caret must actually remain inside
# the magnified viewport. The telemetry crop can reject, never prove, PASS.
$strictScorer=Join-Path $PSScriptRoot 'A03-QualifyOfficeSwitchCaret.py'
$strict=@(& python.exe $strictScorer $dest 2>&1)
$strictExit=$LASTEXITCODE
Write-Output ($strict|Out-String)
if($strictExit -ne 0){exit 3}
$editingScorer=Join-Path $PSScriptRoot 'A04-QualifyOfficeEditing.py'
$editingResult=@(& python.exe $editingScorer $dest 2>&1)
$editingExit=$LASTEXITCODE
Write-Output ($editingResult|Out-String)
if($editingExit -ne 0){exit 3}
exit 0
