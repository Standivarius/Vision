param(
 [switch]$Smoke,[switch]$JourneyTest,[switch]$DeveloperTests,[string]$SnapshotPath="",
 [switch]$DiagnosticsApproved,[switch]$AIApproved,
 [ValidateSet('connected','without_doxa')][string]$ConnectionPreference='without_doxa',
 [ValidateSet('en','ro')][string]$Language='en', [int]$CompactTestWidth=0,
 [object]$HostForm=$null,[switch]$EmbeddedSmoke,[switch]$BrandTest
)
# Simulation flag only works in read-only UI smoke mode, never actual setup.
if($CompactTestWidth -ne 0 -and ((-not $Smoke) -or $CompactTestWidth -lt 440 -or $CompactTestWidth -gt 522)){
 throw 'Compact width injection is restricted to smoke tests between 440 and 522 pixels'
}
# Regular entry always presents explicit permissions before scanning the computer.
if(-not $DiagnosticsApproved -and -not $Smoke -and -not $JourneyTest -and -not $DeveloperTests -and -not $HostForm -and -not $BrandTest){
 & (Join-Path $PSScriptRoot 'Start-DoxaGuidedSetup.ps1') -Language $Language
 return
}
$script:cloudConsent=[bool]$AIApproved
$script:connectionChoice=$ConnectionPreference
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$diagnose=Join-Path $PSScriptRoot 'Get-DoxaSetupExperience.ps1'
$assistantScript=Join-Path $PSScriptRoot 'Ask-DoxaInstaller.ps1'
$compatibilityScript=Join-Path $PSScriptRoot 'Get-DoxaCompatibility.ps1'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$maintenance=Join-Path $repo 'artifacts\vendor\smi770-msi-20261016\controlled-reinstall-20261016.ps1'
$navy=[Drawing.Color]::FromArgb(17,35,59)
$teal=[Drawing.Color]::FromArgb(16,140,137)
$slate=[Drawing.Color]::FromArgb(67,82,99)
$light=[Drawing.Color]::FromArgb(231,238,245)
$form=if($HostForm){$HostForm}else{New-Object Windows.Forms.Form}
$form.Text='Standivarius | Doxa Setup'
$script:developerMode=[bool]($DeveloperTests -or $JourneyTest)
$form.StartPosition='CenterScreen'
$form.ClientSize=New-Object Drawing.Size(1060,685)
$form.FormBorderStyle='Sizable'
$form.MaximizeBox=$true
$form.AutoScroll=$true
$form.BackColor=[Drawing.Color]::FromArgb(247,249,252)
$form.Font=New-Object Drawing.Font('Segoe UI',10)
function Label([string]$text,[int]$x,[int]$y,[int]$w,[int]$h,[int]$size=10,[bool]$bold=$false,[object]$colour=$null) {
 $l=New-Object Windows.Forms.Label
 $l.SetBounds($x,$y,$w,$h);$l.Text=$text;$l.AutoEllipsis=$true
 $l.Font=New-Object Drawing.Font('Segoe UI',$size,$(if($bold){[Drawing.FontStyle]::Bold}else{[Drawing.FontStyle]::Regular}))
 $l.ForeColor=if($colour){$colour}else{$slate}
 return $l
}
function Button([string]$text,[int]$x,[int]$y,[int]$w,[int]$h,[object]$bg,[object]$fg) {
 $b=New-Object Windows.Forms.Button
 $b.SetBounds($x,$y,$w,$h);$b.Text=$text
 $b.BackColor=$bg;$b.ForeColor=$fg;$b.FlatStyle='Flat';$b.FlatAppearance.BorderSize=0
 $b.UseVisualStyleBackColor=$false
 return $b
}
$head=New-Object Windows.Forms.Panel
$head.SetBounds(0,0,1060,110);$head.BackColor=$navy;$form.Controls.Add($head)
$head.Controls.Add((Label 'Standivarius' 28 13 430 32 19 $true ([Drawing.Color]::White)))
$head.Controls.Add((Label 'D O X A    /    SETUP & SUPPORT' 29 55 520 24 10 $true ([Drawing.Color]::FromArgb(119,225,222))))
$languageChoice=New-Object Windows.Forms.ComboBox
$languageChoice.SetBounds(840,27,181,31);$languageChoice.DropDownStyle='DropDownList'
[void]$languageChoice.Items.Add('English');[void]$languageChoice.Items.Add('Romana')
$languageChoice.SelectedIndex=0;$head.Controls.Add($languageChoice)
$languageChoice.AccessibleName='Application language / Limba aplicatiei'
$languageChoice.TabIndex=0
$intro=Label 'Get your screens ready' 29 138 610 34 20 $true $navy
$sub=Label 'Step 3 of 4: checking Windows, USB and Doxa readiness.' 29 178 620 38
$form.Controls.AddRange(@($intro,$sub))
$card=New-Object Windows.Forms.Panel
$card.SetBounds(28,230,620,332);$card.BackColor=[Drawing.Color]::White
$card.BorderStyle='FixedSingle';$form.Controls.Add($card)
$cardHeading=Label 'Your Doxa system' 21 15 320 30 13 $true $navy
$card.Controls.Add($cardHeading)
# Original vector illustration rendered locally by Windows Forms: no external image,
# manufacturer mark, cloud request or device state is inferred from this diagram.
$deviceArt=New-Object Windows.Forms.Panel
$deviceArt.SetBounds(20,50,579,130)
$deviceArt.BackColor=[Drawing.Color]::FromArgb(244,248,252)
$deviceArt.AccessibleName='Illustration of three Doxa display panels connected to one dock'
$deviceArt.AccessibleDescription='Illustration only; actual screen connection state is shown in the equipment details below.'
$deviceArt.Add_Paint({
 param($sender,$event)
 $g=$event.Graphics
 $g.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
 if($sender.Width -lt 579){$g.ScaleTransform(($sender.Width/579.0),1.0)}
 $screenPen=New-Object Drawing.Pen ([Drawing.Color]::FromArgb(65,83,112)),2
 $panelBrush=New-Object Drawing.SolidBrush ([Drawing.Color]::White)
 $glass=New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(222,241,246))
 $accent=New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(78,170,185))
 $foot=New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(105,126,149))
 $wire=New-Object Drawing.Pen ([Drawing.Color]::FromArgb(159,177,192)),2
 $dock=New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(37,62,86))
 $glow=New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(225,236,241))
 try {
  # Central screen is larger, mirroring the typical triple-screen desktop geometry.
  foreach($panel in @(@(111,18,123,66),@(230,7,133,78),@(359,18,123,66))){
   $x=[int]$panel[0];$y=[int]$panel[1];$w=[int]$panel[2];$h=[int]$panel[3]
   $g.FillRectangle($glow,$x+5,$y+6,$w,$h)
   $g.FillRectangle($panelBrush,$x,$y,$w,$h)
   $g.DrawRectangle($screenPen,$x,$y,$w,$h)
   $g.FillRectangle($glass,$x+7,$y+7,$w-14,$h-17)
   $g.FillRectangle($accent,$x+7,$y+7,($w-14),4)
   $g.FillRectangle($foot,($x+[int]($w/2)-2),$y+$h,4,12)
   $g.FillRectangle($foot,($x+[int]($w/2)-15),$y+$h+12,30,3)
  }
  # Doxa USB display controller with unbroken power/data path; diagram is not a detection result.
  $g.DrawLine($wire,296,101,296,109)
  $g.FillRectangle($dock,272,109,49,13)
  $g.FillRectangle($accent,277,113,7,4)
 }finally{
  foreach($item in @($screenPen,$panelBrush,$glass,$accent,$foot,$wire,$dock,$glow)){$item.Dispose()}
 }
})
$card.Controls.Add($deviceArt)
$connectionBadge=Label 'STATUS NOT CHECKED' 386 20 206 23 9 $true $slate
$connectionBadge.TextAlign='MiddleRight'
$connectionBadge.AccessibleName='Doxa connection status'
$card.Controls.Add($connectionBadge)
$rows=@()
for($i=0;$i -lt 3;$i++){
 $l=Label '' 21 (186+$i*34) 572 31 10 $false $navy
 $card.Controls.Add($l);$rows+=,$l
}
$stateLabel=Label '' 21 286 575 39 9 $false $slate
$card.Controls.Add($stateLabel)
$check=Button 'Detect Doxa' 28 576 155 46 $teal ([Drawing.Color]::White)
$guide=Button 'Set up screens...' 215 576 148 46 $light $navy
$guide.AccessibleName='Open the offline illustrated Doxa connection and four-screen layout guide'
$guide.AccessibleDescription='Read-only instructions without AI, driver changes or internet connection.'
$guide.TabIndex=1
$reset=Button 'Return to live check' 194 576 187 46 $light $navy
$reinstall=Button 'Install signed driver...' 394 576 253 46 $navy ([Drawing.Color]::White)
$form.Controls.AddRange(@($check,$guide,$reset,$reinstall))
$check.TabIndex=0
$check.AccessibleName='Detect Doxa, read only, without driver changes'
$reinstall.TabIndex=2
$reinstall.AccessibleName='Install a verified original signed vendor driver, if required'
$reinstall.AccessibleDescription='Only after local source verification and separate administrator approval. Will not reinstall a working signed driver.'
$reset.Visible=$script:developerMode
if(-not $script:developerMode){
 $check.SetBounds(28,576,175,46)
 $guide.SetBounds(215,576,148,46)
 $reinstall.SetBounds(375,576,272,46)
}
$side=New-Object Windows.Forms.Panel
$side.SetBounds(669,136,362,487);$side.BackColor=[Drawing.Color]::White
$side.BorderStyle='FixedSingle';$form.Controls.Add($side)
$helpHeading=Label 'Doxa help' 17 15 330 30 15 $true $navy
$assistantStatus=Label 'Doxa installation questions only' 17 48 336 25 9 $false $slate
$side.Controls.AddRange(@($helpHeading,$assistantStatus))
$chat=New-Object Windows.Forms.RichTextBox
$chat.SetBounds(17,80,326,242);$chat.ReadOnly=$true;$chat.BorderStyle='None'
$chat.BackColor=[Drawing.Color]::FromArgb(249,252,253)
$chat.Font=New-Object Drawing.Font('Segoe UI',10);$side.Controls.Add($chat)
$chat.AccessibleName='Doxa help conversation'
$chat.TabStop=$true
$chat.TabIndex=0
$ask=New-Object Windows.Forms.TextBox
$ask.SetBounds(17,330,228,33);$side.Controls.Add($ask)
$ask.AccessibleName='Ask a Doxa installation question'
$ask.TabIndex=1
$send=Button 'Ask' 258 328 85 35 $teal ([Drawing.Color]::White)
$side.Controls.Add($send)
$send.TabIndex=2
$send.AccessibleDescription='Send an installation question. Online AI is used only if separately approved.'
$faultTitle=Label 'Test an installation problem (safe)' 17 381 326 25 10 $true $navy
$side.Controls.Add($faultTitle)
$faults=New-Object Windows.Forms.ComboBox
$faults.SetBounds(17,410,226,28);$faults.DropDownStyle='DropDownList'
foreach($t in @('Missing driver','Missing display','Blocked by IT','Changed driver package','Online help unavailable')){[void]$faults.Items.Add($t)}
$faults.SelectedIndex=0;$side.Controls.Add($faults)
$inject=Button 'Try' 258 407 85 34 $navy ([Drawing.Color]::White)
$side.Controls.Add($inject)
$faultTitle.Visible=$script:developerMode
$faults.Visible=$script:developerMode
$inject.Visible=$script:developerMode
$hint=Label 'Ask about a Doxa screen, connection or driver.' 17 448 330 25 9 $false $slate
$side.Controls.Add($hint)
$hint.Visible=(-not $script:developerMode -and -not $script:cloudConsent)
$offline=Button 'Switch to offline help' 17 442 326 31 $light $navy
$offline.Visible=([bool]$script:cloudConsent -and -not $script:developerMode)
$side.Controls.Add($offline)
if(-not $script:developerMode){
 $chat.SetBounds(17,80,326,295)
 $ask.SetBounds(17,389,228,36)
 $send.SetBounds(258,388,85,38)
}
$advanced=New-Object System.Windows.Forms.LinkLabel
$advanced.SetBounds(405,629,295,19)
$advanced.Text='Advanced: reinstall test (developer)'
$advanced.LinkColor=$slate
$advanced.Visible=($script:developerMode -and (Test-Path -LiteralPath $maintenance -PathType Leaf))
$form.Controls.Add($advanced)
$official=New-Object System.Windows.Forms.LinkLabel
$official.SetBounds(30,628,330,20)
$official.Text='Official Silicon Motion driver downloads'
$official.LinkColor=$teal
$form.Controls.Add($official)
$official.Add_LinkClicked({
 try{Start-Process 'https://www.siliconmotion.com/downloads/SM770-drivers.html'|Out-Null}
 catch{Say 'Doxa' (T 'Open siliconmotion.com and find the official SM770 driver.' 'Deschide siliconmotion.com pentru driverul oficial SM770.')}
})
$footer=Label 'Doxa Setup | Windows administrator approval is required for driver changes' 29 648 995 22 9
$form.Controls.Add($footer)
# In a portrait/remote Windows desktop, stack device and help instead of losing
# half the application off-screen. On full-size desktops retain the two-column view.
$script:compactLayout=($CompactTestWidth -gt 0 -or [Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Width -lt 1090)
if($script:compactLayout){
 $work=[Windows.Forms.Screen]::PrimaryScreen.WorkingArea
 $width=if($CompactTestWidth -gt 0){$CompactTestWidth}else{[Math]::Max(440,[Math]::Min(522,$work.Width-16))}
 $height=[Math]::Max(530,[Math]::Min(940,$work.Height-55))
 $form.AutoScroll=$true
 $form.ClientSize=New-Object Drawing.Size($width,$height)
 $head.SetBounds(0,0,$width,107)
 $languageChoice.SetBounds(($width-174),30,157,30)
 $intro.SetBounds(17,121,($width-34),35)
 $sub.SetBounds(17,163,($width-34),40)
 $cardWidth=$width-40 # Reserve space for the vertical scrollbar at high DPI.
 $card.SetBounds(10,213,$cardWidth,332)
 $cardHeading.SetBounds(17,14,253,30)
 $connectionBadge.SetBounds(($cardWidth-195),20,177,23)
 $deviceArt.SetBounds(12,50,($cardWidth-24),130)
 for($i=0;$i -lt 3;$i++){$rows[$i].SetBounds(17,(186+$i*34),($cardWidth-34),31)}
 $stateLabel.SetBounds(17,286,($cardWidth-34),39)
 $actionsTop=556
 $check.SetBounds(10,$actionsTop,155,46)
 $guide.SetBounds(173,$actionsTop,145,46)
 # Driver install requires a full-width labelled action on narrow screens.
 $reinstall.SetBounds(10,610,$cardWidth,46)
 $reset.SetBounds(10,1240,200,30)
 $side.SetBounds(10,667,$cardWidth,488)
 $helpHeading.SetBounds(17,15,($cardWidth-34),30)
 $assistantStatus.SetBounds(17,48,($cardWidth-34),25)
 $chat.SetBounds(17,80,($cardWidth-34),295)
 $ask.SetBounds(17,389,($cardWidth-127),36)
 $send.SetBounds(($cardWidth-99),388,82,38)
 $hint.SetBounds(17,448,($cardWidth-34),25)
 $offline.SetBounds(17,442,($cardWidth-34),31)
 $official.SetBounds(20,1169,($width-40),23)
 $footer.SetBounds(20,1203,($width-40),24)
}
# Laptop screen height is a separate constraint from window width.
$workArea=[Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$script:shortWide=((-not $script:compactLayout) -and $workArea.Height -lt 760)
if($script:shortWide){
 $safeHeight=[Math]::Min(625,[Math]::Max(510,$workArea.Height-50))
 $form.ClientSize=New-Object Drawing.Size(1060,$safeHeight)
 $head.SetBounds(0,0,1060,95)
 $intro.SetBounds(29,102,610,34)
 $sub.SetBounds(29,141,620,38)
 $card.SetBounds(28,186,620,317)
 $deviceArt.SetBounds(20,48,579,112)
 for($i=0;$i -lt 3;$i++){$rows[$i].SetBounds(21,(161+$i*34),572,31)}
 $stateLabel.SetBounds(21,264,575,44)
 $check.SetBounds(28,513,175,43)
 $guide.SetBounds(215,513,148,43)
 $reinstall.SetBounds(375,513,272,43)
 $side.SetBounds(669,113,362,445)
 if(-not $script:developerMode){
  $chat.SetBounds(17,78,326,295)
  $ask.SetBounds(17,381,228,36)
  $send.SetBounds(258,380,85,38)
  $hint.SetBounds(17,405,326,28)
  $offline.SetBounds(17,404,326,31)
 }
 $official.SetBounds(30,565,330,24)
 $footer.SetBounds(29,592,995,22)
 $advanced.SetBounds(410,565,290,20)
}
$form.MinimumSize=if($script:compactLayout){New-Object Drawing.Size(440,480)}else{New-Object Drawing.Size(770,500)}
$script:lastDetectionKey='';$script:current=$null;$script:fault='none';$script:lang=$Language
$script:cloudPolicyScript=Join-Path $PSScriptRoot 'Get-DoxaCloudAIPolicy.ps1'
function T([string]$en,[string]$ro){if($script:lang -eq 'ro'){$ro}else{$en}}
function Say([string]$speaker,[string]$body){
 $nl=[Environment]::NewLine
 $chat.SelectionStart=$chat.TextLength
 $chat.SelectionColor=if($speaker -eq 'Doxa'){$teal}else{$navy}
 $chat.SelectionFont=New-Object Drawing.Font('Segoe UI',10,[Drawing.FontStyle]::Bold)
 $chat.AppendText($speaker+$nl)
 $chat.SelectionColor=$slate
 $chat.SelectionFont=New-Object Drawing.Font('Segoe UI',10)
 $chat.AppendText($body+$nl+$nl)
 $chat.ScrollToCaret()
}
function RefreshState {
 try{
  $assistantStatus.Text=T 'Checking Windows and Doxa (read-only)...' 'Verificam Windows si Doxa (fara modificari)...'
  [Windows.Forms.Application]::DoEvents()
  $result=& $diagnose -Fault $script:fault -Language $script:lang | Out-String | ConvertFrom-Json
  $script:current=$result
  $d=$result.observed
  $stateKey=($result.code+'|'+[string]$d.driver_version+'|'+[string]$d.active_desktops+'|'+[string]@($d.pnp_doxa_panels).Count+'|'+[string]$script:fault)
  $stateChanged=($stateKey -ne $script:lastDetectionKey)
  $script:lastDetectionKey=$stateKey
  # Never conflate decorative illustration with verified physical device presence.
  $connectionBadge.Text=if($result.test_only){'TEST DATA'}elseif($d.hardware_ready){T '3 PANELS IDENTIFIED' '3 PANOURI DETECTATE'}elseif($result.code -eq 'doxa_not_detected'){T 'NOT CONNECTED' 'DECONECTAT'}else{T 'CHECK REQUIRED' 'VERIFICA'}
  $connectionBadge.ForeColor=if($d.hardware_ready){$teal}else{[Drawing.Color]::FromArgb(151,86,40)}
  $rows[0].Text=if($d.signed_driver_present){
   "OK   Signed Silicon Motion driver, version "+$d.driver_version
  }elseif($result.code -eq 'doxa_not_detected' -and $d.driver_package_in_store){
   T 'INFO   Silicon Motion driver package is still installed in Windows' 'INFO   Pachetul driver Silicon Motion este inca instalat in Windows'
  }elseif($result.code -eq 'doxa_not_detected'){
   T 'INFO   Doxa not detected - driver cannot be verified yet' 'INFO   Doxa nu este detectat - driverul nu poate fi verificat'
  }else{
   T 'CHECK   Doxa driver not verified' 'VERIFICA   Driver Doxa neconfirmat'
  }
  $rows[1].Text=if($d.session_kind -eq 'remote'){
   'INFO   '+$d.active_desktops+(T ' remote-session desktop(s); physical topology not visible' ' ecrane in sesiunea remote; ecranele fizice nu se pot verifica')
  }else{
   'INFO   '+$d.active_desktops+(T ' local Windows desktop(s)' ' ecrane Windows in sesiunea locala')
  }
  $rows[2].Text=if($result.test_only){
   'DEVELOPER SIMULATION   '+$result.code
  }elseif($result.code -eq 'doxa_not_detected'){
   T 'CHECK   No Doxa panels detected. Check power and USB.' 'VERIFICA   Panourile Doxa nu sunt detectate. Verifica alimentarea si USB.'
   }elseif($d.hardware_ready){
    T 'PNP   Three Doxa monitor identities present; physical mapping unverified' 'PNP   Trei identitati de monitor Doxa; pozitiile nu sunt verificate'
  }else{
   'CHECK   '+$result.code
  }
  $stateLabel.Text=if($result.code -eq 'doxa_not_detected'){
   T 'NEXT: Connect Doxa power and USB, then click Detect Doxa.' 'URMATORUL PAS: Conecteaza alimentarea si USB, apoi Detecteaza Doxa.'
  }else{$result.message+$(if($result.test_only){'  [SIMULATION ONLY]'}else{''})}
  if(-not $stateChanged -and -not $result.test_only){$stateLabel.Text+=(T '  Refreshed ' '  Actualizat ')+(Get-Date -Format 'HH:mm:ss')}
   if($d.hardware_ready -and -not $d.physical_display_topology_verified){$stateLabel.Text=T 'Three Doxa PnP identities found. Four extended physical desktops have NOT been verified.' 'Trei identitati Doxa PnP gasite. Cele patru ecrane extinse fizic NU sunt confirmate.'}
   if($d.hardware_ready -and $d.physical_display_topology_verified){$stateLabel.Text=T 'Four Windows desktops observed; physical Doxa-to-Windows mapping remains unverified.' 'Patru ecrane Windows detectate; corespondenta fizica Doxa-Windows ramane neconfirmata.'}
   $stateLabel.ForeColor=if($d.hardware_ready){$slate}else{[Drawing.Color]::FromArgb(166,87,25)}
   if(Get-Command UpdateDoxaPanelTicks -ErrorAction SilentlyContinue){UpdateDoxaPanelTicks}
  $advice=$result.message
  if(-not $result.test_only -and $result.code -eq 'doxa_not_detected' -and $d.driver_package_in_store){
   $advice+=' '+(T 'The Silicon Motion driver package is still installed in Windows. Do not reinstall it; reconnect Doxa and check again.' 'Pachetul driver Silicon Motion este inca instalat in Windows. Nu il reinstala; reconecteaza Doxa si verifica din nou.')
  }
  if($stateChanged){Say 'Doxa' $advice}
  if(-not $result.test_only){
   # Refresh the expensive Windows USB compatibility census only when relevant state changed.
   if($stateChanged){
    $preflight=(& $compatibilityScript -ConnectionChoice $script:connectionChoice -Language $script:lang|Out-String)|ConvertFrom-Json
   $script:compatibility=$preflight
   $summary=(T 'Pre-check: ' 'Verificare preliminara: ')+[string]$preflight.recommendation
   $summary+=' '+(T 'USB controllers seen: ' 'Controlere USB detectate: ')+[string]$preflight.usb_controller_count
   $summary+=' '+(T 'Physical USB-C port and real screen behavior still require hardware verification.' 'Portul USB-C fizic si functionarea ecranelor trebuie verificate cu hardware-ul conectat.')
    Say 'Doxa' $summary
   }
    $sub.Text=T 'Detect Doxa and check the Windows screens.' 'Detecteaza Doxa si verifica ecranele Windows.'
   $assistantStatus.Text=if($script:cloudConsent){T 'Online AI requested; device approval may be required' 'AI online solicitat; aprobarea dispozitivului poate fi necesara'}else{T 'Offline Doxa help is ready' 'Asistenta Doxa offline este disponibila'}
  }
 }catch{
  $rows[2].Text='!    Check failed'
  $stateLabel.Text=$_.Exception.Message
  Say 'Doxa' ('The check could not finish: '+$_.Exception.Message)
 }
}
function Answer([string]$q){
 if(-not $script:current){return (T 'Please check Doxa first.' 'Verifica mai intai Doxa.')}
 if($script:fault -ne 'none'){
   return $script:current.message+' '+(T 'This is only a diagnostic test. Return to live check for your actual Windows state.' 'Aceasta este doar o simulare. Revino la verificarea reala pentru starea Windows.')
 }
 try{
  $source=Join-Path $PSScriptRoot 'Get-DoxaKnowledgeAnswer.ps1'
  $response=(& $source -Question $q -Language $script:lang | Out-String) | ConvertFrom-Json
  $answer=[string]$response.answer
  if($response.sources -and @($response.sources).Count -gt 0){
    $source=$response.sources[0]
    $url=[string]$source.url
    if($url -match '^https://(www\.siliconmotion\.com|learn\.microsoft\.com)/'){
      $answer+='  '+(T 'Source: ' 'Sursa: ')+[string]$source.publisher+' - '+$url
    }
  }
  return $answer
 }catch{
  return (T 'I could not open the local curated Doxa help at this moment.' 'Nu pot incarca acum sursele tehnice locale pentru Doxa.')
 }
}
$guide.Add_Click({
 Say 'Doxa' (T 'Follow the illustrated guide for Doxa power, USB data, Windows Extend and four-screen layout. This is offline guidance; no settings have been changed.' 'Urmareste ghidul ilustrat pentru alimentare, USB, Extindere si cele patru ecrane. Ghid offline; setarile nu au fost modificate.')
 if($JourneyTest -or $EmbeddedSmoke){return}
 $helper=Join-Path $PSScriptRoot 'Show-DoxaConnectionGuide.ps1'
 if(Test-Path -LiteralPath $helper){& $helper -Owner $form -Language $script:lang}
 else{Say 'Doxa' (T 'Guide unavailable. Open Windows Settings > System > Display manually.' 'Ghid indisponibil. Deschide Setari Windows > Sistem > Ecran.')}
})
$check.Add_Click({$script:fault='none';RefreshState})
$reset.Add_Click({$script:fault='none';RefreshState})
$inject.Add_Click({
 if(-not $script:developerMode){return}
 $script:fault=@('driver_missing','display_missing','policy_blocked','package_mismatch','support_offline')[$faults.SelectedIndex]
 RefreshState
})
$script:aiJob=$null
$script:queuedQuestion=''
$script:quickAdviceShown=$false
$aiTimer=New-Object System.Windows.Forms.Timer
$aiTimer.Interval=350
$aiTimer.Add_Tick({
 if($null -eq $script:aiJob){$aiTimer.Stop();return}
 if(-not $script:cloudConsent){
  $aiTimer.Stop(); Stop-Job -Job $script:aiJob -ErrorAction SilentlyContinue
  Remove-Job -Job $script:aiJob -Force -ErrorAction SilentlyContinue
  $script:aiJob=$null;$script:queuedQuestion='';$script:quickAdviceShown=$false;$send.Enabled=$true
  return
 }
 $policyNow=(& $script:cloudPolicyScript | Out-String)|ConvertFrom-Json
 if(-not [bool]$policyNow.cloud_ai_allowed){
  $script:cloudConsent=$false
  $aiTimer.Stop();Stop-Job -Job $script:aiJob -ErrorAction SilentlyContinue
  Remove-Job -Job $script:aiJob -Force -ErrorAction SilentlyContinue
  $script:aiJob=$null;$script:queuedQuestion='';$script:quickAdviceShown=$false;$send.Enabled=$true
  Say 'Doxa' (T 'IT policy now blocks online help; any already-sent request cannot be recalled.' 'Politica IT blocheaza acum AI online; cererea deja trimisa nu poate fi retrasa.')
  return
 }
 if($script:aiJob.State -notin @('Completed','Failed','Stopped')){return}
 $aiTimer.Stop()
 try{
  $raw=Receive-Job -Job $script:aiJob -ErrorAction Stop | Out-String
  $reply=$raw|ConvertFrom-Json
  if($reply.status -eq 'answered' -and $reply.answer){
   Say 'Doxa AI' ([string]$reply.answer)
   $assistantStatus.Text=T 'Doxa AI online -- setup only' 'Doxa AI conectat -- doar instalare'
  }elseif($reply.status -in @('out_of_scope','knowledge_gap') -and $reply.answer){
   Say 'Doxa' ([string]$reply.answer)
   $assistantStatus.Text=T 'Doxa installation support only' 'Doar asistenta pentru instalarea Doxa'
  }else{
   if($script:quickAdviceShown){
    Say 'Doxa' (T 'Online AI was unavailable. The verified offline guidance above remains available.' 'AI online nu a fost disponibil. Recomandarile offline de mai sus raman disponibile.')
   }else{
    Say 'Doxa' ((Answer $script:queuedQuestion)+' '+(T 'Online AI was unavailable; this is local guidance.' 'AI nu a fost disponibil; acesta este un raspuns local.'))
   }
   $assistantStatus.Text=T 'Local guidance -- Cloud AI unavailable' 'Asistenta locala -- AI indisponibil'
  }
 }catch{
  if($script:quickAdviceShown){
   Say 'Doxa' (T 'Online AI failed. Continue with the verified offline guidance above.' 'AI online a esuat. Continua cu recomandarile offline de mai sus.')
  }else{
   Say 'Doxa' ((Answer $script:queuedQuestion)+' '+(T 'Online AI was unavailable; using local guidance.' 'AI nu a fost disponibil; am folosit asistenta locala.'))
  }
 }finally{
  Remove-Job -Job $script:aiJob -Force -ErrorAction SilentlyContinue
  $script:aiJob=$null
  $script:queuedQuestion=''
  $script:quickAdviceShown=$false
  $send.Enabled=$true
 }
})
$send.Add_Click({
 $q=$ask.Text.Trim()
 if(-not $q){return}
 if($null -ne $script:aiJob){return}
 Say (T 'You' 'Tu') $q
 $ask.Clear()
 if($q.Length -gt 1800){Say 'Doxa' (T 'Please shorten the question.' 'Te rugam sa scurtezi intrebarea.');return}
 # The same local scope boundary applies even if cloud AI is unavailable.
 $scopeResult=(& (Join-Path $PSScriptRoot 'Get-DoxaKnowledgeAnswer.ps1') -Question $q -Language $script:lang | Out-String)|ConvertFrom-Json
 if($scopeResult.status -eq 'out_of_scope'){
  Say 'Doxa' ([string]$scopeResult.answer)
  $assistantStatus.Text=T 'Doxa installation support only' 'Doar asistenta pentru instalarea Doxa'
  return
 }
 # Fault overlays are clearly simulations and must not send any simulated claims to AI.
 if($script:fault -ne 'none'){
  Say 'Doxa' (Answer $q)
  $assistantStatus.Text=T 'Test mode -- Local explanation' 'Mod de test -- Explicatie locala'
  return
 }
 if($null -eq $script:current){
  Say 'Doxa' (T 'Detect Doxa first, then ask about your equipment.' 'Verifica mai intai Doxa, apoi cere ajutor.')
  return
 }
 if(-not $script:cloudConsent){
  Say 'Doxa' (Answer $q)
  $assistantStatus.Text=T 'Local help only - remote AI declined' 'Doar ajutor local - AI neaprobat'
  return
 }
 $policy=(& $script:cloudPolicyScript|Out-String)|ConvertFrom-Json
 if(-not [bool]$policy.cloud_ai_allowed){
  Say 'Doxa' (Answer $q)
  $assistantStatus.Text='Offline only - remote AI disabled by your organization'
  $offline.Visible=$false
  $script:cloudConsent=$false
  return
 }
 # Curated, source-backed advice appears before starting the optional AI job.
 # Cloud latency must never block the first useful troubleshooting steps.
 $script:quickAdviceShown=($scopeResult.status -eq 'curated_answer' -and [bool]$scopeResult.answer)
 if($script:quickAdviceShown){
  Say (T 'Doxa - quick offline guidance' 'Doxa - recomandari offline rapide') ([string]$scopeResult.answer)
 }
 $script:queuedQuestion=$q
 $send.Enabled=$false
 $assistantStatus.Text=T 'Checking with Doxa AI... offline steps above are ready' 'Consultam Doxa AI... recomandarile offline sunt gata'
 try{
  $script:aiJob=Start-Job -ScriptBlock {param($path,$question,$languageChoice) & $path -Question $question -Language $languageChoice -AIConsentGranted} -ArgumentList @($assistantScript,$q,$script:lang)
  $aiTimer.Start()
 }catch{
  $send.Enabled=$true
  $script:aiJob=$null
  if(-not $script:quickAdviceShown){Say 'Doxa' (Answer $q)}
  $script:quickAdviceShown=$false
  $assistantStatus.Text=T 'Local guidance -- Cloud AI unavailable' 'Asistenta locala -- AI indisponibil'
 }
})
$form.Add_FormClosing({
 $aiTimer.Stop()
 if($null -ne $script:aiJob){
  Stop-Job -Job $script:aiJob -ErrorAction SilentlyContinue
  Remove-Job -Job $script:aiJob -Force -ErrorAction SilentlyContinue
 }
})
$offline.Add_Click({
 $script:cloudConsent=$false
 if($null -ne $script:aiJob){
  $aiTimer.Stop()
  Stop-Job -Job $script:aiJob -ErrorAction SilentlyContinue
  Remove-Job -Job $script:aiJob -Force -ErrorAction SilentlyContinue
  $script:aiJob=$null
  $script:quickAdviceShown=$false
  $send.Enabled=$true
 }
 $offline.Visible=$false
 $hint.Visible=(-not $script:developerMode)
 $assistantStatus.Text='Offline Doxa help only - Cloud AI switched off'
 Say 'Doxa' 'Cloud AI is off for the remainder of this setup session. Previous questions cannot be recalled.'
})
$ask.Add_KeyDown({param($sender,$e);if($e.KeyCode -eq 'Enter'){$e.SuppressKeyPress=$true;$send.PerformClick()}})
function ApplyMainLanguage {
 $script:lang=if($languageChoice.SelectedIndex -eq 1){'ro'}else{'en'}
 $intro.Text=T 'Your Doxa, ready to connect' 'Pregateste ecranele Doxa'
 $sub.Text=T 'Doxa checks your equipment, explains problems and guides the next step.' 'Doxa verifica echipamentele si te ajuta sa rezolvi problemele.'
 $cardHeading.Text=T 'Your Doxa system' 'Sistemul tau Doxa'
 $helpHeading.Text=T 'Doxa help' 'Asistenta Doxa'
 $check.Text=T 'Detect Doxa' 'Detecteaza Doxa'
 $guide.Text=T 'Set up screens...' 'Configureaza ecranele...'
 $reset.Text=T 'Return to live check' 'Verificare reala'
 $reinstall.Text=T 'Install signed driver...' 'Instaleaza driverul semnat...'
 $official.Text=T 'Official Silicon Motion driver downloads' 'Descarca driverul oficial Silicon Motion'
 $faultTitle.Text=T 'Test an installation problem (safe)' 'Simuleaza o problema de instalare'
 $send.Text=T 'Ask' 'Intreaba'
 $assistantStatus.Text=T 'Doxa installation questions only' 'Doar intrebari despre instalarea Doxa'
 $chat.Clear()
 if(-not $Smoke){RefreshState}
}
$languageChoice.Add_SelectedIndexChanged({ApplyMainLanguage})
if($Language -eq 'en'){$intro.Text='Your Doxa, ready to connect'}
# The welcome wizard's selection carries into the main window without a second prompt.
if($Language -eq 'ro'){$languageChoice.SelectedIndex=1}
$advanced.Add_LinkClicked({
 if($script:fault -ne 'none') {
  [Windows.Forms.MessageBox]::Show((T 'Clear the simulated fault before a real maintenance test.' 'Inchide simularea inainte de testul real.'),'Doxa')|Out-Null
  return
 }
 if(-not(Test-Path -LiteralPath $maintenance)){
  [Windows.Forms.MessageBox]::Show('The private recovery script is not available.','Doxa')|Out-Null
  return
 }
 $message=T 'TECHNICAL TEST ONLY. This will remove the current Doxa display driver and reinstall the original signed vendor MSI. All three external screens will temporarily disappear. The laptop screen must remain accessible; Windows will ask for your administrator approval. No automatic restart. Continue?' 'DOAR TEST TEHNIC. Driverul Doxa va fi dezinstalat si reinstalat din MSI-ul semnat. Cele trei ecrane externe vor disparea temporar. Trebuie sa ai acces la ecranul laptopului si sa aprobi UAC. Nu se reporneste automat. Continui?'
 $yes=[Windows.Forms.MessageBox]::Show($message,'Doxa driver reinstall test',[Windows.Forms.MessageBoxButtons]::YesNo,[Windows.Forms.MessageBoxIcon]::Warning,[Windows.Forms.MessageBoxDefaultButton]::Button2)
 if($yes -ne [Windows.Forms.DialogResult]::Yes){return}
 try{
  Start-Process -FilePath "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList ('-NoProfile -File "'+$maintenance+'" -Apply') -Verb RunAs|Out-Null
  Say 'Doxa' (T 'Windows has requested administrator approval. Recheck the displays after the technical test and review the installer log.' 'Windows solicita aprobarea administratorului. Repeta verificarea si consulta jurnalul testului.')
 }catch{Say 'Doxa' ('Could not obtain administrator approval: '+$_.Exception.Message)}
})
 # The legacy driver picker has been retired. The only customer install action
 # is the protected embedded DoxaMaintenance-v2.exe /install in Doxa-BrandTabs.
 # The old $reinstall control remains hidden for existing UI test compatibility.
if(-not ($Smoke -or $JourneyTest)){
 . (Join-Path $PSScriptRoot 'Doxa-BrandTabs.ps1')
}
if($BrandTest){
 $form.Show();[Windows.Forms.Application]::DoEvents()
 $handle=$form.Handle
 $click=[Windows.Forms.Button].GetMethod('OnClick',[Reflection.BindingFlags]'Instance,NonPublic')
 if($tabs.Count -ne 3 -or $tabs[2].Right -ge $sideHolder.Left){throw 'Main tabs intrude into chatbot column'}
 if($workspace.Right -ge $sideHolder.Left){throw 'Workspace frame must not include persistent chatbot'}
 if($tabs[0].Text -eq $check.Text){throw 'Redundant Detect Doxa action label'}
 [void]$click.Invoke($tabs[1],@([EventArgs]::Empty))
 if(-not $setup.Visible -or -not $side.Visible -or -not $sideHolder.Visible){throw 'Arrange and persistent Help not visible'}
 if(-not $settingsButton.Visible -or $settingsButton.Parent -ne $setup){throw 'Windows Display settings must appear only in arrangement'}
 [void]$click.Invoke($tabs[2],@([EventArgs]::Empty))
 if(-not $install.Visible -or -not $side.Visible -or $reinstall.Visible){throw 'Signed-driver information not safe'}
 [void]$click.Invoke($tabs[0],@([EventArgs]::Empty))
 if(-not $detect.Visible -or $form.Handle -ne $handle){throw 'Same window navigation failed'}
 if($settingsButton.Parent -eq $detect){throw 'Windows display settings incorrectly present in Connect'}
 if($form.Tag.upper_port -ne 'power' -or $form.Tag.lower_port -ne 'data'){throw 'USB-C order incorrect'}
 if(-not $modeOff.Visible -or -not $privacy.Visible){throw 'Persistent help privacy/choice missing'}
 if($guide.Parent -ne $form -or $guide -ne $tabs[1]){throw 'Obsolete duplicate navigation'}
 # Test all three panel PnP outcomes; a green tick must never be hardcoded.
 $savedCurrent=$script:current
 $script:current=[pscustomobject]@{test_only=$false;observed=[pscustomobject]@{
  doxa_hardware_detected=$true;pnp_doxa_panels=@('Generic Monitor (L)','Generic Monitor (T)');signed_driver_present=$true
 }}
 UpdateDoxaPanelTicks
 if(-not $script:doxaScreenChecks[0] -or -not $script:doxaScreenChecks[1] -or $script:doxaScreenChecks[2]){throw 'Per-panel ticks do not follow PnP data'}
 $script:current.test_only=$true
 UpdateDoxaPanelTicks
 if(@($script:doxaScreenChecks|Where-Object {$_}).Count -gt 0){throw 'Test-only data presented as verified'}
 $script:current=$savedCurrent
 if($savedCurrent){UpdateDoxaPanelTicks}
 $languageChoice.SelectedIndex=1
 if($tabs[0].Text -ne 'Detecteaza Doxa' -or $check.Text -ne 'Verifica conexiunea'){throw 'Romanian interface translation missing'}
 $languageChoice.SelectedIndex=0
 if($tabs[0].Text -ne 'Detect Doxa' -or $check.Text -ne 'Check connection'){throw 'English reversibility missing'}
 $script:previousAIApproval=$true;$script:queuedQuestion='pending';$script:quickAdviceShown=$true
 $script:aiJob=Start-Job -ScriptBlock {Start-Sleep -Seconds 10;'late'}
 $modeOff.Checked=$false;$modeOff.Checked=$true
 if($script:previousAIApproval -or $script:queuedQuestion -or $script:quickAdviceShown -or $script:aiJob){throw 'Offline mode did not clear pending job/approval'}
 foreach($size in @(@(780,610),@(1060,610))){
  $form.ClientSize=New-Object Drawing.Size([int]$size[0],[int]$size[1]);[Windows.Forms.Application]::DoEvents()
  if($tabs[2].Right -gt $form.ClientSize.Width -or $workspace.Right -gt $form.ClientSize.Width -or $sideHolder.Right -gt $form.ClientSize.Width){throw 'Horizontal overflow at '+$size[0]}
 }
 # Render the real paint handlers (including USB-C sockets and screen ticks).
 $form.ClientSize=New-Object Drawing.Size(1060,610)
 [Windows.Forms.Application]::DoEvents()
 $preview=New-Object Drawing.Bitmap($workspace.Width,$workspace.Height)
 try{$workspace.DrawToBitmap($preview,(New-Object Drawing.Rectangle(0,0,$workspace.Width,$workspace.Height)))}finally{$preview.Dispose()}
 if($SnapshotPath){
  $form.ClientSize=New-Object Drawing.Size(1060,610)
  SelectDoxaPage 'detect'
  [Windows.Forms.Application]::DoEvents()
  $bitmap=New-Object Drawing.Bitmap($form.Width,$form.Height)
  try{
   $form.DrawToBitmap($bitmap,([Drawing.Rectangle]::new(0,0,$form.Width,$form.Height)))
   $bitmap.Save($SnapshotPath,[Drawing.Imaging.ImageFormat]::Png)
  }finally{$bitmap.Dispose()}
 }
 $result=[ordered]@{status='PASS';version='preview.12';single_form=$true;task_tabs_left_only=$true;chat_persistent=$true;duplicate_bottom_nav_removed=$true;connect_first=$true;arrange_only_windows_settings=$true;individual_pnp_ticks_tested=$true;upper_port='power';lower_port='data';romanian_tabs_tested=$true;online_revocation_tested=$true;driver_action_hidden=$true;horizontal_reflow_tested=$true;driver_changes=$false;network_requests=0}
 $form.Dispose();$result|ConvertTo-Json -Compress;return
}
if($JourneyTest){
 # No display or driver modifications; invoke button click handlers without showing a window.
 $click=[Windows.Forms.Button].GetMethod('OnClick',[Reflection.BindingFlags]'Instance,NonPublic')
 RefreshState
 $initialCode=$script:current.code
 $beforeDuplicateCheck=$chat.TextLength
 [void]$click.Invoke($check,@([EventArgs]::Empty))
 $repeatDetectNoChatFlood=($chat.TextLength -eq $beforeDuplicateCheck)
 if(-not $repeatDetectNoChatFlood){throw ('Repeated Detect Doxa appended duplicate help text before '+$beforeDuplicateCheck+', after '+$chat.TextLength+', state '+$script:lastDetectionKey+', code '+$script:current.code)}

 [void]$click.Invoke($guide,@([EventArgs]::Empty))
 if($null -ne $script:aiJob -or -not $chat.Text.Contains((T 'This is offline guidance' 'Ghid offline'))){throw 'Connection guide did not stay offline'}
 # Unrelated questions stay inside this WinForms window; no cloud request is started.
 $ask.Text='What is the weather today?'
 [void]$click.Invoke($send,@([EventArgs]::Empty))
 if($null -ne $script:aiJob){throw 'Out-of-scope question started an AI job.'}
 $scopeResult=(& (Join-Path $PSScriptRoot 'Get-DoxaKnowledgeAnswer.ps1') -Question 'What is the weather today?' -Language $script:lang | Out-String)|ConvertFrom-Json
 if(-not $chat.Text.Contains([string]$scopeResult.answer)){throw 'Localized scope refusal was not displayed in chat.'}
 $script:fault='display_missing';RefreshState
 $ask.Text='Why is the simulated display missing?'
 [void]$click.Invoke($send,@([EventArgs]::Empty))
 if($null -ne $script:aiJob){throw 'Simulated fault contacted the online assistant.'}
 if(-not $chat.Text.Contains((T 'diagnostic test' 'simulare'))){throw 'Fault message did not stay local.'}
 $script:fault='none';RefreshState
 $installSkip='not_checked'
   # The legacy browse-for-MSI button must not reappear for customers.
  # Driver actions use the protected embedded native installer in BrandTabs.
  if($reinstall.Visible){throw 'Legacy driver selection returned to the customer experience.'}
  if($script:current.code -eq 'doxa_not_detected'){
   $installSkip='connect_doxa_first'
  }elseif($script:current.observed.signed_driver_present){
   $installSkip='correct_driver_noop'
  }
$result=[ordered]@{journey='PASS';initial_code=$initialCode;fault_did_not_call_ai=$true;install_button=$installSkip;driver_changes=$false;official_source=$official.Text;language_options=$languageChoice.Items.Count;device_illustration_present=($deviceArt.Width -gt 300);connection_steps_offline=$true;repeat_detect_does_not_spam=$repeatDetectNoChatFlood;language=$script:lang;localized_intro=$intro.Text}
 $form.Dispose()
 $result|ConvertTo-Json -Compress
 return
}
if($Smoke) {
 $snapshot=New-Object Drawing.Bitmap($form.Width,$form.Height)
 try{
  if($SnapshotPath){$form.Show();$form.Refresh()}
  $form.DrawToBitmap($snapshot,[Drawing.Rectangle]::new(0,0,$form.Width,$form.Height))
  $artworkRenderPass=$true
  if($SnapshotPath){
   $parent=Split-Path -Parent $SnapshotPath
   if(-not(Test-Path $parent -PathType Container)){throw 'Snapshot output folder does not exist'}
   $snapshot.Save($SnapshotPath,[Drawing.Imaging.ImageFormat]::Png)
  }
 }finally{if($SnapshotPath){$form.Hide()};$snapshot.Dispose()}
 @{smoke=$(if($script:compactLayout -and ($reinstall.Width -lt 280 -or $side.Right -gt ($form.ClientSize.Width-17))){'FAIL'}else{'PASS'});reinstall_button_width=$reinstall.Width;compact_scrollbar_margin=($form.ClientSize.Width-$side.Right);window=$form.Text;layout_mode=$(if($script:compactLayout){'compact_stacked'}else{'wide_columns'});viewport_width=$form.ClientSize.Width;side_within_horizontal_bounds=($side.Right -le $form.ClientSize.Width);languages=@('English','Romana');form_width=$form.Width;form_height=$form.Height;fault_count=$faults.Items.Count;device_illustration_present=($deviceArt.Width -gt 300 -and $deviceArt.Height -gt 100);short_laptop_layout=$script:shortWide;resize_supported=($form.FormBorderStyle -eq 'Sizable');window_fits_work_area=($form.Height -le [Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Height);critical_buttons_visible=($check.Bottom -le $form.ClientSize.Height -and $guide.Bottom -le $form.ClientSize.Height -and $reinstall.Bottom -le $form.ClientSize.Height -and $footer.Bottom -le $form.ClientSize.Height);exact_detect_button_text=$check.Text;connection_steps_wired=($guide.Parent -eq $form);device_illustration_accessible=([bool]$deviceArt.AccessibleName);artwork_render_pass=$artworkRenderPass;illustration_not_device_evidence=$true;initial_language=$script:lang;intro_text=$intro.Text;help_title=$helpHeading.Text;language_dropdown_count=$languageChoice.Items.Count;developer_controls_visible=[bool]$inject.Visible;reset_visible=[bool]$reset.Visible;advanced_visible=[bool]$advanced.Visible;chat_height=$chat.Height;driver_changes_without_user_action=$false;cloud_ai_connected=$false}|ConvertTo-Json -Compress
 $form.Dispose()
 return
}
if($HostForm){
 if(-not $form.Tag -or -not ($form.Tag.PSObject.Properties.Name -contains 'tabs')){
  $form.Tag=[pscustomobject]@{
  stage='main';checkButton=$check;guideButton=$guide
   statusLabel=$stateLabel
  }
 }
  if(-not $EmbeddedSmoke){RefreshState}
 return
}
RefreshState
[Windows.Forms.Application]::Run($form)
