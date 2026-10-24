param(
    [ValidateRange(10,600)][int]$DurationSeconds = 60,
    [ValidateSet(2,4)][int]$Zoom = 2,
    [switch]$Record,
    [switch]$NoPointer,
    [switch]$ForceSingleMonitor
)
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = (Resolve-Path (Join-Path $root '..\..\..')).Path
$buildDir = Join-Path $root 'build\Release'
$visualExe = Join-Path $buildDir 'visual_spike1_wgc_detail.exe'
$stimulusExe = Join-Path $buildDir 'visual_spike1_stimulus.exe'
if (-not (Test-Path $visualExe) -or -not (Test-Path $stimulusExe)) {
    throw "Build outputs missing. Run .\build.ps1 first."
}

$stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$runId = "${stamp}__spike1_auto"
$runDir = Join-Path $repo "lab\benchmarks\spike1_wgc_d3d11_detail\runs\$runId"
New-Item -ItemType Directory -Force -Path $runDir | Out-Null

$telemetry = Join-Path $runDir 'visual_telemetry.csv'
$scenarioLog = Join-Path $runDir 'scenario_events.jsonl'
$orchestratorLog = Join-Path $runDir 'orchestrator_events.jsonl'
$environmentPath = Join-Path $runDir 'environment.json'
$manifestPath = Join-Path $runDir 'manifest.json'
$videoPath = Join-Path $runDir 'video.mp4'
$recordLogPath = Join-Path $runDir 'ffmpeg.log'

function Get-Qpc { [System.Diagnostics.Stopwatch]::GetTimestamp() }
function Write-OrchestratorEvent([string]$Type,[string]$Detail) {
    $obj = [ordered]@{
        qpc = Get-Qpc
        utc = (Get-Date).ToUniversalTime().ToString('o')
        type = $Type
        detail = $Detail
    }
    ($obj | ConvertTo-Json -Compress) | Add-Content -Encoding utf8 $orchestratorLog
}
function Resolve-WinGetTool([string]$Name) {
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }
    $packages = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    if (Test-Path $packages) {
        $hit = Get-ChildItem -Path $packages -Filter ($Name + '.exe') -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}
function Quote-Arg([string]$Value) {
    return '"' + $Value.Replace('"','\"') + '"'
}

Add-Type -AssemblyName System.Windows.Forms
$screens = @([System.Windows.Forms.Screen]::AllScreens | ForEach-Object {
    [ordered]@{
        device_name = $_.DeviceName
        primary = $_.Primary
        bounds = [ordered]@{ x=$_.Bounds.X; y=$_.Bounds.Y; width=$_.Bounds.Width; height=$_.Bounds.Height }
        working_area = [ordered]@{ x=$_.WorkingArea.X; y=$_.WorkingArea.Y; width=$_.WorkingArea.Width; height=$_.WorkingArea.Height }
        bits_per_pixel = $_.BitsPerPixel
    }
})

$os = Get-CimInstance Win32_OperatingSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$gpus = @(Get-CimInstance Win32_VideoController | ForEach-Object {
    [ordered]@{ name=$_.Name; driver_version=$_.DriverVersion; current_horizontal_resolution=$_.CurrentHorizontalResolution; current_vertical_resolution=$_.CurrentVerticalResolution; current_refresh_rate=$_.CurrentRefreshRate }
})
$environment = [ordered]@{
    run_id = $runId
    captured_utc = (Get-Date).ToUniversalTime().ToString('o')
    machine = $env:COMPUTERNAME
    user = $env:USERNAME
    session_name = $env:SESSIONNAME
    qpc_frequency = [System.Diagnostics.Stopwatch]::Frequency
    os = [ordered]@{ caption=$os.Caption; version=$os.Version; build_number=$os.BuildNumber; architecture=$os.OSArchitecture }
    cpu = [ordered]@{ name=$cpu.Name; cores=$cpu.NumberOfCores; logical_processors=$cpu.NumberOfLogicalProcessors }
    gpu = $gpus
    screens = $screens
    parameters = [ordered]@{ duration_seconds=$DurationSeconds; zoom=$Zoom; record=[bool]$Record; move_pointer=(-not [bool]$NoPointer); force_single_monitor=[bool]$ForceSingleMonitor }
}
$environment | ConvertTo-Json -Depth 8 | Set-Content -Encoding utf8 $environmentPath
Write-OrchestratorEvent 'run_start' $runId

$ffmpeg = $null
$ffprobe = Resolve-WinGetTool 'ffprobe'
$recordProcess = $null
$recordingActive = $false
if ($Record) {
    $ffmpeg = Resolve-WinGetTool 'ffmpeg'
    if (-not $ffmpeg) {
        Write-OrchestratorEvent 'recording_unavailable' 'ffmpeg_not_found'
        Write-Warning 'Recording requested but ffmpeg was not found. Continuing without video.'
    } else {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $ffmpeg
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.Arguments = '-y -hide_banner -loglevel warning -f gdigrab -framerate 60 -draw_mouse 1 -i desktop -c:v libx264 -preset ultrafast -crf 18 -pix_fmt yuv420p ' + (Quote-Arg $videoPath)
        $recordProcess = New-Object System.Diagnostics.Process
        $recordProcess.StartInfo = $psi
        $null = $recordProcess.Start()
        $recordingActive = $true
        Write-OrchestratorEvent 'recording_started' "pid=$($recordProcess.Id);ffmpeg=$ffmpeg"
        Start-Sleep -Milliseconds 700
    }
}

