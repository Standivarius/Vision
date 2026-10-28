# Standivarius Doxa Setup Preview.12 - task-based one-window interface.
# This file reuses real diagnostics, hardware policy and assistant handlers
# from Start-DoxaSetup.ps1; it never changes display topology or drivers.
$red=[Drawing.Color]::FromArgb(165,27,51)
$ink=[Drawing.Color]::FromArgb(24,32,50)
$muted=[Drawing.Color]::FromArgb(92,101,117)
$line=[Drawing.Color]::FromArgb(217,224,231)
$white=[Drawing.Color]::White
$green=[Drawing.Color]::FromArgb(20,146,80)
$form.Controls.Clear()
$form.BackColor=$white
$form.ClientSize=New-Object Drawing.Size(1060,610)
$form.MinimumSize=New-Object Drawing.Size(745,520)
$form.AutoScroll=$true
$form.Text='Standivarius | Doxa Setup - TEST preview.12'
function UXLabel([string]$t,[int]$x,[int]$y,[int]$w,[int]$h,[float]$pt=10,[bool]$bold=$false){
 $c=New-Object Windows.Forms.Label;$c.Text=$t;$c.SetBounds($x,$y,$w,$h)
 $c.ForeColor=$ink
 $c.Font=New-Object Drawing.Font('Segoe UI',$pt,$(if($bold){[Drawing.FontStyle]::Bold}else{[Drawing.FontStyle]::Regular}))
 return $c
}
function UXButton([string]$t,[int]$x,[int]$y,[int]$w,[int]$h){
 $b=New-Object Windows.Forms.Button;$b.Text=$t;$b.SetBounds($x,$y,$w,$h)
 $b.FlatStyle='Flat';$b.FlatAppearance.BorderColor=$line;$b.FlatAppearance.BorderSize=1
 $b.BackColor=$white;$b.ForeColor=$ink;$b.Cursor='Hand'
 return $b
}
# Brand and product are intentionally two distinct typographic levels.
$logo=UXLabel 'standivarius' 22 12 242 42 22 $true
$logo.ForeColor=$red;$form.Controls.Add($logo)
$logoFile=Join-Path $PSScriptRoot 'assets\standivarius-official-logo.png'
if(Test-Path -LiteralPath $logoFile){
 $logo.Visible=$false
 $logoPicture=New-Object Windows.Forms.PictureBox
 $st=New-Object IO.MemoryStream(,[IO.File]::ReadAllBytes($logoFile))
 $img=[Drawing.Image]::FromStream($st);$logoPicture.Image=New-Object Drawing.Bitmap($img)
 $img.Dispose();$st.Dispose()
 $logoPicture.SizeMode='Zoom';$logoPicture.SetBounds(22,13,235,36)
 $logoPicture.AccessibleName='Standivarius official logo'
 $form.Controls.Add($logoPicture)
}
$form.Controls.Add((UXLabel '|' 265 17 17 37 20))
$productName=UXLabel 'Doxa' 288 9 112 47 27 $true
$form.Controls.Add($productName)
$productQualifier=UXLabel 'Setup' 399 25 118 30 13
$productQualifier.ForeColor=$muted;$form.Controls.Add($productQualifier)
$languageChoice.SetBounds(894,22,145,30);$languageChoice.TabIndex=0
$form.Controls.Add($languageChoice)

# Three task areas, entirely aligned with LEFT workspace. Doxa Help is persistent.
$tabs=@((UXButton 'Detect Doxa' 19 72 213 48),(UXButton 'Set up screens' 236 72 213 48),(UXButton 'Install signed driver' 453 72 213 48))
$form.Controls.AddRange($tabs)
$workspace=New-Object Windows.Forms.Panel
$workspace.SetBounds(19,119,663,478)
$workspace.BackColor=$white
$workspace.Add_Paint({
 param($s,$e)
 $p=New-Object Drawing.Pen ([Drawing.Color]::FromArgb(165,27,51)),1.4
 try{$e.Graphics.DrawRectangle($p,1,1,$s.Width-3,$s.Height-3)}finally{$p.Dispose()}
})
$workspace.AccessibleName='Current Doxa setup task'
$form.Controls.Add($workspace)
$main=New-Object Windows.Forms.Panel;$main.SetBounds(10,10,643,452)
$workspace.Controls.Add($main)
$sideHolder=New-Object Windows.Forms.Panel
$sideHolder.SetBounds(699,119,341,478)
$sideHolder.BorderStyle='FixedSingle'
$sideHolder.BackColor=$white
$sideHolder.AccessibleName='Doxa help chatbot, always available'
$form.Controls.Add($sideHolder)

