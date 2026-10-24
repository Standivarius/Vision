<#
.SYNOPSIS
    Vision Test Farm runner entrypoint for PowerShell operators.

.DESCRIPTION
    Wraps the Python-based Test Farm CLI (v0.1) providing list, dry-run,
    run, safe-smoke, aggregate, and swa-suite commands.

.EXAMPLE
    .\run-farm.ps1 -DryRun
    .\run-farm.ps1 -SafeSmoke
    .\run-farm.ps1 -SwaSuite
    .\run-farm.ps1 -Scenario unit_ctest
#>
param(
    [switch]$List,
    [switch]$DryRun,
    [switch]$SafeSmoke,
    [switch]$SwaSuite,
    [string]$Scenario = '',
    [string]$Pack = '',
    [string]$Tags = '',
    [string]$Category = '',
    [string]$RunsDir = '',
    [string]$OutDir = ''
)

$ErrorActionPreference = 'Stop'
$harnessDir = $PSScriptRoot
$cliPy = Join-Path $harnessDir 'tf_cli.py'

$python = 'python.exe'
$pyCmd = Get-Command python.exe -ErrorAction SilentlyContinue
if($pyCmd){$python = $pyCmd.Source}

$argsList = @()

if ($List) {
    $argsList += 'list'
} elseif ($DryRun) {
    $argsList += 'dry-run'
    if ($Pack) { $argsList += @('--pack', $Pack) }
    if ($Tags) { $argsList += @('--tags', $Tags) }
    if ($Category) { $argsList += @('--category', $Category) }
    if ($Scenario) { $argsList += @('--scenario', $Scenario) }
} elseif ($SafeSmoke) {
    $argsList += 'safe-smoke'
} elseif ($SwaSuite) {
    $argsList += 'swa-suite'
} elseif ($RunsDir) {
    $argsList += @('aggregate', '--runs-dir', $RunsDir)
    if ($OutDir) { $argsList += @('--out-dir', $OutDir) }
} else {
    $argsList += 'run'
    if ($Pack) { $argsList += @('--pack', $Pack) }
    if ($Tags) { $argsList += @('--tags', $Tags) }
    if ($Category) { $argsList += @('--category', $Category) }
    if ($Scenario) { $argsList += @('--scenario', $Scenario) }
    if ($OutDir) { $argsList += @('--out-dir', $OutDir) }
}

& $python $cliPy @argsList
exit $LASTEXITCODE
