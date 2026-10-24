# Visual Repository Bridge Startup Script
# Machine: MARIUS-DELL

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$EnvFile = Join-Path $ProjectRoot ".env"

if (-not (Test-Path $EnvFile)) {
    Write-Error "Configuration file not found: $EnvFile"
    exit 1
}

# Parse .env
Get-Content $EnvFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith("#")) {
        $parts = $line.Split("=", 2)
        if ($parts.Count -eq 2) {
            [System.Environment]::SetEnvironmentVariable($parts[0].Trim(), $parts[1].Trim(), "Process")
        }
    }
}

# Locate Node.js executable
$NodeExe = $null
if (Get-Command node -ErrorAction SilentlyContinue) {
    $NodeExe = "node"
} elseif (Test-Path "C:\Users\DELL\AppData\Local\OpenAI\Codex\runtimes\cua_node\4004642ff3fabdc7\bin\node.exe") {
    $NodeExe = "C:\Users\DELL\AppData\Local\OpenAI\Codex\runtimes\cua_node\4004642ff3fabdc7\bin\node.exe"
} else {
    Write-Error "Node.js executable could not be found."
    exit 1
}

$Port = if ($env:PORT) { $env:PORT } else { "8090" }
$HostAddr = if ($env:HOST) { $env:HOST } else { "127.0.0.1" }
$ServerScript = Join-Path $ProjectRoot "bridge\server.mjs"

# Stop any existing process on the port for a clean restart
$existingConns = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
foreach ($conn in $existingConns) {
    if ($conn.OwningProcess -and $conn.OwningProcess -ne $PID) {
        Write-Host "Stopping previous bridge process on port $Port (PID: $($conn.OwningProcess))..." -ForegroundColor Yellow
        Stop-Process -Id $conn.OwningProcess -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
    }
}

# Ensure ngrok tunnel is running
$TunnelScript = Join-Path $ScriptDir "start-vision-tunnel.ps1"
$tunnelHealthy = $false
try {
    $tunnels = (Invoke-RestMethod -Uri "http://127.0.0.1:4040/api/tunnels" -TimeoutSec 2 -ErrorAction Stop).tunnels
    if ($tunnels -and $tunnels.Count -gt 0) { $tunnelHealthy = $true }
} catch {}

if (-not $tunnelHealthy) {
    Write-Host "Starting background ngrok tunnel..." -ForegroundColor Yellow
    Get-Process ngrok -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$TunnelScript`"" -WindowStyle Hidden
}

# Ensure bridge watchdog is running
$WatchScript = Join-Path $ScriptDir "watch-vision-bridge.ps1"
$watchdogRunning = Get-CimInstance Win32_Process -Filter "Name like '%powershell%'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*watch-vision-bridge.ps1*" }
if (-not $watchdogRunning) {
    Write-Host "Starting bridge watchdog in background..." -ForegroundColor Yellow
    Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$WatchScript`"" -WindowStyle Hidden
}

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Starting Visual Repository Bridge      " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Project Root : $ProjectRoot"
Write-Host "Workspace    : $env:WORKSPACE_ROOT"
Write-Host "Local URL    : http://${HostAddr}:${Port}"
Write-Host "Public URL   : $($env:PUBLIC_NGROK_URL)"
Write-Host "OpenAPI URL  : http://${HostAddr}:${Port}/openapi_chatgpt_compact.json"
Write-Host "Auth Token   : Loaded from $EnvFile"
Write-Host "=========================================" -ForegroundColor Cyan

& $NodeExe $ServerScript