# Detection: connection comes FIRST; physical Doxa connection must precede verification.
$detect=New-Object Windows.Forms.Panel;$detect.Dock='Fill';$main.Controls.Add($detect)
$detect.Controls.Add((UXLabel 'Connect Doxa' 11 3 420 33 17 $true))
$detect.Controls.Add((UXLabel 'Rear of the central Doxa screen:' 11 38 397 26 10))
$detect.Controls.Add((UXLabel 'POWER  -  upper USB-C socket' 14 69 405 29 11 $true))
$detect.Controls.Add((UXLabel 'DATA  -  lower USB-C socket' 14 106 405 29 11 $true))
# Rounded rectangular USB-C female receptacles, with cavity and internal tongue.
$ports=New-Object Windows.Forms.Panel;$ports.SetBounds(422,11,211,138)
$ports.AccessibleName='Rear view, central Doxa panel: upper oval rectangular USB-C female is power, lower USB-C female is data'
$ports.Add_Paint({
 param($s,$e)
 $g=$e.Graphics;$g.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
 $body=New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(72,79,90))
 $hole=New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(15,19,25))
 $steel=New-Object Drawing.Pen ([Drawing.Color]::FromArgb(182,190,197)),2.5
 $tongue=New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(140,144,150))
 $whiteText=New-Object Drawing.SolidBrush ([Drawing.Color]::White)
 $font=New-Object Drawing.Font('Segoe UI',8,[Drawing.FontStyle]::Bold)
 try{
  $g.FillRectangle($body,10,4,192,130)
  foreach($y in @(32,86)){
   # Actual USB-C socket silhouette is a capsule, not a circular hole.
   $shape=New-Object Drawing.Drawing2D.GraphicsPath
   try{
    $shape.AddArc(74,$y,14,16,90,180)
    $shape.AddArc(104,$y,14,16,270,180)
    $shape.CloseFigure()
    $g.FillPath($hole,$shape);$g.DrawPath($steel,$shape)
    $g.FillRectangle($tongue,82,$y+6,27,4)
   }finally{$shape.Dispose()}
  }
  $g.DrawString('P O W E R',$font,$whiteText,15,33)
  $g.DrawString('D A T A',$font,$whiteText,17,88)
 }finally{foreach($r in @($body,$hole,$steel,$tongue,$whiteText,$font)){$r.Dispose()}}
})
$detect.Controls.Add($ports)
$detect.Controls.Add((UXLabel 'Check the three screens' 11 155 392 33 16 $true))
$connectionBadge.SetBounds(421,160,209,24)
$detect.Controls.Add($connectionBadge)
# Decorative screen positions, but checks come EXCLUSIVELY from live PnP identities.
$script:doxaScreenChecks=@($false,$false,$false)
$screenDiagram=New-Object Windows.Forms.Panel
$screenDiagram.SetBounds(8,188,627,145)
$screenDiagram.BackColor=[Drawing.Color]::FromArgb(249,250,252)
$screenDiagram.AccessibleName='Illustration: Screens 2, 3, 4 above laptop Screen 1. A green tick means Windows identified that Doxa PnP monitor, not verified Extend mode.'
$screenDiagram.Add_Paint({
 param($s,$e)
 $g=$e.Graphics;$g.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
 $displayPen=New-Object Drawing.Pen ([Drawing.Color]::FromArgb(57,63,71)),2.6
 $fill=New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(238,243,247))
 $font=New-Object Drawing.Font('Segoe UI',11,[Drawing.FontStyle]::Bold)
 $small=New-Object Drawing.Font('Segoe UI',8)
 $txt=New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(24,32,50))
 $good=New-Object Drawing.Pen ([Drawing.Color]::FromArgb(20,146,80)),3.5
 $none=New-Object Drawing.Pen ([Drawing.Color]::FromArgb(158,164,172)),2
 try{
  for($i=0;$i -lt 3;$i++){
   $x=11+($i*209)
   $g.FillRectangle($fill,$x,8,195,73);$g.DrawRectangle($displayPen,$x,8,195,73)
   $g.DrawString((T ('Screen '+($i+2)) ('Ecran '+($i+2))),$font,$txt,$x+39,30)
   $checked=[bool]$script:doxaScreenChecks[$i]
   $p=if($checked){$good}else{$none}
   if($checked){
    $g.DrawLines($p,[Drawing.PointF[]]@([Drawing.PointF]::new([float]($x+153),[float]44),[Drawing.PointF]::new([float]($x+160),[float]50),[Drawing.PointF]::new([float]($x+173),[float]34)))
   }else{$g.DrawEllipse($p,$x+152,35,19,19)}
  }
  $g.FillRectangle($fill,241,96,147,40);$g.DrawRectangle($displayPen,241,96,147,40)
  $g.DrawString((T 'Laptop 1' 'Laptop 1'),$small,$txt,289,109)
 }finally{foreach($r in @($displayPen,$fill,$font,$small,$txt,$good,$none)){$r.Dispose()}}
})
$detect.Controls.Add($screenDiagram)
$screenCaption=UXLabel 'Green ticks = Windows sees each Doxa monitor identity; this does not confirm Extend mode.' 11 337 630 26 8
$screenCaption.ForeColor=$muted;$detect.Controls.Add($screenCaption)
# Read-only hardware status from the existing diagnostic engine.
$rows[0].SetBounds(12,363,614,20)
$rows[1].SetBounds(12,384,614,19)
$rows[2].Visible=$false
foreach($v in @($rows[0],$rows[1])){$v.Font=New-Object Drawing.Font('Segoe UI',9);$detect.Controls.Add($v)}
$stateLabel.SetBounds(12,405,410,35);$stateLabel.Font=New-Object Drawing.Font('Segoe UI',9)
$detect.Controls.Add($stateLabel)
$check.SetBounds(445,404,176,39)
$check.BackColor=$red;$check.ForeColor=$white
$detect.Controls.Add($check)
# Only one Detect Doxa button, not a duplicate navigation button.

