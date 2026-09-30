$ErrorActionPreference='Stop'
$taskName='VisualPhysicalConsoleRegression'
$runner='C:\dev\Visual\lab\automation-harness\run-physical-console-task.ps1'
if(-not (Test-Path $runner)){throw "Runner not found: $runner"}

$identity=[Security.Principal.WindowsIdentity]::GetCurrent()
$principal=New-Object Security.Principal.WindowsPrincipal($identity)
if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
    throw 'Run this installer from an elevated PowerShell window (Run as administrator).'
}

$action=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$runner`""
$user="$env:USERDOMAIN\$env:USERNAME"
$taskPrincipal=New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
$settings=New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
Register-ScheduledTask -TaskName $taskName -Action $action -Principal $taskPrincipal -Settings $settings -Force | Out-Null
Write-Host "Installed scheduled task: $taskName"
Write-Host "User: $user"
Write-Host "RunLevel: Highest"
Write-Host "Action: powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner"
Write-Host 'Future test trigger: Start-ScheduledTask -TaskName VisualPhysicalConsoleRegression'
