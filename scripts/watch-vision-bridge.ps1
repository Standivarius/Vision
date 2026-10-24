<#
.SYNOPSIS
    Watchdog script for Visual Repository Bridge.
    Continuously monitors the bridge /health endpoint and automatically restarts it if it goes down.

.PARAMETER IntervalSec
    Interval in seconds between health checks (default: 5).

.PARAMETER TimeoutSec
    HTTP probe timeout in seconds (default: 3).

.PARAMETER FailureThreshold
    Number of consecutive failed probes before triggering a restart (default: 2).
#>
[CmdletBinding()]
param(
    [int]$IntervalSec = 5,
    [int]$TimeoutSec = 3,
    [int]$FailureThreshold = 2
)

$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$StartScript = Join-Path $ScriptDir "start-vision-bridge.ps1"
$TunnelScript = Join-Path $ScriptDir "start-vision-tunnel.ps1"
$EnvFile = Join-Path $ProjectRoot ".env"
$LogFile = Join-Path $ProjectRoot "artifacts\bridge-watchdog.log"

# Parse port and host from .env if available
$Port = "8090"
$HostAddr = "127.0.0.1"

if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#")) {
            $parts = $line.Split("=", 2)
            if ($parts.Count -eq 2) {
                $key = $parts[0].Trim()
                $val = $parts[1].Trim()
                if ($key -ieq "PORT") { $Port = $val }
                if ($key -ieq "HOST") { $HostAddr = $val }
            }
        }
    }
}

$HealthUrl = "http://${HostAddr}:${Port}/health"

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [ConsoleColor]$Color = [ConsoleColor]::White
    )
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $formatted = "[$timestamp] [$Level] $Message"
    Write-Host $formatted -ForegroundColor $Color
    try {
        Add-Content -LiteralPath $LogFile -Value $formatted -Encoding utf8 -ErrorAction SilentlyContinue
    } catch {}
}

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "       Visual Bridge Watchdog & Auto-Restarter   " -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "Target Health URL  : $HealthUrl"
Write-Host "Check Interval     : ${IntervalSec}s"
Write-Host "Probe Timeout      : ${TimeoutSec}s"
Write-Host "Failure Threshold  : $FailureThreshold consecutive failures"
Write-Host "Log File           : $LogFile"
Write-Host "Press Ctrl+C to stop the watchdog."
Write-Host "=================================================" -ForegroundColor Cyan

$consecutiveFailures = 0
$consecutiveTunnelFailures = 0
$restartCount = 0
$tunnelRestartCount = 0
$lastHeartbeat = [DateTime]::MinValue

while ($true) {
    # 1. Local Bridge Health Check
    $isHealthy = $false
    try {
        $response = Invoke-RestMethod -Uri $HealthUrl -TimeoutSec $TimeoutSec -ErrorAction Stop
        if ($response -and $response.status -eq "ok") {
            $isHealthy = $true
        }
    } catch {
        $isHealthy = $false
    }

    if ($isHealthy) {
        if ($consecutiveFailures -gt 0) {
            Write-Log "Visual Bridge recovered and is responding normally." "INFO" Green
        }
        $consecutiveFailures = 0
    } else {
        $consecutiveFailures++
        Write-Log "Bridge health probe failed ($consecutiveFailures/$FailureThreshold) at $HealthUrl" "WARN" Yellow

        if ($consecutiveFailures -ge $FailureThreshold) {
            $restartCount++
            Write-Log "Bridge is DOWN! Triggering automatic restart (#$restartCount)..." "ALERT" Red

            # Cleanly stop any lingering process holding the port
            $connections = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
            foreach ($conn in $connections) {
                if ($conn.OwningProcess -and $conn.OwningProcess -ne $PID) {
                    Write-Log "Stopping lingering process (PID: $($conn.OwningProcess)) on port $Port..." "WARN" Yellow
                    Stop-Process -Id $conn.OwningProcess -Force -ErrorAction SilentlyContinue
                }
            }

            Start-Sleep -Milliseconds 500

            # Launch start-vision-bridge in background
            Write-Log "Spawning fresh Visual Bridge process..." "INFO" Cyan
            Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$StartScript`"" -WindowStyle Hidden

            # Wait for startup and re-probe
            Start-Sleep -Seconds 4
            $consecutiveFailures = 0
        }
    }

    # 2. ngrok Tunnel Health Check
    $isTunnelHealthy = $false
    try {
        $tunnels = (Invoke-RestMethod -Uri "http://127.0.0.1:4040/api/tunnels" -TimeoutSec $TimeoutSec -ErrorAction Stop).tunnels
        if ($tunnels -and $tunnels.Count -gt 0) {
            $isTunnelHealthy = $true
        }
    } catch {
        $isTunnelHealthy = $false
    }

    if ($isTunnelHealthy) {
        if ($consecutiveTunnelFailures -gt 0) {
            Write-Log "ngrok tunnel recovered and is responding normally." "INFO" Green
        }
        $consecutiveTunnelFailures = 0
    } else {
        $consecutiveTunnelFailures++
        Write-Log "ngrok tunnel probe failed ($consecutiveTunnelFailures/$FailureThreshold) at http://127.0.0.1:4040" "WARN" Yellow

        if ($consecutiveTunnelFailures -ge $FailureThreshold) {
            $tunnelRestartCount++
            Write-Log "ngrok tunnel is DOWN! Triggering automatic restart (#$tunnelRestartCount)..." "ALERT" Red

            Get-Process ngrok -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 500

            Write-Log "Spawning fresh ngrok tunnel process..." "INFO" Cyan
            Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$TunnelScript`"" -WindowStyle Hidden

            Start-Sleep -Seconds 3
            $consecutiveTunnelFailures = 0
        }
    }

    # Periodic heartbeat log every 60 seconds
    if ($isHealthy -and $isTunnelHealthy) {
        if (((Get-Date) - $lastHeartbeat).TotalSeconds -ge 60) {
            Write-Log "Heartbeat: Visual Bridge (port $Port) and ngrok tunnel are both UP and healthy." "OK" DarkGreen
            $lastHeartbeat = Get-Date
        }
    }

    Start-Sleep -Seconds $IntervalSec
}