# Arrange screens is ONLY a post-detection Windows task.
$setup=New-Object Windows.Forms.Panel;$setup.Dock='Fill';$setup.Visible=$false;$main.Controls.Add($setup)
$setup.Controls.Add((UXLabel 'Arrange your four screens' 13 8 610 37 18 $true))
$setup.Controls.Add((UXLabel 'After Windows detects Doxa, arrange the laptop and three external screens.' 13 49 610 44 10))
$layoutDiagram=New-Object Windows.Forms.Panel
$layoutDiagram.SetBounds(12,92,617,212)
$layoutDiagram.AccessibleName='Suggested physical layout: Doxa screens 2, 3 and 4 in a horizontal row, laptop screen 1 below the centre.'
$layoutDiagram.Add_Paint({
 param($s,$e)
 $g=$e.Graphics;$g.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
 $pen=New-Object Drawing.Pen ([Drawing.Color]::FromArgb(49,53,61)),3
 $fill=New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(238,243,247))
 $inkBrush=New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(24,32,50))
 $font=New-Object Drawing.Font('Segoe UI',13,[Drawing.FontStyle]::Bold)
 try{
  for($i=0;$i -lt 3;$i++){
   $x=8+$i*204
   $g.FillRectangle($fill,$x,9,195,100);$g.DrawRectangle($pen,$x,9,195,100)
   $g.DrawString((T ('Screen '+($i+2)) ('Ecran '+($i+2))),$font,$inkBrush,$x+48,49)
  }
  $g.FillRectangle($fill,233,131,153,66);$g.DrawRectangle($pen,233,131,153,66)
  $g.DrawString('Laptop 1',$font,$inkBrush,265,153)
 }finally{foreach($res in @($pen,$fill,$inkBrush,$font)){$res.Dispose()}}
})
$setup.Controls.Add($layoutDiagram)
$setup.Controls.Add((UXLabel '1. In Windows Display settings, select Identify to see the real monitor numbers.' 13 307 616 35 10))
$setup.Controls.Add((UXLabel '2. Select Extend, then drag each Windows rectangle to match your desk.' 13 338 615 36 10))
$settingsButton=UXButton 'Open Windows Display settings' 13 394 323 41
$settingsButton.AccessibleDescription='Opens Windows settings. Does not automatically change displays.'
$setup.Controls.Add($settingsButton)
$settingsButton.Add_Click({
 try{Start-Process 'ms-settings:display'|Out-Null}
 catch{[Windows.Forms.MessageBox]::Show((T 'Use Win+I, then System > Display.' 'Foloseste Win+I, apoi Sistem > Ecran.'),'Doxa')|Out-Null}
})

