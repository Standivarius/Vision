# Doxa Preview 10: Windows Forms customer visual layer.
# Driver and diagnostic actions remain in Start-DoxaSetup.ps1.
$red=[Drawing.Color]::FromArgb(165,27,51)
$ink=[Drawing.Color]::FromArgb(24,32,50)
$line=[Drawing.Color]::FromArgb(215,220,226)
$white=[Drawing.Color]::White
$workArea=[Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$form.ClientSize=New-Object Drawing.Size(1060,[Math]::Min(615,[Math]::Max(500,$workArea.Height-48)))
$form.MinimumSize=New-Object Drawing.Size(770,490)
$form.AutoScroll=$true
$form.BackColor=$white
$form.Text='Standivarius | Doxa Setup - TEST preview.10'
$form.Controls.Clear()
function BLabel($t,$x,$y,$w,$h,$size=10,$bold=$false) {
 $c=New-Object Windows.Forms.Label;$c.SetBounds($x,$y,$w,$h);$c.Text=$t
 $c.ForeColor=$ink;$c.Font=New-Object Drawing.Font('Segoe UI',$size,$(if($bold){[Drawing.FontStyle]::Bold}else{[Drawing.FontStyle]::Regular}))
 return $c
}
function BButton($t,$x,$y,$w,$h) {
 $b=New-Object Windows.Forms.Button;$b.SetBounds($x,$y,$w,$h);$b.Text=$t
 $b.FlatStyle='Flat';$b.FlatAppearance.BorderColor=$line;$b.FlatAppearance.BorderSize=1
 $b.BackColor=$white;$b.ForeColor=$ink
 return $b
}
$logo=BLabel 'standivarius' 22 12 240 41 22 $true;$logo.ForeColor=$red;$form.Controls.Add($logo)
$logoFile=Join-Path $PSScriptRoot 'assets\standivarius-official-logo.png'
if(Test-Path -LiteralPath $logoFile){
 $logo.Visible=$false
 $brandPicture=New-Object Windows.Forms.PictureBox
 $logoStream=New-Object IO.MemoryStream(,[IO.File]::ReadAllBytes($logoFile))
 $rawLogo=[Drawing.Image]::FromStream($logoStream)
 $brandPicture.Image=New-Object Drawing.Bitmap($rawLogo)
 $rawLogo.Dispose();$logoStream.Dispose()
 $brandPicture.SizeMode='Zoom'
 $brandPicture.SetBounds(22,13,235,36)
 $brandPicture.AccessibleName='Standivarius official logo'
 $form.Controls.Add($brandPicture)
}
$form.Controls.Add((BLabel '|  Doxa Setup' 265 19 245 31 17))
$languageChoice.SetBounds(877,20,151,30);$form.Controls.Add($languageChoice)
$tabs=@((BButton 'Detect Doxa' 19 69 253 52),(BButton 'Set up screens' 276 69 253 52),(BButton 'Install signed driver' 533 69 252 52))
$form.Controls.AddRange($tabs)
$frame=New-Object Windows.Forms.Panel;$frame.SetBounds(19,120,1025,472);$form.Controls.Add($frame)
$frame.Add_Paint({param($s,$e);$p=New-Object Drawing.Pen ([Drawing.Color]::FromArgb(165,27,51)),1.5;try{$e.Graphics.DrawRectangle($p,1,1,$s.Width-3,$s.Height-3)}finally{$p.Dispose()}})
$left=New-Object Windows.Forms.Panel;$left.SetBounds(12,12,662,443);$frame.Controls.Add($left)
$right=New-Object Windows.Forms.Panel;$right.SetBounds(691,12,313,443);$frame.Controls.Add($right)
$divider=New-Object Windows.Forms.Panel;$divider.SetBounds(683,14,1,439);$divider.BackColor=$line;$frame.Controls.Add($divider)
function Diagram($x,$y,$w,$h) {
 $p=New-Object Windows.Forms.Panel;$p.SetBounds($x,$y,$w,$h)
 $p.AccessibleName='Screen 2 left, Screen 3 centre, Screen 4 right; laptop Screen 1 below centre.'
 $p.Add_Paint({
  param($s,$e);$g=$e.Graphics;$g.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.ScaleTransform([float]($s.Width/620.0),[float]($s.Height/205.0))
  $pen=New-Object Drawing.Pen ([Drawing.Color]::FromArgb(45,50,58)),2.5
  $glass=New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(245,247,249))
  $brush=New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(24,32,50))
  $font=New-Object Drawing.Font('Segoe UI',12,[Drawing.FontStyle]::Bold)
  try {
   foreach($i in 0..2){$sx=14+$i*200;$g.FillRectangle($glass,$sx,4,191,97);$g.DrawRectangle($pen,$sx,4,191,97);$g.DrawString(('Screen '+($i+2)),$font,$brush,$sx+49,42)}
   $g.FillRectangle($glass,237,120,153,67);$g.DrawRectangle($pen,237,120,153,67);$g.DrawString('Screen 1',$font,$brush,274,142)
   $g.DrawLine($pen,222,192,402,192)
  }finally{foreach($o in @($pen,$glass,$brush,$font)){$o.Dispose()}}
 })
 return $p
}
$detect=New-Object Windows.Forms.Panel;$detect.Dock='Fill';$left.Controls.Add($detect)
$detect.Controls.Add((BLabel 'Detect Doxa' 10 5 410 37 18 $true))
$card.BorderStyle='None';$card.SetBounds(6,44,650,354);$detect.Controls.Add($card)
$cardHeading.Visible=$false;$deviceArt.Visible=$false;$connectionBadge.SetBounds(429,4,202,25)
$draw=Diagram 8 30 618 206;$card.Controls.Add($draw)
for($i=0;$i -lt 3;$i++){$rows[$i].SetBounds(11,(240+$i*25),611,23);$rows[$i].Font=New-Object Drawing.Font('Segoe UI',9)}
$stateLabel.SetBounds(11,317,615,28);$stateLabel.Font=New-Object Drawing.Font('Segoe UI',9)
$check.SetBounds(12,397,167,41);$check.BackColor=$red;$check.ForeColor=$white;$detect.Controls.Add($check)
$toSetup=BButton 'Set up screens' 193 397 180 41;$detect.Controls.Add($toSetup)
$setup=New-Object Windows.Forms.Panel;$setup.Dock='Fill';$setup.Visible=$false;$left.Controls.Add($setup)
$sub1=BButton 'Connect Doxa' 10 4 236 43;$sub2=BButton 'Arrange four screens' 251 4 237 43;$setup.Controls.AddRange(@($sub1,$sub2))
$connect=New-Object Windows.Forms.Panel;$connect.SetBounds(8,52,646,387);$setup.Controls.Add($connect)
$arrange=New-Object Windows.Forms.Panel;$arrange.SetBounds(8,52,646,387);$arrange.Visible=$false;$setup.Controls.Add($arrange)
$connect.Controls.Add((BLabel '1. Connect the supplied power adapter' 10 3 624 32 13 $true))
$connect.Controls.Add((BLabel 'UPPER USB-C port behind the central screen. Check it is secure.' 10 33 624 29 10))
$connect.Controls.Add((BLabel '2. Connect the USB-C data cable' 10 75 624 31 13 $true))
$connect.Controls.Add((BLabel 'LOWER USB-C port, then connect the other end to your computer.' 10 104 624 30 10))
$portDraw=New-Object Windows.Forms.Panel;$portDraw.SetBounds(16,145,344,165)
$portDraw.AccessibleName='Upper USB-C port power; lower USB-C port signal/data.'
$portDraw.Add_Paint({
 param($s,$e);$g=$e.Graphics;$g.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
 $b=New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(73,79,88))
 $hole=New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(15,20,27))
 $pen=New-Object Drawing.Pen ([Drawing.Color]::FromArgb(165,27,51)),2
 $textBrush=New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(24,32,50))
 $font=New-Object Drawing.Font('Segoe UI',11,[Drawing.FontStyle]::Bold)
 try{
  $g.FillRectangle($b,18,8,103,150)
  foreach($yy in @(49,109)){$g.FillEllipse($hole,79,$yy,27,13);$g.DrawLine($pen,108,$yy+6,151,$yy+6)}
  $g.DrawString('POWER (upper)',$font,$textBrush,158,46)
  $g.DrawString('DATA (lower)',$font,$textBrush,158,106)
 }finally{foreach($o in @($b,$hole,$pen,$textBrush,$font)){$o.Dispose()}}
})
$connect.Controls.Add($portDraw)
$emphasis=BLabel 'Power first, then USB-C data.' 376 182 252 74 13 $true;$emphasis.ForeColor=$red;$connect.Controls.Add($emphasis)
$open1=BButton 'Open Windows Display settings' 10 335 312 40;$connect.Controls.Add($open1)
$open1.Add_Click({Start-Process 'ms-settings:display'|Out-Null})
$arrange.Controls.Add((BLabel 'Recommended four-screen layout' 12 3 620 37 16 $true))
$arrange.Controls.Add((Diagram 9 45 617 214))
$arrange.Controls.Add((BLabel 'Move the pointer from laptop Screen 1 up to Screen 3, then left or right.' 11 263 623 28 10))
$arrange.Controls.Add((BLabel 'Use Identify in Windows before arranging actual display numbers.' 11 296 623 25 10))
$open2=BButton 'Open Windows Display settings' 10 335 312 40;$arrange.Controls.Add($open2)
$open2.Add_Click({Start-Process 'ms-settings:display'|Out-Null})
$install=New-Object Windows.Forms.Panel;$install.Dock='Fill';$install.Visible=$false;$left.Controls.Add($install)
$install.Controls.Add((BLabel 'Install signed Doxa driver' 18 16 620 42 18 $true))
$install.Controls.Add((BLabel 'Only install when the signed driver is missing and device eligibility is verified.' 18 93 620 54 11))
$install.Controls.Add((BLabel 'A healthy existing Silicon Motion driver must NOT be reinstalled.' 18 172 620 58 11))
$reinstall.SetBounds(18,271,300,43);$reinstall.BackColor=$red;$reinstall.ForeColor=$white;$install.Controls.Add($reinstall)
$official.SetBounds(19,326,475,26);$official.LinkColor=$red;$install.Controls.Add($official)
$install.Controls.Add((BLabel 'This preview does not bundle a vendor driver, change topology or install silently.' 18 388 625 39 10))
$side.BorderStyle='None';$side.SetBounds(0,0,313,443);$right.Controls.Add($side)
$helpHeading.SetBounds(12,4,287,33);$assistantStatus.SetBounds(12,39,287,24)
$offline.Visible=$false;$hint.Visible=$false
$modeOff=New-Object Windows.Forms.RadioButton;$modeOff.SetBounds(12,70,139,28);$modeOff.Text='Offline help';$modeOff.Checked=(-not $script:cloudConsent)
$modeOn=New-Object Windows.Forms.RadioButton;$modeOn.SetBounds(158,70,144,28);$modeOn.Text='Online AI';$modeOn.Checked=[bool]$script:cloudConsent
$side.Controls.AddRange(@($modeOff,$modeOn))
$chat.SetBounds(12,106,289,246);$ask.SetBounds(12,361,193,34);$send.SetBounds(212,361,89,34);$send.BackColor=$red
$side.Controls.Add((BLabel 'AI requires consent; offline help needs no internet.' 12 407 291 30 9))
$script:previousAIApproval=[bool]$script:cloudConsent
$modeOff.Add_CheckedChanged({
 if(-not $modeOff.Checked){return}
 $script:cloudConsent=$false
 if($null -ne $script:aiJob){$aiTimer.Stop();Stop-Job $script:aiJob -ErrorAction SilentlyContinue;Remove-Job $script:aiJob -Force -ErrorAction SilentlyContinue;$script:aiJob=$null;$send.Enabled=$true}
 $assistantStatus.Text='Offline help selected'
})
$modeOn.Add_CheckedChanged({
 if(-not $modeOn.Checked){return}
 $policy=(& $script:cloudPolicyScript|Out-String)|ConvertFrom-Json
 if(-not [bool]$policy.cloud_ai_allowed){$modeOff.Checked=$true;return}
 if(-not $script:previousAIApproval){
  $msg='Online AI sends your typed question and limited Windows/Doxa diagnostics over HTTPS. No screenshots or raw USB identifiers. Allow online AI for this session?'
  $answer=[Windows.Forms.MessageBox]::Show($msg,'Doxa cloud AI permission',[Windows.Forms.MessageBoxButtons]::YesNo,[Windows.Forms.MessageBoxIcon]::Question,[Windows.Forms.MessageBoxDefaultButton]::Button2)
  if($answer -ne [Windows.Forms.DialogResult]::Yes){$modeOff.Checked=$true;return}
  $script:previousAIApproval=$true
 }
 $script:cloudConsent=$true;$assistantStatus.Text='Online Doxa AI selected'
})
$context=New-Object Windows.Forms.Panel;$context.Dock='Fill';$context.Visible=$false;$right.Controls.Add($context)
$contextHeading=BLabel '' 12 7 291 54 15 $true;$context.Controls.Add($contextHeading)
$contextBody=BLabel '' 12 73 288 288 11;$context.Controls.Add($contextBody)
$contextButton=BButton 'Open Windows Display settings' 12 384 289 42;$context.Controls.Add($contextButton)
$contextButton.Add_Click({Start-Process 'ms-settings:display'|Out-Null})
function SelectSub($s){
 $isArrange=$s -eq 'arrange';$connect.Visible=-not $isArrange;$arrange.Visible=$isArrange
 foreach($b in @($sub1,$sub2)){$chosen=$b -eq $(if($isArrange){$sub2}else{$sub1});$b.BackColor=if($chosen){$red}else{$white};$b.ForeColor=if($chosen){$white}else{$ink}}
 $contextHeading.Text=if($isArrange){'How to arrange your screens'}else{'How to connect Doxa'}
 $contextBody.Text=if($isArrange){
  (@('1. Open Windows Display settings, then Identify.','','2. In Multiple displays, choose Extend.','','3. Drag the numbered displays so the laptop is below the centre screen.','','4. Apply; then move the mouse across all four screens.') -join [Environment]::NewLine)
 }else{
  (@('1. Connect supplied power to the UPPER USB-C port behind the centre screen.','','2. Connect the data cable to the LOWER USB-C port, then to the computer.','','3. Detect Doxa to verify the three panels.','','4. Open Windows Display settings for Extend.') -join [Environment]::NewLine)
 }
}
function SelectMain($s){
 foreach($p in @($detect,$setup,$install)){$p.Visible=$false}
 for($i=0;$i -lt 3;$i++){$selected=$i -eq $(switch($s){detect{0}setup{1}install{2}});$tabs[$i].BackColor=if($selected){$red}else{$white};$tabs[$i].ForeColor=if($selected){$white}else{$ink}}
 switch($s){detect{$detect.Visible=$true;$side.Visible=$true;$context.Visible=$false}setup{$setup.Visible=$true;$side.Visible=$false;$context.Visible=$true}install{$install.Visible=$true;$side.Visible=$true;$context.Visible=$false}}
 $frame.Invalidate()
}
$tabs[0].Add_Click({SelectMain 'detect'});$tabs[1].Add_Click({SelectMain 'setup'});$tabs[2].Add_Click({SelectMain 'install'})
$sub1.Add_Click({SelectSub 'connect'});$sub2.Add_Click({SelectSub 'arrange'})
$toSetup.Add_Click({SelectMain 'setup';SelectSub 'connect'})
SelectSub 'connect';SelectMain 'detect'
$form.Tag=[pscustomobject]@{stage='main';checkButton=$check;guideButton=$guide;statusLabel=$stateLabel;tabs=$tabs;workspace=$frame;upper_port='power';lower_port='data';online_toggle=$modeOn;offline_toggle=$modeOff}
