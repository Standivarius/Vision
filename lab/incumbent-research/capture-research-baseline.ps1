param([string]$OutputPath='')
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
if(-not $OutputPath){$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss';$OutputPath=Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')) "lab\benchmarks\incumbent_research\runs\${stamp}__machine_baseline.json"}
$repo=Resolve-Path (Join-Path $PSScriptRoot '..\..')
$screens=@([Windows.Forms.Screen]::AllScreens)
$screenRows=@($screens|ForEach-Object{[ordered]@{device=$_.DeviceName;primary=$_.Primary;x=$_.Bounds.X;y=$_.Bounds.Y;width=$_.Bounds.Width;height=$_.Bounds.Height}})
function AppInfo([string]$Path){if(Test-Path $Path){$i=Get-Item $Path;return [ordered]@{path=$Path;file_version=$i.VersionInfo.FileVersion;product_version=$i.VersionInfo.ProductVersion}};return $null}
$uninstall=@(Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue|Where-Object{$_.DisplayName -match 'ZoomText|SuperNova|Dolphin'}|ForEach-Object{[ordered]@{name=$_.DisplayName;version=$_.DisplayVersion;publisher=$_.Publisher;install_location=$_.InstallLocation}})
$os=Get-CimInstance Win32_OperatingSystem;$cs=Get-CimInstance Win32_ComputerSystem;$cpu=Get-CimInstance Win32_Processor|Select-Object -First 1;$gpu=@(Get-CimInstance Win32_VideoController|ForEach-Object{[ordered]@{name=$_.Name;driver_version=$_.DriverVersion;adapter_ram=$_.AdapterRAM}})
$vision=AppInfo (Join-Path $repo 'app\build\Release\visual_app.exe')
$edge=AppInfo 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe';if(-not$edge){$edge=AppInfo 'C:\Program Files\Microsoft\Edge\Application\msedge.exe'}
$word=AppInfo 'C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE';$excel=AppInfo 'C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE'
$obj=[ordered]@{captured_at=(Get-Date).ToString('o');machine=$env:COMPUTERNAME;os=[ordered]@{caption=$os.Caption;version=$os.Version;build=$os.BuildNumber};cpu=$cpu.Name;ram_bytes=[int64]$cs.TotalPhysicalMemory;gpus=$gpu;displays=$screenRows;vision=$vision;edge=$edge;word=$word;excel=$excel;incumbent_installs=$uninstall}
New-Item -ItemType Directory -Force (Split-Path $OutputPath -Parent)|Out-Null
$obj|ConvertTo-Json -Depth 8|Set-Content -Encoding UTF8 $OutputPath
Write-Output $OutputPath