# Signed driver is conditional troubleshooting, not a normal mandatory step.
$install=New-Object Windows.Forms.Panel;$install.Dock='Fill';$install.Visible=$false;$main.Controls.Add($install)
$install.Controls.Add((UXLabel 'Signed driver: only if needed' 14 15 615 43 18 $true))
$install.Controls.Add((UXLabel 'Check Doxa first. When the signed Silicon Motion driver is healthy, no installation is needed.' 14 84 615 60 11))
$driverStatus=UXLabel 'Driver status: run Detect Doxa to verify.' 14 164 600 62 12 $true
$install.Controls.Add($driverStatus)
$install.Controls.Add((UXLabel 'If the signed driver is missing, choose Install / check driver below. Windows will ask for administrator approval. A working driver is never replaced.' 14 249 613 78 11))
$driverAction=UXButton 'Install / check driver' 14 339 286 45
$driverAction.AccessibleName='Install or verify the signed Doxa Windows display driver'
$driverAction.AccessibleDescription='Uses the protected Doxa Windows installer and asks for administrator approval only if installation is needed.'
$install.Controls.Add($driverAction)
$driverAction.Add_Click({
 $native=Join-Path $env:ProgramFiles 'Standivarius\DoxaMaintenance\DoxaMaintenance.exe'
 if(-not(Test-Path -LiteralPath $native -PathType Leaf)){
  Say 'Doxa' (T 'Open the original Standivarius Doxa Windows installer to install the driver.' 'Deschide instalatorul Doxa pentru Windows ca sa instalezi driverul.')
  return
 }
 try {
  $process=Start-Process -FilePath $native -ArgumentList '/install' -Verb RunAs -PassThru -Wait
  if($process.ExitCode -in @(0,3010)){
   RefreshState
   Say 'Doxa' (T 'Windows has completed its driver check. Verify all external screens. If requested, restart at a convenient time.' 'Windows a incheiat verificarea driverului. Verifica ecranele externe. Daca este necesar, reporneste cand este convenabil.')
  }else{
   Say 'Doxa' (T 'Windows driver setup was not completed. Ask IT to check the Doxa installer logs.' 'Instalarea driverului nu s-a incheiat. Solicita IT sa verifice jurnalul instalatorului Doxa.')
  }
 }catch{
  Say 'Doxa' (T 'Administrator approval was declined or setup could not start.' 'Aprobarea administratorului a fost refuzata sau instalarea nu a pornit.')
 }
})
$reinstall.Visible=$false
$official.SetBounds(14,401,450,30);$official.LinkColor=$red;$install.Controls.Add($official)

