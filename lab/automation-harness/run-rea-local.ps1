param(
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [Parameter(ValueFromRemainingArguments=$true)][string[]]$ReaArgs
)
$ErrorActionPreference='Stop'
$env:JAVA_HOME=[Environment]::GetEnvironmentVariable('JAVA_HOME','User')
$env:GHIDRA_INSTALL_DIR=[Environment]::GetEnvironmentVariable('GHIDRA_INSTALL_DIR','User')
if(-not$env:JAVA_HOME){throw 'JAVA_HOME user variable is missing'}
if(-not$env:GHIDRA_INSTALL_DIR){throw 'GHIDRA_INSTALL_DIR user variable is missing'}
$env:Path=(Join-Path $env:JAVA_HOME 'bin')+';'+$env:Path

$node=(Get-Command node.exe -ErrorAction Stop).Source
$npmRoot=(& npm.cmd root -g).Trim()
$reaScript=Join-Path $npmRoot 'rea-agents\scripts\rea.mjs'
if(-not(Test-Path $reaScript)){throw "REA CLI script not found: $reaScript"}

$tmp=$OutputPath+'.tmp.'+[guid]::NewGuid().ToString('N')
$err=$OutputPath+'.stderr.'+[guid]::NewGuid().ToString('N')+'.txt'
$args=@($reaScript)+$ReaArgs
$p=Start-Process -FilePath $node -ArgumentList $args -NoNewWindow -Wait -PassThru -RedirectStandardOutput $tmp -RedirectStandardError $err
$code=$p.ExitCode

if(Test-Path $OutputPath){Remove-Item $OutputPath -Force -ErrorAction SilentlyContinue}
Move-Item $tmp $OutputPath -Force
Write-Host ('REA_EXIT='+$code)
Write-Host ('OUTPUT='+$OutputPath)
Write-Host ('BYTES='+((Get-Item $OutputPath).Length))
if(Test-Path $err){
    Write-Host ('STDERR_BYTES='+((Get-Item $err).Length))
    if((Get-Item $err).Length -eq 0){Remove-Item $err -Force -ErrorAction SilentlyContinue}
}
exit $code
