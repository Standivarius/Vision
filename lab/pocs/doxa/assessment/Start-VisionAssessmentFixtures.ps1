# Disposable colour-coded source windows for Vision POC A independent frame tests.
# Does not drive input, install drivers, move user windows or access documents.
param([switch]$Probe)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
. (Join-Path $PSScriptRoot '..\VisionFocusWorkspaceProbe.ps1')
[void][VisionPocFocusWin32]::SetProcessDpiAwarenessContext([IntPtr](-4))
$external=@([Windows.Forms.Screen]::AllScreens | Where-Object{-not $_.Primary} |
 Sort-Object {$_.Bounds.Left})
$primary=@([Windows.Forms.Screen]::AllScreens|Where-Object{$_.Primary})
if($external.Count -ne 3 -or $primary.Count -ne 1){
 [pscustomobject]@{status='BLOCKED_TOPOLOGY';monitors=@([Windows.Forms.Screen]::AllScreens).Count;required='Laptop plus three external'}|ConvertTo-Json
 exit 4
}
$middle=$external[1].Bounds
if(Test-VisionLockScreenOccludesPoint ([int]($middle.Left+$middle.Width/2)) ([int]($middle.Top+$middle.Height/2))){
 '{"status":"BLOCKED_LOCK_SCREEN"}'
 exit 4
}
if($Probe){
 [pscustomobject]@{status='READY';left=$external[0].DeviceName;centre=$external[1].DeviceName;right=$external[2].DeviceName;documents_touched=$false}|ConvertTo-Json
 exit 0
}
$script:forms=@()
$script:labels=@()
$script:palettes=@(
 @([Drawing.Color]::FromArgb(248,214,32),[Drawing.Color]::FromArgb(243,201,51),[Drawing.Color]::FromArgb(238,188,72),[Drawing.Color]::FromArgb(232,175,91)),
 @([Drawing.Color]::FromArgb(35,190,130),[Drawing.Color]::FromArgb(50,181,143),[Drawing.Color]::FromArgb(65,172,156),[Drawing.Color]::FromArgb(80,163,169))
)
function Create-Fixture([string]$role,$bounds,[int]$idx){
 $f=New-Object Windows.Forms.Form
 $f.Text='VISION ASSESSMENT DISPOSABLE '+$role
 $f.FormBorderStyle='Sizable'
 $f.StartPosition='Manual'
 $f.ShowInTaskbar=$true
 $f.TopMost=$false
 $f.Location=New-Object Drawing.Point(($bounds.Left+80),($bounds.Top+80))
 $f.Size=New-Object Drawing.Size(($bounds.Width-160),($bounds.Height-160))
 $f.BackColor=$script:palettes[$idx][0]
 $label=New-Object Windows.Forms.Label
 $label.Text="$role | FIXTURE | 0"
 $label.Font=New-Object Drawing.Font('Segoe UI',48,[Drawing.FontStyle]::Bold)
 $label.AutoSize=$true
 $label.ForeColor=[Drawing.Color]::Black
 $label.BackColor=[Drawing.Color]::Transparent
 $label.Location=New-Object Drawing.Point(50,75)
 $f.Controls.Add($label)
 $note=New-Object Windows.Forms.Label
 $note.Text='Non-confidential source marker. Switch source using the existing Vision POC A controller. Close LEFT to finish.'
 $note.Font=New-Object Drawing.Font('Segoe UI',16)
 $note.AutoSize=$true
 $note.Location=New-Object Drawing.Point(55,220)
 $note.BackColor=[Drawing.Color]::Transparent
 $f.Controls.Add($note)
 $script:forms+=,$f
 $script:labels+=,$label
}
Create-Fixture 'LEFT' $external[0].Bounds 0
Create-Fixture 'RIGHT' $external[2].Bounds 1
$script:frame=0
$timer=New-Object Windows.Forms.Timer
$timer.Interval=850
$timer.Add_Tick({
 $script:frame++
 $shade=$script:frame % 4
 for($k=0;$k -lt 2;$k++){
  if(-not $script:forms[$k].IsDisposed){
   $script:forms[$k].BackColor=$script:palettes[$k][$shade]
   $source=if($k -eq 0){'LEFT'}else{'RIGHT'}
   $script:labels[$k].Text="$source | FIXTURE | $script:frame"
  }
 }
})
try{
 $script:forms[1].Show()
 $timer.Start()
 [Windows.Forms.Application]::Run($script:forms[0])
}finally{
 $timer.Stop()
 $timer.Dispose()
 foreach($f in $script:forms){if(-not $f.IsDisposed){$f.Close()};$f.Dispose()}
}
'ASSESSMENT_FIXTURES_EXITED'

