# Read-only fault lab acceptance; never invokes --trial or real topology changes.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$entry=Join-Path $PSScriptRoot 'Invoke-DoxaFaultLab.ps1'
$catalog=Get-Content (Join-Path $PSScriptRoot 'fault-catalog.json') -Raw -Encoding UTF8|ConvertFrom-Json
$ids=@($catalog.scenarios|ForEach-Object{$_.id})
if($ids.Count -ne 8 -or @($ids|Select-Object -Unique).Count -ne 8){throw 'Fault catalog missing or repeated scenario IDs'}
$check=(& $entry -SelfTest|Out-String)|ConvertFrom-Json
if($check.status -ne 'PASS' -or -not $check.primary_protected -or $check.simulations_passed -ne 5 -or $check.windows_mutations -ne 0){throw 'Fault lab guard failed'}
$source=Get-Content (Join-Path $PSScriptRoot 'DoxaDisplayPath.cs') -Raw -Encoding UTF8
if($source -notmatch 'SDC_USE_DATABASE_CURRENT=0x0F' -or $source -notmatch 'Thread.Sleep\(seconds\*1000\)' -or
   $source -notmatch 'Process.Start\(process\)' -or $source -notmatch 'SDC_USE_SUPPLIED_DISPLAY_CONFIG'){
 throw 'Independent rollback path or CCD flag is missing'
}
if($source -match 'Disable-PnpDevice|pnputil.exe|devcon.exe|Remove-PnpDevice'){throw 'Test utility must not edit the display driver'}
$native=Join-Path (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path 'artifacts\fault-lab') 'DoxaDisplayPath.exe'
$backup=(& $native --snapshot-test|Out-String).Trim()
if($LASTEXITCODE -ne 0 -or $backup -notmatch '^PASS:'){throw 'CCD backup serialization failed'}
$guiCheck=(& $entry -GuiSmoke|Out-String)|ConvertFrom-Json
if($guiCheck.status -ne 'PASS' -or $guiCheck.live_mutations -ne 0){throw 'Headless fault lab GUI smoke failed'}
Add-Type -AssemblyName System.Windows.Forms
$before=@([Windows.Forms.Screen]::AllScreens).Count
$list=(& $native --list|Out-String)
$after=@([Windows.Forms.Screen]::AllScreens).Count
if($before -ne $after){throw 'Read-only test changed display count'}
if($list -notmatch 'primary=True internal=True'){throw 'Internal laptop path not protected'}
[pscustomobject]@{
 status='PASS'
 catalog_items=$ids.Count
 simulated_faults=$check.simulations_passed
 external_displays_validated=@($check.external_dry_run).Count
 primary_protected=$check.primary_protected
 snapshot_serialization='PASS'
 gui_smoke='PASS'
 auto_rollback_design='INSPECTED_NOT_PHYSICALLY_EXECUTED'
 visible_displays_unchanged=($before -eq $after)
 mutations=0
}|ConvertTo-Json -Depth 5
