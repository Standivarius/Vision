param()
$ErrorActionPreference='Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class VisionUiSurfaceSmokeNativeV4 {
  [DllImport("kernel32.dll")] public static extern uint WTSGetActiveConsoleSessionId();
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string className,string windowName);
}
'@ -ErrorAction SilentlyContinue

function Wait-MainWindow([System.Diagnostics.Process]$Process,[int]$TimeoutMs=6000) {
    $deadline=(Get-Date).AddMilliseconds($TimeoutMs)
    while((Get-Date)-lt$deadline){
        $Process.Refresh()
        if($Process.HasExited){throw "Vision exited early: $($Process.ExitCode)"}
        if($Process.MainWindowHandle-ne0){return}
        Start-Sleep -Milliseconds 100
    }
    throw "Vision main window was not created within $TimeoutMs ms"
}

function Wait-UiWindow([int]$ProcessId,[string]$ClassName,[string]$Title,[int]$TimeoutMs=3500) {
    $deadline=(Get-Date).AddMilliseconds($TimeoutMs)
    while((Get-Date)-lt$deadline){
        $hwnd=[VisionUiSurfaceSmokeNativeV4]::FindWindow($ClassName,$Title)
        if($hwnd-ne[IntPtr]::Zero){
            $element=[System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
            if($element -and $element.Current.ProcessId-eq$ProcessId -and -not$element.Current.IsOffscreen){
                return $element
            }
        }
        Start-Sleep -Milliseconds 75
    }
    return $null
}

function Descendant-Names([System.Windows.Automation.AutomationElement]$Root) {
    $items=$Root.FindAll(
        [System.Windows.Automation.TreeScope]::Descendants,
        [System.Windows.Automation.Condition]::TrueCondition)
    $names=@()
    foreach($item in $items){
        $name=$item.Current.Name
        if(-not[string]::IsNullOrWhiteSpace($name)){$names+=$name}
    }
    return $names
}

function Send-HotkeyAndWaitExit([System.Diagnostics.Process]$Process,[object]$Shell,[string]$Keys,[int]$TimeoutMs=5000) {
    $Process.Refresh()
    if($Process.HasExited){return $true}
    $Shell.SendKeys($Keys)
    return $Process.WaitForExit($TimeoutMs)
}

$repo=Resolve-Path (Join-Path $PSScriptRoot '..')
$exe=Join-Path $PSScriptRoot 'build\Release\visual_app.exe'
if(-not(Test-Path $exe -PathType Leaf)){throw "Vision app not built: $exe"}
if([Diagnostics.Process]::GetCurrentProcess().SessionId-ne[VisionUiSurfaceSmokeNativeV4]::WTSGetActiveConsoleSessionId()){
    throw 'UI surface smoke requires the active console session'
}
if(@([Windows.Forms.Screen]::AllScreens).Count-lt2){throw 'UI surface smoke requires at least two active displays'}

$resolvedExe=(Resolve-Path $exe).Path
$existing=@(Get-Process visual_app -ErrorAction SilentlyContinue|Where-Object{
    try{$_.Path-eq$resolvedExe}catch{$false}
})
if($existing.Count){throw "UI surface smoke requires no existing dev Vision instance; found PID(s): $($existing.Id -join ', ')"}

$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$run=Join-Path $repo ("lab\benchmarks\integrated_app\runs\"+$stamp+"__ui_surface_smoke")
New-Item -ItemType Directory -Force -Path $run|Out-Null
$telemetry1=Join-Path $run 'first_telemetry.csv'
$telemetry2=Join-Path $run 'restart_telemetry.csv'
$duplicateTelemetry=Join-Path $run 'duplicate_telemetry.csv'
$shell=New-Object -ComObject WScript.Shell

$first=$null
$restart=$null
$forcedCleanup=$false
$duplicateExited=$false
$duplicateExit=$null
$settingsOpened=$false
$settingsHasRoles=$false
$settingsHasColour=$false
$helpOpened=$false
$helpHasCommon=$false
$firstExited=$false
$restartOpened=$false
$restartExited=$false

try {
    $first=Start-Process $exe -ArgumentList @('--zoom','2','--log',$telemetry1) -PassThru
    Wait-MainWindow $first
    Start-Sleep -Milliseconds 700

    $duplicate=Start-Process $exe -ArgumentList @('--zoom','2','--log',$duplicateTelemetry) -PassThru
    $duplicateExited=$duplicate.WaitForExit(3000)
    if($duplicateExited){$duplicateExit=$duplicate.ExitCode}
    $first.Refresh()
    if(-not$duplicateExited -or $duplicateExit-ne0 -or $first.HasExited){
        throw "Single-instance acceptance failed: duplicateExited=$duplicateExited duplicateExit=$duplicateExit firstExited=$($first.HasExited)"
    }

    $shell.SendKeys('^%s')
    $settings=Wait-UiWindow $first.Id 'VisualSettingsWindow' 'Vision Settings'
    if($settings){
        $settingsOpened=$true
        $names=Descendant-Names $settings
        $settingsHasRoles=($names -contains 'Screen roles')
        $normalisedNames=@($names|ForEach-Object{($_ -replace '[^A-Za-z]','').ToLowerInvariant()})
        $settingsHasColour=($normalisedNames -contains 'colourcontrast')
    }
    if(-not$settingsOpened -or -not$settingsHasRoles -or -not$settingsHasColour){
        throw "Vision Settings acceptance failed: opened=$settingsOpened roles=$settingsHasRoles colour=$settingsHasColour"
    }

    $shell.SendKeys('^%h')
    $help=Wait-UiWindow $first.Id 'VisualHelpWindow' 'Vision Help / Ask Vision'
    if($help){
        $helpOpened=$true
        $names=Descendant-Names $help
        $helpHasCommon=($names -contains 'Common Vision help')
    }
    if(-not$helpOpened -or -not$helpHasCommon){
        throw "Vision Help acceptance failed: opened=$helpOpened common_help=$helpHasCommon"
    }

    $firstExited=Send-HotkeyAndWaitExit $first $shell '^%q'
    if(-not$firstExited){throw 'Vision did not exit through Ctrl+Alt+Q'}

    Start-Sleep -Milliseconds 350
    $restart=Start-Process $exe -ArgumentList @('--zoom','2','--log',$telemetry2) -PassThru
    Wait-MainWindow $restart
    $restartOpened=$true
    $restartRenderDeadline=(Get-Date).AddSeconds(5)
    $restartRendered=$false
    while((Get-Date)-lt$restartRenderDeadline){
        if((Test-Path $telemetry2) -and (Select-String -Path $telemetry2 -Pattern '# event=first_render_frame' -SimpleMatch -Quiet -ErrorAction SilentlyContinue)){
            $restartRendered=$true; break
        }
        $restart.Refresh(); if($restart.HasExited){break}; Start-Sleep -Milliseconds 100
    }
    if(-not$restartRendered){throw 'Restarted Vision did not produce a rendered frame'}
    $restartExited=Send-HotkeyAndWaitExit $restart $shell '^%q'
    if(-not$restartExited){throw 'Restarted Vision did not exit through Ctrl+Alt+Q'}
}
finally {
    foreach($process in @($first,$restart)){
        if($process){
            try{
                $process.Refresh()
                if(-not$process.HasExited){
                    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
                    $forcedCleanup=$true
                }
            }catch{}
        }
    }
}

$rows1=if(Test-Path $telemetry1){@(Import-Csv $telemetry1|Where-Object{$_.frame-match'^\d+$'})}else{@()}
$rows2=@(if(Test-Path $telemetry2){ Import-Csv $telemetry2 | Where-Object { $_.frame -match '^\d+$' } })
$presentFailures=@($rows1+$rows2|Where-Object{[uint64]$_.present_hr-ne0}).Count

$pass=(
    $duplicateExited -and $duplicateExit-eq0 -and
    $settingsOpened -and $settingsHasRoles -and $settingsHasColour -and
    $helpOpened -and $helpHasCommon -and
    $firstExited -and $restartOpened -and $restartExited -and
    $rows1.Count-gt0 -and $rows2.Count-gt0 -and
    $presentFailures-eq0 -and -not$forcedCleanup
)

$analysis=[ordered]@{
    first_frames=$rows1.Count
    restart_frames=$rows2.Count
    present_failures=$presentFailures
    duplicate_exited=$duplicateExited
    duplicate_exit_code=$duplicateExit
    settings_opened=$settingsOpened
    settings_screen_roles_visible=$settingsHasRoles
    settings_colour_contrast_visible=$settingsHasColour
    help_opened=$helpOpened
    help_common_content_visible=$helpHasCommon
    first_exit_via_hotkey=$firstExited
    restart_opened=$restartOpened
    restart_exit_via_hotkey=$restartExited
    forced_cleanup=$forcedCleanup
    pass=$pass
}
$analysis|ConvertTo-Json -Depth 3|Set-Content -Encoding UTF8 (Join-Path $run 'analysis.json')

$summary=@(
    '# Vision UI surface / lifecycle smoke',
    '',
    "- First / restart frames: $($rows1.Count) / $($rows2.Count)",
    "- Present failures: $presentFailures",
    "- Duplicate launch exited 0 while first stayed alive: $($duplicateExited -and $duplicateExit-eq0)",
    "- Settings opened / Screen roles / Colour & Contrast: $settingsOpened / $settingsHasRoles / $settingsHasColour",
    "- Help opened / common content visible: $helpOpened / $helpHasCommon",
    "- First exit / restart / second exit: $firstExited / $restartOpened / $restartExited",
    "- Forced cleanup: $forcedCleanup",
    "- Pass: $pass"
)
$summary -join [Environment]::NewLine | Set-Content -Encoding UTF8 (Join-Path $run 'SUMMARY.md')
if(-not$pass){throw "UI surface smoke failed: $run"}
Write-Host "Vision UI surface smoke complete: $run"
Get-Content (Join-Path $run 'SUMMARY.md')
