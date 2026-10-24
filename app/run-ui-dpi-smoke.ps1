param()
$ErrorActionPreference='Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class VisionUiDpiSmokeNative {
  [DllImport("kernel32.dll")] public static extern uint WTSGetActiveConsoleSessionId();
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string className,string windowName);
  [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr hwnd);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hwnd, IntPtr insertAfter, int x, int y, int cx, int cy, uint flags);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left,Top,Right,Bottom; }
}
"@ -ErrorAction SilentlyContinue

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

function Wait-Window([int]$ProcessId,[string]$Class,[string]$Title,[int]$TimeoutMs=4000) {
    $deadline=(Get-Date).AddMilliseconds($TimeoutMs)
    while((Get-Date)-lt$deadline){
        $hwnd=[VisionUiDpiSmokeNative]::FindWindow($Class,$Title)
        if($hwnd-ne[IntPtr]::Zero){
            $element=[System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
            if($element -and $element.Current.ProcessId-eq$ProcessId -and -not$element.Current.IsOffscreen){
                return [pscustomobject]@{Hwnd=$hwnd;Element=$element}
            }
        }
        Start-Sleep -Milliseconds 75
    }
    return $null
}

function Window-State([IntPtr]$Hwnd,[string]$Label) {
    $r=New-Object VisionUiDpiSmokeNative+RECT
    if(-not[VisionUiDpiSmokeNative]::GetWindowRect($Hwnd,[ref]$r)){throw "GetWindowRect failed for $Label"}
    [pscustomobject]@{
        label=$Label
        dpi=[int][VisionUiDpiSmokeNative]::GetDpiForWindow($Hwnd)
        left=$r.Left; top=$r.Top
        width=$r.Right-$r.Left; height=$r.Bottom-$r.Top
    }
}

function Move-ToScreen([IntPtr]$Hwnd,[System.Windows.Forms.Screen]$Screen,[string]$Label) {
    $before=Window-State $Hwnd "$Label-before"
    $x=$Screen.Bounds.X + [math]::Max(30,[int](($Screen.Bounds.Width-$before.width)/2))
    $y=$Screen.Bounds.Y + [math]::Max(30,[int](($Screen.Bounds.Height-$before.height)/2))
    if(-not[VisionUiDpiSmokeNative]::SetWindowPos($Hwnd,[IntPtr]::Zero,$x,$y,$before.width,$before.height,0x0014)){
        throw "SetWindowPos failed for $Label"
    }
    Start-Sleep -Milliseconds 900
    return Window-State $Hwnd $Label
}

function Names-ForWindow([IntPtr]$Hwnd) {
    $Root=[System.Windows.Automation.AutomationElement]::FromHandle($Hwnd)
    if(-not$Root){return @()}
    $items=$Root.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition)
    $names=@()
    foreach($item in $items){
        try{
            $n=$item.Current.Name
            if(-not[string]::IsNullOrWhiteSpace($n)){$names+=$n}
        }catch{}
    }
    return $names
}

function Contains-Name([IntPtr]$Hwnd,[string]$Name) {
    $Root=[System.Windows.Automation.AutomationElement]::FromHandle($Hwnd)
    if(-not$Root){return $false}
    $items=$Root.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition)
    foreach($item in $items){ if($item.Current.Name -eq $Name){return $true} }
    return $false
}

$repo=Resolve-Path (Join-Path $PSScriptRoot '..')
$exe=Join-Path $PSScriptRoot 'build\Release\visual_app.exe'
if(-not(Test-Path $exe -PathType Leaf)){throw "Vision app not built: $exe"}
if([Diagnostics.Process]::GetCurrentProcess().SessionId-ne[VisionUiDpiSmokeNative]::WTSGetActiveConsoleSessionId()){
    throw 'UI DPI smoke requires the active console session'
}
$screens=@([Windows.Forms.Screen]::AllScreens)
if($screens.Count-lt2){throw 'UI DPI smoke requires at least two active displays'}

$resolvedExe=(Resolve-Path $exe).Path
$existing=@(Get-Process visual_app -ErrorAction SilentlyContinue|Where-Object{try{$_.Path-eq$resolvedExe}catch{$false}})
if($existing.Count){throw "UI DPI smoke requires no existing dev Vision instance; found PID(s): $($existing.Id -join ', ')"}

