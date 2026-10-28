param(
 [switch]$Catalog,
 [switch]$List,
 [switch]$Gui,
 [switch]$GuiSmoke,
 [switch]$SelfTest,
 [ValidateSet('one-screen-temporary','screen-missing-simulation','driver-missing-simulation','blocked-policy-simulation','package-mismatch-simulation','assistant-unavailable-simulation')]
 [string]$Scenario='',
 [string]$Display='',
 [ValidateRange(15,90)][int]$Seconds=45,
 [switch]$Execute,
 [switch]$OwnerAtKeyboard,
 [switch]$LaptopScreenUsable,
 [string]$ConfirmDisplay='',
 [string]$RestoreSnapshot=''
)
# Standivarius Doxa Fault Lab. No PnP disable, driver uninstall, admin escalation,
# display topology write or online AI call occurs without explicit -Execute and gates.
# The real monitor trial is always temporary and auto-restored by a separate EXE.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$source=Join-Path $PSScriptRoot 'DoxaDisplayPath.cs'
$catalogPath=Join-Path $PSScriptRoot 'fault-catalog.json'
$build=Join-Path $root 'artifacts\fault-lab'
$exe=Join-Path $build 'DoxaDisplayPath.exe'
$compiler='C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'

function NativeExe {
 if(-not(Test-Path $compiler)){throw 'Windows .NET Framework C# compiler is required'}
 if(-not(Test-Path $build)){New-Item $build -ItemType Directory -Force|Out-Null}
 # Rebuild when the reviewed repository source changes; no external downloads.
 $mustCompile=(-not(Test-Path $exe)) -or ((Get-Item $exe).LastWriteTimeUtc -lt (Get-Item $source).LastWriteTimeUtc)
 if($mustCompile){
  & $compiler /nologo /target:exe /platform:x64 /reference:System.Windows.Forms.dll /reference:System.Xml.dll "/out:$exe" $source
  if($LASTEXITCODE -ne 0){throw 'Could not compile the local display helper'}
 }
 return $exe
}
function Get-Catalog {return (Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8|ConvertFrom-Json)}
function Perform-Simulation([string]$id){
 $map=@{
  'screen-missing-simulation'='display_missing'
  'driver-missing-simulation'='driver_missing'
  'blocked-policy-simulation'='policy_blocked'
  'package-mismatch-simulation'='package_mismatch'
  'assistant-unavailable-simulation'='support_offline'
 }
 if(-not $map.ContainsKey($id)){throw 'Unknown simulated fault'}
 $diagnostics=Join-Path (Split-Path $PSScriptRoot -Parent) 'personal-ui\Get-DoxaSetupExperience.ps1'
 $result=(& $diagnostics -Fault $map[$id] -Language en|Out-String)|ConvertFrom-Json
 if(-not [bool]$result.test_only){throw 'Simulated diagnostic failed to mark itself TEST ONLY'}
 [pscustomobject]@{
  scenario=$id;status='SIMULATED';test_only=$true
  code=[string]$result.code;message=[string]$result.message
  actions_executed=$false;driver_changed=$false;display_changed=$false
  ask_doxa_help="This is an intentional test: how would I recover from "+$id+"?"
 }
}
function Get-ActiveNames {
 Add-Type -AssemblyName System.Windows.Forms
 return @([Windows.Forms.Screen]::AllScreens|Where-Object{-not $_.Primary}|ForEach-Object{[string]$_.DeviceName})
}
function Validate-DisplayName([string]$name){
 $available=Get-ActiveNames
 if($available -notcontains $name){throw 'Select an active non-primary display from -List; never guess the Windows display number'}
}
function Run-Real([string]$name,[bool]$reallyExecute,[bool]$atKeyboard,[bool]$laptopScreen,[string]$confirmation,[int]$seconds){
 if([string]::IsNullOrWhiteSpace($name)){throw 'Choose -Display from -List first'}
 Validate-DisplayName $name
 $native=NativeExe
 if(-not $reallyExecute){
  Write-Output 'DRY_RUN_ONLY: no display settings will change'
  & $native --preflight $name
  if($LASTEXITCODE -ne 0){throw 'Windows refused safe display preflight'}
  return
 }
 if(-not($atKeyboard -and $laptopScreen)){throw 'Live tests require -OwnerAtKeyboard and -LaptopScreenUsable (visually confirmed)'}
 if($confirmation -cne $name){throw 'Repeat the exact external Windows device name in -ConfirmDisplay'}
 & $native --preflight $name
 if($LASTEXITCODE -ne 0){throw 'Windows CCD rejected proposed temporary change'}
 & $native --trial $name $seconds ('DISABLE '+$name)
 if($LASTEXITCODE -ne 0){throw 'Windows failed trial; automatic watchdog may still be armed'}
}
function Open-Gui([switch]$Smoke) {
 Add-Type -AssemblyName System.Windows.Forms
 Add-Type -AssemblyName System.Drawing
 [Windows.Forms.Application]::EnableVisualStyles()
 $native=NativeExe
 $form=New-Object Windows.Forms.Form
 $form.Text='Standivarius Doxa Fault Lab'
 $form.StartPosition='CenterScreen';$form.ClientSize=New-Object Drawing.Size(770,520)
 $form.Font=New-Object Drawing.Font('Segoe UI',10)
 $form.MinimumSize=New-Object Drawing.Size(650,470)
 $description=New-Object Windows.Forms.Label
 $description.Text='Test ONE Doxa display at a time. The laptop screen is protected; changes automatically revert.'
 $description.SetBounds(18,17,736,50);$description.AutoSize=$false
 $devices=New-Object Windows.Forms.ComboBox
 $devices.DropDownStyle='DropDownList';$devices.SetBounds(18,75,360,35)
 $devices.AccessibleName='Choose an external Windows monitor to test'
 $refresh=New-Object Windows.Forms.Button;$refresh.Text='Refresh screens';$refresh.SetBounds(395,75,155,35)
 $dry=New-Object Windows.Forms.Button;$dry.Text='Check only';$dry.SetBounds(570,75,170,35)
 $owner=New-Object Windows.Forms.CheckBox
 $owner.Text='I am at the Dell keyboard';$owner.SetBounds(18,126,360,30)
 $laptop=New-Object Windows.Forms.CheckBox
 $laptop.Text='The built-in laptop display is usable';$laptop.SetBounds(18,160,440,30)
 $seconds=New-Object Windows.Forms.NumericUpDown
 $seconds.Minimum=15;$seconds.Maximum=90;$seconds.Value=45;$seconds.SetBounds(570,159,80,29)
 $secLabel=New-Object Windows.Forms.Label;$secLabel.Text='Auto-restore seconds:';$secLabel.SetBounds(395,162,173,24)
 $run=New-Object Windows.Forms.Button
 $run.Text='Temporarily disable selected screen';$run.SetBounds(18,208,398,45)
 $run.BackColor=[Drawing.Color]::FromArgb(250,219,184)
 $guide=New-Object Windows.Forms.Label
 $guide.Text='After disabling: open Doxa Help, click Detect Doxa, ask for recovery, and observe the screen return.'
 $guide.SetBounds(18,266,723,50)
 $log=New-Object Windows.Forms.TextBox
 $log.ReadOnly=$true;$log.Multiline=$true;$log.ScrollBars='Vertical';$log.SetBounds(18,331,723,160)
 $log.AccessibleName='Lab status and rollback instructions'
 $form.Controls.AddRange(@($description,$devices,$refresh,$dry,$owner,$laptop,$seconds,$secLabel,$run,$guide,$log))
 $listScreens={
  $devices.Items.Clear()
  foreach($name in @(Get-ActiveNames)){[void]$devices.Items.Add($name)}
  if($devices.Items.Count -gt 0){$devices.SelectedIndex=0}
  $log.AppendText("External Windows screens: "+$devices.Items.Count+[Environment]::NewLine)
 }
 $refresh.Add_Click($listScreens)
 $dry.Add_Click({
  try{
   if($null -eq $devices.SelectedItem){return}
   $name=[string]$devices.SelectedItem
   $output=(& $native --preflight $name 2>&1|Out-String)
   $log.AppendText($output+[Environment]::NewLine)
  }catch{$log.AppendText("Preflight failed: "+$_.Exception.Message+[Environment]::NewLine)}
 })
 $run.Add_Click({
  try{
   if($null -eq $devices.SelectedItem){throw 'Select an external display'}
   if(-not($owner.Checked -and $laptop.Checked)){throw 'Both physical safety checks must be confirmed'}
   $name=[string]$devices.SelectedItem
   $question='Temporarily disable '+$name+' for '+$seconds.Value+' seconds? A separate process will automatically restore the saved topology. The primary laptop display stays active.'
   if([Windows.Forms.MessageBox]::Show($question,'Confirm physical display test','YesNo','Warning') -ne [Windows.Forms.DialogResult]::Yes){return}
   $log.AppendText('Preparing isolated rollback watchdog...'+[Environment]::NewLine)
   [Windows.Forms.Application]::DoEvents()
   $output=(& $native --trial $name ([int]$seconds.Value) ('DISABLE '+$name) 2>&1|Out-String)
   if($LASTEXITCODE -ne 0){throw $output}
   $log.AppendText($output+[Environment]::NewLine)
   $log.AppendText('Do not unplug the laptop or close Windows during the test. Automatic restore is armed.'+[Environment]::NewLine)
  }catch{$log.AppendText("NOT STARTED / ERROR: "+$_.Exception.Message+[Environment]::NewLine)}
 })
 & $listScreens
 if($Smoke){
  if($devices.Items.Count -lt 1){throw 'No external screen choices in the GUI'}
  $fields=@($owner,$laptop,$run,$dry,$devices,$seconds,$log)
  if(@($fields|Where-Object{$null -eq $_}).Count){throw 'Missing GUI controls'}
  $screenCount=$devices.Items.Count
  $form.Dispose()
  [pscustomobject]@{status='PASS';gui='CREATED_WITHOUT_SHOWING';screen_choices=$screenCount;live_mutations=0}|ConvertTo-Json -Compress
  return
 }
 [void]$form.ShowDialog();$form.Dispose()
}
if($Catalog -or (-not $List -and -not $Gui -and -not $GuiSmoke -and -not $SelfTest -and -not $Scenario -and -not $RestoreSnapshot)){
 Get-Catalog|ConvertTo-Json -Depth 6
 return
}
if($List){& (NativeExe) --list; if($LASTEXITCODE){throw 'Monitor listing failed'};return}
if($SelfTest){
 $native=NativeExe
 $listOutput=(& $native --list|Out-String)
 if($LASTEXITCODE -ne 0 -or $listOutput -notmatch 'ACTIVE_PATH_COUNT='){throw 'Unable to enumerate Windows displays'}
 Add-Type -AssemblyName System.Windows.Forms
 $primary=[Windows.Forms.Screen]::PrimaryScreen.DeviceName
 $savedPreference=$ErrorActionPreference
 try{
  $ErrorActionPreference='Continue'
  & $native --preflight $primary 2>$null | Out-Null
  $primaryCode=$LASTEXITCODE
 }finally{$ErrorActionPreference=$savedPreference}
 if($primaryCode -eq 0){throw 'Primary screen incorrectly passed destructive preflight'}
 $tests=@()
 foreach($name in @(Get-ActiveNames)){
  $output=(& $native --preflight $name|Out-String)
  $tests+= [pscustomobject]@{display=$name;dry_run_status=if($LASTEXITCODE -eq 0){'PASS'}else{'UNSUPPORTED_SAFE_BLOCK'}}
 }
 $sim=@('screen-missing-simulation','driver-missing-simulation','blocked-policy-simulation','package-mismatch-simulation','assistant-unavailable-simulation')
 foreach($scenario in $sim){$result=Perform-Simulation $scenario;if(!$result.test_only -or $result.display_changed){throw 'Simulated scenario escaped its guard'}}
 [pscustomobject]@{status='PASS';primary_protected=$true;external_dry_run=$tests;simulations_passed=$sim.Count;windows_mutations=0;driver_changes=0}|ConvertTo-Json -Depth 5
 return
}
if($RestoreSnapshot){
 & (NativeExe) --restore $RestoreSnapshot
 if($LASTEXITCODE){throw 'Restore was not completed; use Windows+P Extend or Display Settings'}
 return
}
if($GuiSmoke){Open-Gui -Smoke;return}
if($Gui){Open-Gui;return}
if($Scenario -eq 'one-screen-temporary'){
 Run-Real $Display ([bool]$Execute) ([bool]$OwnerAtKeyboard) ([bool]$LaptopScreenUsable) $ConfirmDisplay $Seconds
 return
}
if($Scenario){Perform-Simulation $Scenario|ConvertTo-Json -Depth 5;return}
