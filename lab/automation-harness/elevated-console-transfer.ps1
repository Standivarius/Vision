$ErrorActionPreference='Continue'
$log='C:\dev\Visual\artifacts\elevated_console_transfer.log'
function Log([string]$s){"$(Get-Date -Format o) $s"|Add-Content -Encoding UTF8 $log}
Remove-Item $log -Force -ErrorAction SilentlyContinue
Log "start user=$env:USERNAME session=$([System.Diagnostics.Process]::GetCurrentProcess().SessionId)"
try{(& whoami /groups 2>&1)|ForEach-Object{Log ([string]$_)}}catch{}
try{
  & tscon.exe 1 /dest:console 2>&1 | ForEach-Object{Log ([string]$_)}
  Log "tscon_exit=$LASTEXITCODE"
}catch{Log "tscon_exception=$($_.Exception.Message)"}
Start-Sleep -Seconds 3
try{(& query session 2>&1)|ForEach-Object{Log ([string]$_)}}catch{}
Log 'end'