$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$run=Join-Path $repo ("lab\benchmarks\integrated_app\runs\"+$stamp+"__ui_dpi_smoke")
New-Item -ItemType Directory -Force -Path $run|Out-Null
$telemetry=Join-Path $run 'telemetry.csv'
$shell=New-Object -ComObject WScript.Shell
$app=$null
$forced=$false

$screenInfo=@()
foreach($screen in $screens){
    $screenInfo += [pscustomobject]@{
        device=$screen.DeviceName
        x=$screen.Bounds.X; y=$screen.Bounds.Y
        width=$screen.Bounds.Width; height=$screen.Bounds.Height
        primary=$screen.Primary
    }
}

try{
    $app=Start-Process $exe -ArgumentList @('--zoom','2','--log',$telemetry) -PassThru
    Wait-MainWindow $app
    Start-Sleep -Milliseconds 700

    $shell.SendKeys('^%s')
    $settings=Wait-Window $app.Id 'VisualSettingsWindow' 'Vision Settings'
    if(-not$settings){throw 'Vision Settings did not open'}

    $settingsStates=@()
    foreach($screen in $screens){
        $settingsStates += Move-ToScreen $settings.Hwnd $screen ("settings-"+$screen.DeviceName)
    }
    $settingsNames=@(Names-ForWindow $settings.Hwnd)
    $settingsNormalised=@($settingsNames | ForEach-Object {($_ -replace '[^A-Za-z]','').ToLowerInvariant()})
    $settingsHealthy=($settingsNames -contains 'Screen roles') -and ($settingsNormalised -contains 'colourcontrast')
    if(-not$settingsHealthy){
        Write-Host '=== SETTINGS STATES ==='
        $settingsStates | Format-Table -AutoSize | Out-String -Width 180 | Write-Host
        Write-Host '=== SETTINGS UIA NAMES AFTER MOVES ==='
        $settingsNames | Sort-Object -Unique | ForEach-Object { Write-Host $_ }
        throw 'Settings lost expected accessible controls after DPI moves'
    }

    $shell.SendKeys('^%h')
    $help=Wait-Window $app.Id 'VisualHelpWindow' 'Vision Help / Ask Vision'
    if(-not$help){throw 'Vision Help did not open'}

    $helpStates=@()
    foreach($screen in $screens){
        $helpStates += Move-ToScreen $help.Hwnd $screen ("help-"+$screen.DeviceName)
    }
    $helpHealthy=Contains-Name $help.Hwnd 'Common Vision help'
    if(-not$helpHealthy){throw 'Help lost expected accessible content after DPI moves'}

    $settingsDpis=@($settingsStates|Select-Object -ExpandProperty dpi -Unique)
    $helpDpis=@($helpStates|Select-Object -ExpandProperty dpi -Unique)
    $mixedDpiObserved=($settingsDpis.Count-ge2 -and $helpDpis.Count-ge2)
    if(-not$mixedDpiObserved){
        throw "Expected mixed-DPI transition not observed. Settings=$($settingsDpis -join ',') Help=$($helpDpis -join ',')"
    }

    $app.Refresh()
    if($app.HasExited){throw "Vision exited during DPI smoke: $($app.ExitCode)"}

    $shell.SendKeys('^%q')
    $exited=$app.WaitForExit(5000)
    if(-not$exited){throw 'Vision did not exit through Ctrl+Alt+Q'}

    $analysis=[ordered]@{
        pass=$true
        screens=$screenInfo
        settings=$settingsStates
        settings_distinct_dpi=$settingsDpis
        settings_healthy=$settingsHealthy
        help=$helpStates
        help_distinct_dpi=$helpDpis
        help_healthy=$helpHealthy
        forced_cleanup=$forced
    }
    $analysis|ConvertTo-Json -Depth 5|Set-Content -Encoding UTF8 (Join-Path $run 'analysis.json')

    $summary=@(
        '# Vision mixed-DPI UI smoke','',
        "- Displays: $($screens.Count)",
        "- Settings DPI values observed: $($settingsDpis -join ', ')",
        "- Help DPI values observed: $($helpDpis -join ', ')",
        "- Settings controls remained accessible: $settingsHealthy",
        "- Help content remained accessible: $helpHealthy",
        "- Pass: True"
    )
    $summary -join [Environment]::NewLine | Set-Content -Encoding UTF8 (Join-Path $run 'SUMMARY.md')
}
finally{
    if($app){
        try{
            $app.Refresh()
            if(-not$app.HasExited){
                Stop-Process -Id $app.Id -Force -ErrorAction SilentlyContinue
                $forced=$true
            }
        }catch{}
    }
}
Write-Host "Vision UI DPI smoke complete: $run"
Get-Content (Join-Path $run 'SUMMARY.md')
