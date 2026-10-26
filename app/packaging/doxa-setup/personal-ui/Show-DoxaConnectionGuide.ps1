param([ValidateSet('en','ro')][string]$Language='en',[System.Windows.Forms.Form]$Owner=$null,[switch]$Smoke)
# An offline guide. No automatic screen topology or driver changes.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$ro=$Language -eq 'ro'
function T([string]$en,[string]$romanian){if($ro){$romanian}else{$en}}
$window=New-Object System.Windows.Forms.Form
$window.Text=T 'Doxa - Connect and arrange screens' 'Doxa - Conectare si aranjare ecrane'
$window.StartPosition='CenterParent'
$window.FormBorderStyle='Sizable'
$window.MinimumSize=New-Object Drawing.Size(530,420)
$area=[Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$window.ClientSize=New-Object Drawing.Size([Math]::Min(760,[Math]::Max(510,$area.Width-50)),[Math]::Min(550,[Math]::Max(350,$area.Height-65)))
$window.Font=New-Object Drawing.Font('Segoe UI',10)
$tabs=New-Object Windows.Forms.TabControl
$tabs.Dock='Fill'
$connect=New-Object Windows.Forms.TabPage
$connect.Text=T '1. Connect Doxa' '1. Conecteaza'
$connect.AutoScroll=$true
$layout=New-Object Windows.Forms.TabPage
$layout.Text=T '2. Arrange four screens' '2. Aranjeaza 4 ecrane'
$layout.AutoScroll=$true
[void]$tabs.TabPages.Add($connect);[void]$tabs.TabPages.Add($layout)
$window.Controls.Add($tabs)
function Label([string]$value,[int]$x,[int]$y,[int]$width,[int]$height,[int]$size=10){
 $l=New-Object Windows.Forms.Label
 $l.Text=$value;$l.SetBounds($x,$y,$width,$height)
 $l.ForeColor=[Drawing.Color]::FromArgb(17,35,59)
 $l.Font=New-Object Drawing.Font('Segoe UI',$size)
 return $l
}
$connect.Controls.Add((Label (T 'Connect the cables, then identify every Windows display' 'Conecteaza cablurile, apoi identifica ecranele Windows') 19 13 680 34 13))
$instructions=New-Object Windows.Forms.TextBox
$instructions.Multiline=$true;$instructions.ReadOnly=$true
$instructions.ScrollBars='Vertical';$instructions.WordWrap=$true
$instructions.SetBounds(20,54,685,327)
$instructions.Anchor='Top,Bottom,Left,Right'
$en=@(
'1. Connect Doxa to its supplied power adapter. Check that the power plug is secure.',
'',
'2. Connect its USB-C DATA cable to a compatible USB port on your computer. Not every USB-C cable or port supports display data.',
'',
'3. Wait for Windows to recognise Silicon Motion USB Display. Do not reinstall a working signed driver.',
'',
'4. Open Windows Display settings with the button below. Under Multiple displays, choose Extend, not Duplicate, if you want separate desktops. Choose Apply.',
'',
'5. Choose Identify in Windows Display settings. Windows shows its OWN screen numbers. They may differ from the Doxa illustration.',
'',
'6. In the next tab, choose the suggested layout or arrange the screens yourself. Drag Windows display rectangles to match where your screens physically sit, then choose Apply.',
'',
'7. Move your pointer and a window across all four screens to check the arrangement.',
'',
'8. Return to Doxa Setup and click Detect Doxa. Three external panels and four extended Windows desktops should be present.',
'',
'If a display is black: check power, the USB data connection and Extend before considering a driver change.'
)
$roLines=@(
'1. Conecteaza Doxa la alimentarea din pachet. Verifica mufa.',
'',
'2. Conecteaza cablul USB-C DE DATE la portul USB compatibil. Nu orice cablu USB-C transmite date pentru ecrane.',
'',
'3. Asteapta ca Windows sa recunoasca dispozitivul Silicon Motion USB Display. Nu reinstala un driver semnat functional.',
'',
'4. Deschide Setari ecran Windows. La Mai multe ecrane, alege Extindere (nu Duplicare), apoi Aplica.',
'',
'5. Alege Identificare. Numerele Windows pot diferi de ilustratia Doxa.',
'',
'6. Alege aranjamentul recomandat sau unul propriu. Muta dreptunghiurile in Windows si apasa Aplica.',
'',
'7. Testeaza miscarea cursorului si a unei ferestre intre cele patru ecrane.',
'',
'8. Revino in Doxa Setup si apasa Detect Doxa.',
'',
'Daca un ecran este negru, verifica alimentarea, cablul de date si Extindere inainte de a modifica driverul.'
)
$instructions.Text=($(
 if($ro){$roLines}else{$en}
) -join [Environment]::NewLine)
$connect.Controls.Add($instructions)
$link=New-Object Windows.Forms.LinkLabel
$link.Text=T 'Open Windows Display settings' 'Deschide Setari ecran Windows'
$link.SetBounds(20,392,420,30)
$link.Anchor='Left,Bottom'
$link.LinkColor=[Drawing.Color]::FromArgb(16,140,137)
$link.AccessibleName='Open Windows Display settings, System Display'
$link.Add_LinkClicked({
 try{Start-Process 'ms-settings:display'|Out-Null}
 catch{[Windows.Forms.MessageBox]::Show((T 'Press Windows + I, System, Display.' 'Apasa Windows + I, Sistem, Ecran.'),'Doxa')|Out-Null}
})
$connect.Controls.Add($link)
$connect.Controls.Add((Label (T 'Offline instructions only - no changes have been applied.' 'Ghid offline - nu s-au aplicat modificari.') 20 438 660 36))
$layout.Controls.Add((Label (T 'Suggested layout - Doxa labels, not Windows monitor numbers' 'Aranjament propus - etichete Doxa, nu numere Windows') 20 14 690 37 13))
$preview=New-Object Windows.Forms.Panel
$preview.SetBounds(20,56,690,132)
$preview.Anchor='Top,Left,Right'
$preview.BackColor=[Drawing.Color]::FromArgb(243,248,252)
$preview.AccessibleName='Four-screen diagram: laptop 1; Doxa left 2; Doxa centre 3; Doxa right 4'
$preview.Add_Paint({
 param($sender,$event)
 $g=$event.Graphics;$g.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
 $g.ScaleTransform(($sender.Width/690.0),1.0)
 $pen=New-Object Drawing.Pen ([Drawing.Color]::FromArgb(32,65,93)),2
 $glass=New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(214,239,244))
 $ink=New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(21,45,66))
 $font=New-Object Drawing.Font('Segoe UI',16,[Drawing.FontStyle]::Bold)
 $small=New-Object Drawing.Font('Segoe UI',10)
 try{
  foreach($a in @(@(17,16,137,70,'1','Laptop'),@(182,8,142,81,'2',$(if($ro){'Stanga'}else{'Left'})),@(352,8,142,81,'3',$(if($ro){'Centru'}else{'Centre'})),@(522,8,142,81,'4',$(if($ro){'Dreapta'}else{'Right'})))){
   $x=[int]$a[0];$y=[int]$a[1];$w=[int]$a[2];$h=[int]$a[3]
   $g.FillRectangle($glass,$x,$y,$w,$h)
   $g.DrawRectangle($pen,$x,$y,$w,$h)
   $g.DrawString([string]$a[4],$font,$ink,$x+($w/2)-9,$y+18)
   $g.DrawString([string]$a[5],$small,$ink,$x+12,100)
   if($a[4] -eq '1'){$g.DrawLine($pen,$x-8,92,$x+$w+8,92)}
  }
 }finally{foreach($x in @($pen,$glass,$ink,$font,$small)){$x.Dispose()}}
})
$layout.Controls.Add($preview)
$recommended=New-Object Windows.Forms.RadioButton
$recommended.SetBounds(20,208,630,36)
$recommended.Text=T 'Use recommended Doxa layout' 'Folosesc aranjamentul Doxa recomandat'
$recommended.Checked=$true
$recommended.AccessibleName='Recommended Doxa physical layout'
$layout.Controls.Add($recommended)
$custom=New-Object Windows.Forms.RadioButton
$custom.SetBounds(20,252,630,36)
$custom.Text=T 'I will arrange screens myself' 'Voi aranja ecranele personalizat'
$layout.Controls.Add($custom)
$details=Label '' 26 303 670 84 10
$details.Anchor='Left,Right'
$layout.Controls.Add($details)
$changeText={
 $details.Text=if($recommended.Checked){
  T 'The product suggests laptop 1, Doxa left 2, centre 3 and right 4. In Windows, select Identify first. Drag the actual Windows numbered rectangles to match these physical positions. Only Windows settings can apply changes.' 'Doxa propune laptop 1, stanga 2, centru 3, dreapta 4. In Windows, alege Identificare, apoi muta dreptunghiurile reale. Doar Windows aplica modificarile.'
 }else{
  T 'Use Windows Display settings to choose your own layout. Select Identify, drag the rectangles, choose Extend and Apply. Doxa Setup does not move your screens automatically.' 'In Setari Windows poti alege aranjamentul propriu. Alege Identificare, muta dreptunghiurile, Extindere si Aplica. Doxa Setup nu schimba ecranele automat.'
 }
}
$recommended.Add_CheckedChanged($changeText);$custom.Add_CheckedChanged($changeText);& $changeText
$openSettings=New-Object Windows.Forms.Button
$openSettings.SetBounds(20,409,295,42)
$openSettings.Anchor='Bottom,Left'
$openSettings.Text=T 'Open Windows Display settings' 'Deschide Setari ecran Windows'
$openSettings.Add_Click({Start-Process 'ms-settings:display'|Out-Null})
$layout.Controls.Add($openSettings)
$layout.Controls.Add((Label (T 'Preview only: no display changes are applied here.' 'Doar previzualizare; nu se modifica ecranele.') 328 412 350 40))
if($Smoke){
 [ordered]@{
  status='PASS';language=$Language;tabs=$tabs.TabCount;settings_uri='ms-settings:display'
  recommended_default=[bool]$recommended.Checked;custom_available=$true
  four_screen_artwork=[bool]$preview.AccessibleName;no_topology_changes=$true
  no_driver_actions=$true;resize_supported=($window.FormBorderStyle -eq 'Sizable')
 }|ConvertTo-Json -Compress
 $window.Dispose();return
}
try{if($Owner){[void]$window.ShowDialog($Owner)}else{[void]$window.ShowDialog()}}finally{$window.Dispose()}
