param(
    [switch]$SkipInstalledProductCheck
)
$ErrorActionPreference='Stop'

Add-Type -AssemblyName System.Windows.Forms

$repo=Resolve-Path (Join-Path $PSScriptRoot '..')
$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$run=Join-Path $repo ("lab\benchmarks\integrated_app\runs\${stamp}__two_screen_acceptance")
New-Item -ItemType Directory -Force -Path $run|Out-Null

$screens=@([System.Windows.Forms.Screen]::AllScreens)
if($screens.Count-lt2){throw "Two-screen acceptance requires at least two active displays; found $($screens.Count)"}

$devExe=Join-Path $PSScriptRoot 'build\Release\visual_app.exe'
if(-not(Test-Path $devExe -PathType Leaf)){throw "Release Vision executable not found: $devExe"}
$installedRoot=Join-Path $env:LOCALAPPDATA 'Standivarius.Visual'
$installedExe=Join-Path $installedRoot 'current\visual_app.exe'
$installedSq=Join-Path $installedRoot 'current\sq.version'
$installedUpdate=Join-Path $installedRoot 'Update.exe'
$settingsPath=Join-Path $env:LOCALAPPDATA 'Standivarius\Visual\settings.ini'
$settingsBackup=Join-Path $run 'settings.before.ini'
$settingsExisted=Test-Path $settingsPath -PathType Leaf
$settingsHashBefore=$null
if($settingsExisted){
    Copy-Item $settingsPath $settingsBackup -Force
    $settingsHashBefore=(Get-FileHash $settingsPath -Algorithm SHA256).Hash
}

$results=@()
$failure=$null
$settingsRestored=$false
$installedInfo=$null
$roleInfo=$null

function Add-StepResult([string]$Name,[bool]$Pass,[double]$Seconds,[string]$Evidence,[string]$Error='') {
    $script:results += [pscustomobject]@{name=$Name;pass=$Pass;seconds=[math]::Round($Seconds,2);evidence=$Evidence;error=$Error}
}

function Run-Step([string]$Name,[scriptblock]$Action) {
    Write-Host "=== ACCEPTANCE: $Name ==="
    $sw=[Diagnostics.Stopwatch]::StartNew()
    try {
        $evidence=& $Action 2>&1
        $sw.Stop()
        $text=($evidence|ForEach-Object{[string]$_}) -join [Environment]::NewLine
        if($text){$text|Set-Content -Encoding UTF8 (Join-Path $run (($Name -replace '[^A-Za-z0-9_-]','_')+'.log'))}
        Add-StepResult $Name $true $sw.Elapsed.TotalSeconds $text
        if($text){Write-Host $text}
    } catch {
        $sw.Stop()
        $message=$_.Exception.Message
        Add-StepResult $Name $false $sw.Elapsed.TotalSeconds '' $message
        throw
    }
}

function Read-IniValue([string]$Path,[string]$Section,[string]$Key) {
    if(-not(Test-Path $Path)){return $null}
    $current=''
    foreach($line in Get-Content $Path){
        $trim=$line.Trim()
        if($trim -match '^\[(.+)\]$'){$current=$Matches[1];continue}
        if($current-eq$Section -and $trim -match '^([^=]+)=(.*)$'){
            if($Matches[1].Trim()-eq$Key){return $Matches[2].Trim()}
        }
    }
    return $null
}

function Stop-KnownVisionProcesses {
    $known=@()
    try{$known+=(Resolve-Path $devExe).Path}catch{}
    try{if(Test-Path $installedExe){$known+=(Resolve-Path $installedExe).Path}}catch{}
    Get-Process visual_app -ErrorAction SilentlyContinue|ForEach-Object{
        try{
            if($known -contains $_.Path){Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue}
        }catch{}
    }
}