# Doxa Help stays present on the RIGHT for every task, not an interchangeable guide.
$side.BorderStyle='None';$side.BackColor=$white
$side.SetBounds(0,0,339,475);$sideHolder.Controls.Add($side)
$helpHeading.Text='Doxa Help';$helpHeading.SetBounds(14,10,309,38)
$assistantStatus.SetBounds(14,49,308,27)
$offline.Visible=$false;$hint.Visible=$false
$modeOff=New-Object Windows.Forms.RadioButton
$modeOff.SetBounds(14,82,143,28);$modeOff.Text='Offline help';$modeOff.Checked=(-not $script:cloudConsent)
$modeOn=New-Object Windows.Forms.RadioButton
$modeOn.SetBounds(169,82,146,28);$modeOn.Text='Online AI';$modeOn.Checked=[bool]$script:cloudConsent
$side.Controls.AddRange(@($modeOff,$modeOn))
$chat.SetBounds(14,118,309,246)
$ask.SetBounds(14,373,203,32);$send.SetBounds(228,373,95,32);$send.BackColor=$red
$privacy=New-Object Windows.Forms.LinkLabel
$privacy.Text='Privacy details for online AI';$privacy.SetBounds(14,422,302,34)
$privacy.LinkColor=$red
$privacy.Add_LinkClicked({
 $f=Join-Path $PSScriptRoot 'AI-PRIVACY-NOTICE.txt'
 try{
  $dlg=New-Object Windows.Forms.Form;$dlg.Text=T 'Doxa privacy details' 'Confidentialitate Doxa'
  $dlg.ClientSize=New-Object Drawing.Size(650,445);$dlg.StartPosition='CenterParent'
  $txt=New-Object Windows.Forms.TextBox;$txt.Multiline=$true;$txt.ReadOnly=$true
  $txt.ScrollBars='Vertical';$txt.Dock='Fill';$txt.Text=Get-Content -LiteralPath $f -Raw -Encoding UTF8
  $dlg.Controls.Add($txt);[void]$dlg.ShowDialog($form);$dlg.Dispose()
 }catch{[Windows.Forms.MessageBox]::Show((T 'Privacy notice unavailable.' 'Informarea nu este disponibila.'),'Doxa')|Out-Null}
})
$side.Controls.Add($privacy)
$script:previousAIApproval=[bool]$script:cloudConsent
$modeOff.Add_CheckedChanged({
 if(-not $modeOff.Checked){return}
 $script:cloudConsent=$false;$script:previousAIApproval=$false
 $script:queuedQuestion='';$script:quickAdviceShown=$false
 if($script:aiJob){
  $aiTimer.Stop();Stop-Job $script:aiJob -ErrorAction SilentlyContinue
  Remove-Job $script:aiJob -Force -ErrorAction SilentlyContinue;$script:aiJob=$null;$send.Enabled=$true
 }
 $assistantStatus.Text=T 'Offline selected. Already-sent requests cannot be recalled.' 'Ajutor offline. Cererile deja trimise nu pot fi retrase.'
})
$modeOn.Add_CheckedChanged({
 if(-not $modeOn.Checked){return}
 $policy=(& $script:cloudPolicyScript | Out-String)|ConvertFrom-Json
 if(-not [bool]$policy.cloud_ai_allowed){$modeOff.Checked=$true;return}
 if(-not $script:previousAIApproval){
  $msg=T 'Online AI sends your typed question and limited Doxa/Windows diagnostics over HTTPS. No screenshots. Allow online AI this session?' 'AI online trimite intrebarea si diagnostice limitate Doxa/Windows prin HTTPS. Fara capturi de ecran. Permiti AI online in aceasta sesiune?'
  $answer=[Windows.Forms.MessageBox]::Show($msg,'Doxa online AI',[Windows.Forms.MessageBoxButtons]::YesNo,[Windows.Forms.MessageBoxIcon]::Question,[Windows.Forms.MessageBoxDefaultButton]::Button2)
  if($answer -ne [Windows.Forms.DialogResult]::Yes){$modeOff.Checked=$true;return}
  $script:previousAIApproval=$true
 }
 $script:cloudConsent=$true;$assistantStatus.Text=T 'Online AI enabled' 'AI online activat'
})