$visualArgs = @('--zoom',[string]$Zoom,'--log',$telemetry)
if ($ForceSingleMonitor -or $screens.Count -eq 1) { $visualArgs += '--single-monitor' }
$visual = Start-Process -FilePath $visualExe -ArgumentList $visualArgs -PassThru
Write-OrchestratorEvent 'visual_started' "pid=$($visual.Id)"
Start-Sleep -Milliseconds 1200
if ($visual.HasExited) {
    Write-OrchestratorEvent 'visual_early_exit' "exit=$($visual.ExitCode)"
    throw "Visual exited before scenario start with code $($visual.ExitCode)"
}

$stimulusArgs = @('--duration',[string]$DurationSeconds,'--log',$scenarioLog)
if ($NoPointer) { $stimulusArgs += '--no-pointer' }
$stimulus = Start-Process -FilePath $stimulusExe -ArgumentList $stimulusArgs -PassThru
Write-OrchestratorEvent 'stimulus_started' "pid=$($stimulus.Id)"
$stimulus.WaitForExit()
Write-OrchestratorEvent 'stimulus_exited' "exit=$($stimulus.ExitCode)"

$visualClosed = $false
if (-not $visual.HasExited) {
    $visualClosed = $visual.CloseMainWindow()
    Write-OrchestratorEvent 'visual_close_requested' "CloseMainWindow=$visualClosed"
    if (-not $visual.WaitForExit(5000)) {
        Write-OrchestratorEvent 'visual_force_stop' 'timeout_waiting_for_clean_exit'
        Stop-Process -Id $visual.Id -Force
        $visual.WaitForExit()
    }
}
$visualExit = $visual.ExitCode
Write-OrchestratorEvent 'visual_exited' "exit=$visualExit"

if ($recordingActive -and $recordProcess -and -not $recordProcess.HasExited) {
    try {
        $recordProcess.StandardInput.WriteLine('q')
        $recordProcess.StandardInput.Flush()
        if (-not $recordProcess.WaitForExit(5000)) {
            Write-OrchestratorEvent 'recording_force_stop' 'ffmpeg_did_not_exit_after_q'
            $recordProcess.Kill()
            $recordProcess.WaitForExit()
        }
    } finally {
        $stderr = $recordProcess.StandardError.ReadToEnd()
        $stdout = $recordProcess.StandardOutput.ReadToEnd()
        [IO.File]::WriteAllText($recordLogPath,($stdout + "`r`n" + $stderr),[Text.UTF8Encoding]::new($false))
    }
    Write-OrchestratorEvent 'recording_stopped' "exit=$($recordProcess.ExitCode);video_exists=$(Test-Path $videoPath)"
}

$videoInfo = $null
if ((Test-Path $videoPath) -and $ffprobe) {
    try {
        $probeJson = & $ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height,r_frame_rate,avg_frame_rate,duration,nb_frames -of json $videoPath 2>$null
        if ($LASTEXITCODE -eq 0) { $videoInfo = ($probeJson -join "`n") | ConvertFrom-Json }
    } catch { }
}

$manifest = [ordered]@{
    run_id = $runId
    completed_utc = (Get-Date).ToUniversalTime().ToString('o')
    duration_seconds = $DurationSeconds
    zoom = $Zoom
    screen_count = $screens.Count
    mode_requested = if ($ForceSingleMonitor -or $screens.Count -eq 1) { 'single_monitor_development' } else { 'cross_monitor_validation' }
    visual_exit_code = $visualExit
    stimulus_exit_code = $stimulus.ExitCode
    recording_requested = [bool]$Record
    recording_created = (Test-Path $videoPath)
    recording_probe = $videoInfo
    files = [ordered]@{
        environment = 'environment.json'
        orchestrator_events = 'orchestrator_events.jsonl'
        scenario_events = 'scenario_events.jsonl'
        visual_telemetry = 'visual_telemetry.csv'
        video = if (Test-Path $videoPath) { 'video.mp4' } else { $null }
        ffmpeg_log = if (Test-Path $recordLogPath) { 'ffmpeg.log' } else { $null }
    }
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -Encoding utf8 $manifestPath
Write-OrchestratorEvent 'run_complete' "visual_exit=$visualExit stimulus_exit=$($stimulus.ExitCode)"

Write-Host "Run complete: $runDir"
Write-Host "Visual exit: $visualExit"
Write-Host "Stimulus exit: $($stimulus.ExitCode)"
Write-Host "Telemetry: $telemetry"
Write-Host "Scenario: $scenarioLog"
if (Test-Path $videoPath) { Write-Host "Video: $videoPath" }

$analyzer = Join-Path $root 'analyze-run.ps1'
if ((Test-Path $analyzer) -and (Test-Path $telemetry)) {
    Write-Host ''
    Write-Host '=== Analysis ==='
    & $analyzer -RunDir $runDir | Tee-Object -FilePath (Join-Path $runDir 'analysis_console.txt')
}

if ($visualExit -ne 0 -or $stimulus.ExitCode -ne 0) { exit 1 }
exit 0