try {
    Stop-KnownVisionProcesses

    if(-not$SkipInstalledProductCheck){
        Run-Step 'installed_product_start' {
            if(-not(Test-Path $installedExe -PathType Leaf)){throw "Installed Vision executable missing: $installedExe"}
            if(-not(Test-Path $installedSq -PathType Leaf)){throw "Installed sq.version missing: $installedSq"}
            if(-not(Test-Path $installedUpdate -PathType Leaf)){throw "Installed Update.exe missing: $installedUpdate"}
            $regPath='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Standivarius.Visual'
            if(-not(Test-Path $regPath)){throw 'Installed uninstall registry entry is missing'}
            $reg=Get-ItemProperty $regPath
            $version=(Get-Item $installedExe).VersionInfo.ProductVersion
            [xml]$sq=Get-Content -Raw $installedSq
            $meta=$sq.package.metadata
            if($meta.id-ne'Standivarius.Visual' -or $meta.mainExe-ne'visual_app.exe' -or $meta.channel-ne'alpha'){
                throw "Installed Velopack identity mismatch: id=$($meta.id) mainExe=$($meta.mainExe) channel=$($meta.channel)"
            }
            $telemetry=Join-Path $run 'installed_visual_telemetry.csv'
            $p=Start-Process $installedExe -ArgumentList @('--log',$telemetry) -PassThru
            $deadline=(Get-Date).AddSeconds(8)
            while((Get-Date)-lt$deadline-and$p.MainWindowHandle-eq0){Start-Sleep -Milliseconds 100;$p.Refresh()}
            if($p.HasExited){throw "Installed Vision exited early: $($p.ExitCode)"}
            if($p.MainWindowHandle-eq0){Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue;throw 'Installed Vision did not create its interactive window'}
            Start-Sleep -Milliseconds 800
            $p.Refresh()
            if($p.HasExited){throw "Installed Vision exited during the start-observation window: $($p.ExitCode)"}
            $telemetryPresent=Test-Path $telemetry -PathType Leaf
            $rows=@()
            $presentFailures=$null
            if($telemetryPresent){
                $rows=@(Import-Csv $telemetry|Where-Object{$_.frame-match'^\d+$'})
                $presentFailures=@($rows|Where-Object{[uint64]$_.present_hr-ne0}).Count
                if($presentFailures-ne0){Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue;throw "Installed Vision recorded $presentFailures Present failures"}
            }
            Stop-Process -Id $p.Id -Force -ErrorAction Stop
            $p.WaitForExit(3000)|Out-Null
            $script:installedInfo=[ordered]@{
                version=$version
                package_id=$meta.id
                main_exe=$meta.mainExe
                channel=$meta.channel
                display_name=$reg.DisplayName
                display_version=$reg.DisplayVersion
                install_location=$reg.InstallLocation
                telemetry_present=$telemetryPresent
                frames=$rows.Count
                present_failures=$presentFailures
                cleanup='force_stop_after_start_evidence'
            }
            "Installed version=$version; package=$($meta.id); normal start=True; telemetry_present=$telemetryPresent; frames=$($rows.Count); Present failures=$presentFailures; cleanup=force-stop after start evidence; registry=$($reg.DisplayName)"
        }
    }

    Run-Step 'settings_roles_colour_state' {
        if(-not(Test-Path $settingsPath)){throw "Vision settings file missing: $settingsPath"}
        $context=Read-IniValue $settingsPath 'Displays' 'Context'
        $detail=Read-IniValue $settingsPath 'Displays' 'Detail'
        $reference=Read-IniValue $settingsPath 'Displays' 'Reference'
        $mode=Read-IniValue $settingsPath 'Appearance' 'Mode'
        if([string]::IsNullOrWhiteSpace($context)){throw 'Context display role is empty'}
        if([string]::IsNullOrWhiteSpace($detail)){throw 'Detail display role is empty'}
        if($context-eq$detail){throw 'Context and Detail roles resolve to the same display'}
        $modeInt=0
        if(-not[int]::TryParse($mode,[ref]$modeInt)-or$modeInt-lt0-or$modeInt-gt3){throw "Appearance Mode '$mode' is invalid"}
        $script:roleInfo=[ordered]@{context=$context;detail=$detail;reference=$reference;appearance_mode=$modeInt}
        "Context=$context; Detail=$detail; Reference=$reference; AppearanceMode=$modeInt"
    }

    Run-Step 'release_build_and_ctests' {
        & (Join-Path $PSScriptRoot 'build.ps1') -Configuration Release -Version 0.1.0-alpha.12 -OfflineDependencies
        if($LASTEXITCODE-ne0){throw "Release build/CTest failed with exit code $LASTEXITCODE"}
    }

    Run-Step 'settings_and_help_tests' {
        foreach($test in @('visual_settings_model_tests.exe','visual_settings_store_tests.exe','visual_help_catalog_tests.exe')){
            $testPath=Join-Path $PSScriptRoot ('build\Release\'+$test)
            if(-not(Test-Path $testPath -PathType Leaf)){throw "Test executable missing: $testPath"}
            & $testPath
            if($LASTEXITCODE-ne0){throw "$test failed with exit code $LASTEXITCODE"}
        }
    }

    Run-Step 'ui_duplicate_help_restart' {
        & (Join-Path $PSScriptRoot 'run-ui-surface-smoke.ps1')
    }

    Run-Step 'zoom_tracking_hotkeys' {
        & (Join-Path $PSScriptRoot 'run-hotkey-smoke.ps1')
    }

    Run-Step 'one_x_exact_return' {
        & (Join-Path $PSScriptRoot 'run-return-smoke.ps1')
    }

    Run-Step 'live_locator_render' {
        $before=Get-Date
        & (Join-Path $PSScriptRoot 'run-integrated-smoke.ps1') -Zoom 2
        if($LASTEXITCODE-ne0){throw "Integrated smoke failed with exit code $LASTEXITCODE"}
        $evidence=Get-ChildItem (Join-Path $repo 'lab\benchmarks\integrated_app\runs') -Directory |
            Where-Object{$_.Name -like '*__mouse_viewport_smoke' -and $_.LastWriteTime -ge $before.AddSeconds(-2)} |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if(-not$evidence){throw 'Integrated smoke evidence directory was not found'}
        $analysis=Get-Content -Raw (Join-Path $evidence.FullName 'analysis.json')|ConvertFrom-Json
        $telemetry=Join-Path $evidence.FullName 'visual_app_telemetry.csv'
        $rows=@(Import-Csv $telemetry|Where-Object{$_.frame-match'^\d+$'})
        $locatorFrames=@($rows|Where-Object{[int]$_.locator_visible-eq1}).Count
        if([int]$analysis.present_failures-ne0){throw "Integrated smoke recorded $($analysis.present_failures) Present failures"}
        if([int]$analysis.viewport_invalid_frames-ne0){throw "Integrated smoke recorded $($analysis.viewport_invalid_frames) invalid viewport frames"}
        if([int]$analysis.pointer_source_frames-lt1){throw 'Integrated smoke recorded no pointer-source frames'}
        if($locatorFrames-lt1){throw 'Integrated smoke recorded no visible View Locator frames'}
        "Evidence=$($evidence.FullName); pointer frames=$($analysis.pointer_source_frames); locator frames=$locatorFrames/$($rows.Count); Present failures=$($analysis.present_failures)"
    }
} catch {
    $failure=$_
} finally {
    Stop-KnownVisionProcesses
    try {
        if($settingsExisted){
            Copy-Item $settingsBackup $settingsPath -Force
            $afterHash=(Get-FileHash $settingsPath -Algorithm SHA256).Hash
            $settingsRestored=($afterHash-eq$settingsHashBefore)
        } else {
            if(Test-Path $settingsPath){Remove-Item $settingsPath -Force}
            $settingsRestored=(-not(Test-Path $settingsPath))
        }
    } catch {
        $settingsRestored=$false
        if(-not$failure){$failure=$_}
    }
}

$passed=@($results|Where-Object{$_.pass}).Count
$failed=@($results|Where-Object{-not$_.pass}).Count
$overall=($null-eq$failure -and $failed-eq0 -and $settingsRestored)
$analysis=[ordered]@{
    captured_at=(Get-Date).ToString('o')
    machine=[Environment]::MachineName
    display_count=$screens.Count
    installed_product_check_skipped=[bool]$SkipInstalledProductCheck
    installed_product=$installedInfo
    roles_and_colour=$roleInfo
    settings_existed_before=$settingsExisted
    settings_hash_before=$settingsHashBefore
    settings_restored=$settingsRestored
    steps=@($results)
    passed_steps=$passed
    failed_steps=$failed
    pass=$overall
    failure=$(if($failure){[string]$failure.Exception.Message}else{$null})
}
$analysis|ConvertTo-Json -Depth 7|Set-Content -Encoding UTF8 (Join-Path $run 'analysis.json')

$lines=New-Object System.Collections.Generic.List[string]
$lines.Add('# Vision two-screen acceptance suite')|Out-Null
$lines.Add('')|Out-Null
$lines.Add("- Machine: $([Environment]::MachineName)")|Out-Null
$lines.Add("- Active displays: $($screens.Count)")|Out-Null
$lines.Add("- Settings restored exactly: $settingsRestored")|Out-Null
$lines.Add("- Passed / failed steps: $passed / $failed")|Out-Null
$lines.Add('')|Out-Null
$lines.Add('| Step | Result | Seconds |')|Out-Null
$lines.Add('|---|---:|---:|')|Out-Null
foreach($item in $results){$lines.Add("| $($item.name) | $(if($item.pass){'PASS'}else{'FAIL'}) | $($item.seconds) |")|Out-Null}
$lines.Add('')|Out-Null
$lines.Add("- Overall pass: $overall")|Out-Null
if($failure){$lines.Add("- Failure: $($failure.Exception.Message)")|Out-Null}
$lines -join [Environment]::NewLine | Set-Content -Encoding UTF8 (Join-Path $run 'SUMMARY.md')

Write-Host "Two-screen acceptance complete: $run"
Get-Content (Join-Path $run 'SUMMARY.md')
if(-not$overall){throw "Two-screen acceptance failed: $run"}