function SelectDoxaPage([string]$page) {
 $script:doxaCurrentPage=$page
 foreach($p in @($detect,$setup,$install)){$p.Visible=$false}
 switch($page){detect{$detect.Visible=$true}setup{$setup.Visible=$true}install{$install.Visible=$true}}
 for($i=0;$i -lt 3;$i++){
  $selected=@('detect','setup','install')[$i] -eq $page
  $tabs[$i].BackColor=if($selected){$red}else{$white}
  $tabs[$i].ForeColor=if($selected){$white}else{$ink}
  $tabs[$i].FlatAppearance.BorderColor=if($selected){$red}else{$line}
  $tabs[$i].AccessibleDescription=if($selected){T 'Selected task' 'Sarcina selectata'}else{T 'Other task' 'Alta sarcina'}
 }
 if($page -eq 'install'){
  $driverAction.Visible=(-not ($script:current -and $script:current.observed.signed_driver_present))
  $driverStatus.Text=if($script:current -and $script:current.observed.signed_driver_present){
   T 'Signed Silicon Motion driver detected. No reinstall needed.' 'Driver Silicon Motion semnat detectat. Nu este necesara reinstalarea.'
  }else{
   T 'Driver not verified. Check Doxa before seeking an official driver.' 'Driver neconfirmat. Verifica Doxa inainte de a solicita driverul oficial.'
  }
 }
 # Help chat is intentionally persistent and does not change into step prose.
 $side.Visible=$true;$sideHolder.Visible=$true
 $workspace.Invalidate()
}
$tabs[0].Add_Click({SelectDoxaPage 'detect'})
$tabs[1].Add_Click({SelectDoxaPage 'setup'})
$tabs[2].Add_Click({SelectDoxaPage 'install'})
# Older button's illustrated help handler is not part of this workflow.
# Compatibility reference points at the one visible setup tab, not an orphan.
$guide=$tabs[1]
function UpdateDoxaPanelTicks {
 if(-not $script:current){return}
 $observed=$script:current.observed
 $profile=@('Generic Monitor (L)','Generic Monitor (T)','Generic Monitor (R)')
 $present=@($observed.pnp_doxa_panels)
 for($i=0;$i -lt 3;$i++) {
  $script:doxaScreenChecks[$i]=[bool](-not $script:current.test_only -and $observed.doxa_hardware_detected -and ($present -contains $profile[$i]))
 }
 $screenDiagram.AccessibleDescription=(T 'Windows PnP recognition by screen: ' 'Identificare Windows PnP pe ecran: ')+
  (@(for($i=0;$i -lt 3;$i++){($i+2).ToString()+': '+$(if($script:doxaScreenChecks[$i]){T 'identified' 'detectat'}else{T 'not identified' 'nedetectat'})}) -join ', ')+
  (T '. Does not verify independent Extend mode.' '. Nu confirma extinderea independenta.')
 $screenDiagram.Invalidate()
}
# Initial diagnostic state and subsequent manual rechecks both call UpdateDoxaPanelTicks.
# This helper is read-only and only uses validated observed data; no fake checks.
function LayoutDoxa {
 $width=[int]$form.ClientSize.Width
 $narrow=($width -lt 1040)
 if($narrow){
  $workspace.SetBounds(19,119,663,478)
  $sideHolder.SetBounds(19,611,663,477)
  $side.SetBounds(0,0,661,473)
  $chat.Width=628;$ask.Width=520;$send.Left=548;$send.Width=96
  $privacy.Top=422
 }else{
  $workspace.SetBounds(19,119,663,478)
  $sideHolder.SetBounds(699,119,($width-719),478)
  $side.SetBounds(0,0,($sideHolder.Width-2),473)
  $chat.Width=$side.Width-30;$ask.Width=$side.Width-136
  $send.Left=$side.Width-111;$send.Width=96
 }
 $languageChoice.Left=[Math]::Max(535,$width-166)
}
$form.Add_ClientSizeChanged({LayoutDoxa})
$brandTranslations=@{
 'Detect Doxa'='Detecteaza Doxa'
 'Check connection'='Verifica conexiunea'
 'Set up screens'='Configureaza ecranele'
 'Install signed driver'='Driver semnat'
 'Connect Doxa'='Conecteaza Doxa'
 'Rear of the central Doxa screen:'='In spatele ecranului Doxa central:'
 'POWER  -  upper USB-C socket'='ALIMENTARE  -  port USB-C superior'
 'DATA  -  lower USB-C socket'='DATE  -  port USB-C inferior'
 'Check the three screens'='Verifica cele trei ecrane'
 'Green ticks = Windows sees each Doxa monitor identity; this does not confirm Extend mode.'='Bife verzi = Windows identifica panourile Doxa; nu confirma modul Extindere.'
 'Arrange your four screens'='Aranjeaza cele patru ecrane'
 'After Windows detects Doxa, arrange the laptop and three external screens.'='Dupa detectarea Doxa, aranjeaza laptopul si cele trei ecrane externe.'
 '1. In Windows Display settings, select Identify to see the real monitor numbers.'='1. In setarile Windows, alege Identificare pentru numerele reale.'
 '2. Select Extend, then drag each Windows rectangle to match your desk.'='2. Alege Extindere, apoi trage dreptunghiurile conform ecranelor fizice.'
 'Open Windows Display settings'='Deschide setarile de afisare Windows'
 'Signed driver: only if needed'='Driver semnat: doar la nevoie'
 'Check Doxa first. When the signed Silicon Motion driver is healthy, no installation is needed.'='Verifica Doxa mai intai. Daca driverul Silicon Motion semnat functioneaza, nu instala nimic.'
 'Driver status: run Detect Doxa to verify.'='Starea driverului: apasa Detecteaza Doxa pentru verificare.'
 'If the signed driver is missing, choose Install / check driver below. Windows will ask for administrator approval. A working driver is never replaced.'='Daca driverul semnat lipseste, apasa Instaleaza / verifica driverul. Windows va solicita aprobarea administratorului. Driverul functional nu este inlocuit.'
 'Offline help'='Ajutor offline'
 'Online AI'='AI online'
 'Privacy details for online AI'='Confidentialitate AI online'
 'Doxa Help'='Asistenta Doxa'
}
function TranslateDoxa {
 function Walk($root){
  foreach($c in @($root.Controls)){
   if($c -is [Windows.Forms.Label] -or $c -is [Windows.Forms.Button] -or $c -is [Windows.Forms.RadioButton] -or $c -is [Windows.Forms.LinkLabel]){
    if($c.Tag -and [string]$c.Tag -like 'doxa-en:*'){$en=([string]$c.Tag).Substring(8)}
    else{
     $en=[string]$c.Text
     if($brandTranslations.ContainsKey($en)){$c.Tag='doxa-en:'+$en}
    }
    if($brandTranslations.ContainsKey($en)){
     $c.Text=if($script:lang -eq 'ro'){$brandTranslations[$en]}else{$en}
     $c.AccessibleName=$c.Text
    }
   }
   if($c.HasChildren){Walk $c}
  }
 }
 Walk $form
 $check.Text=T 'Check connection' 'Verifica conexiunea'
 $check.AccessibleName=$check.Text
 SelectDoxaPage $script:doxaCurrentPage
 $screenDiagram.Invalidate();$layoutDiagram.Invalidate();$ports.Invalidate()
}
foreach($b in $tabs){$b.AccessibleRole=[Windows.Forms.AccessibleRole]::PageTab}
for($i=0;$i -lt 3;$i++){$tabs[$i].TabIndex=($i+1)}
$check.TabIndex=5;$settingsButton.TabIndex=6;$modeOff.TabIndex=7;$modeOn.TabIndex=8;$ask.TabIndex=9;$send.TabIndex=10;$privacy.TabIndex=11
$languageChoice.Add_SelectedIndexChanged({TranslateDoxa})
$script:doxaCurrentPage='detect'
SelectDoxaPage 'detect'
LayoutDoxa
TranslateDoxa
$form.Tag=[pscustomobject]@{
 stage='main';checkButton=$check;guideButton=$guide;statusLabel=$stateLabel
 tabs=$tabs;workspace=$workspace;side_panel=$side;help_persistent=$true
 detect_page=$detect;setup_page=$setup;install_page=$install
 connection_ports=$ports;screen_diagram=$screenDiagram;screen_checks=$script:doxaScreenChecks
 upper_port='power';lower_port='data';online_toggle=$modeOn;offline_toggle=$modeOff
}
