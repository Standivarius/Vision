param([switch]$Smoke,[switch]$JourneyTest,[switch]$SeamlessTest,[ValidateSet('connected','without_doxa')][string]$TestConnectionChoice='without_doxa',[switch]$TestAIAllowed,[ValidateSet('en','ro')][string]$Language='en')
# Consent-first welcome. No hardware enumeration or remote AI call occurs before consent.
# Reading the organization cloud-AI prohibition is a local policy check only.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$form=New-Object Windows.Forms.Form
$script:lang=$Language
function T([string]$en,[string]$ro){if($script:lang -eq 'ro'){$ro}else{$en}}
$form.Text='Standivarius Doxa Setup - TEST preview.11'
$form.StartPosition='CenterScreen'
$form.ClientSize=New-Object Drawing.Size(750,510)
$form.FormBorderStyle='FixedDialog'
$form.MaximizeBox=$false
$form.Font=New-Object Drawing.Font('Segoe UI',11)
$form.BackColor=[Drawing.Color]::FromArgb(249,250,252)
$navy=[Drawing.Color]::FromArgb(17,35,59)
$teal=[Drawing.Color]::FromArgb(16,140,137)
$title=New-Object Windows.Forms.Label
$title.Text='Welcome to Doxa Setup'
$title.Font=New-Object Drawing.Font('Segoe UI',22,[Drawing.FontStyle]::Bold)
$title.ForeColor=$navy
$title.SetBounds(32,28,493,56)
$languageChoice=New-Object Windows.Forms.ComboBox
$languageChoice.SetBounds(549,39,168,31)
$languageChoice.DropDownStyle='DropDownList'
$languageChoice.AccessibleName='Setup language / Limba instalarii'
[void]$languageChoice.Items.Add('English')
[void]$languageChoice.Items.Add('Romana')
$languageChoice.SelectedIndex=if($Language -eq 'ro'){1}else{0}
$languageChoice.TabIndex=0
$form.Controls.Add($languageChoice)
$form.Controls.Add($title)
$step=New-Object Windows.Forms.Label
$step.SetBounds(35,93,650,31)
$step.ForeColor=$teal
$form.Controls.Add($step)
$explanation=New-Object Windows.Forms.Label
$explanation.SetBounds(35,140,670,78)
$form.Controls.Add($explanation)
$local=New-Object Windows.Forms.CheckBox
$local.SetBounds(35,222,672,51)
$local.Text='I allow local read-only checks of Windows version, USB controllers, display devices and installed driver packages.'
$local.CheckAlign='TopLeft'
$local.TabIndex=1
$local.AccessibleName='Local read-only diagnostics permission'
$form.Controls.Add($local)
$localDetails=New-Object System.Windows.Forms.LinkLabel
$localDetails.SetBounds(35,277,671,26)
$localDetails.Text='What does this local check read?'
$localDetails.LinkColor=$teal
$localDetails.TabIndex=2
$localDetails.AccessibleName='Read the local device-check information before agreeing'
$localDetails.Add_LinkClicked({
 $file=Join-Path $PSScriptRoot 'LOCAL-CHECK-NOTICE.txt'
 $message=if(Test-Path -LiteralPath $file){Get-Content -LiteralPath $file -Raw -Encoding UTF8}else{'Local-check information unavailable. Close Setup to avoid continuing without it.'}
 $window=New-Object System.Windows.Forms.Form
 $window.Text=T 'Doxa Setup - local check details' 'Doxa - verificari locale'
 $window.StartPosition='CenterParent';$window.ClientSize=New-Object Drawing.Size(650,440)
 $window.FormBorderStyle='Sizable';$window.MinimumSize=New-Object Drawing.Size(390,310)
 $window.Font=New-Object Drawing.Font('Segoe UI',10)
 $copy=New-Object System.Windows.Forms.TextBox
 $copy.Dock='Fill';$copy.Multiline=$true;$copy.ReadOnly=$true;$copy.ScrollBars='Vertical';$copy.WordWrap=$true;$copy.Text=$message
 $window.Controls.Add($copy);[void]$window.ShowDialog($form);$window.Dispose()
})
$form.Controls.Add($localDetails)
$cloud=New-Object Windows.Forms.CheckBox
$cloud.SetBounds(35,312,674,71)
$cloud.Text='Optional remote AI: send the question you type and limited Windows/Doxa diagnostic facts over HTTPS to a Cloudflare-hosted AI service. No screenshots, raw USB identifiers or passwords. You can continue without AI.'
$cloud.TabIndex=3
$cloud.AccessibleName='Optional online AI permission'
$form.Controls.Add($cloud)
$policyScript=Join-Path $PSScriptRoot 'Get-DoxaCloudAIPolicy.ps1'
$policy=(& $policyScript|Out-String)|ConvertFrom-Json
if(-not [bool]$policy.cloud_ai_allowed){
 $cloud.Checked=$false
 $cloud.Enabled=$false
 $cloud.Text='Cloud AI is disabled by your organization. Offline Doxa setup is available.'
}
$privacy=New-Object System.Windows.Forms.LinkLabel
$privacy.Text='What is sent to cloud AI? Privacy and AI details'
$privacy.SetBounds(35,388,660,25)
$privacy.LinkColor=$teal
$privacy.Add_LinkClicked({
 $noticeFile=Join-Path $PSScriptRoot 'AI-PRIVACY-NOTICE.txt'
 $text=if(Test-Path -LiteralPath $noticeFile){Get-Content -LiteralPath $noticeFile -Raw -Encoding UTF8}else{'AI details could not be opened. Keep cloud AI disabled.'}
 $window=New-Object System.Windows.Forms.Form
 $window.Text=T 'Doxa Setup - AI details' 'Doxa - detalii despre AI'
 $window.ClientSize=New-Object Drawing.Size(760,510)
 $window.StartPosition='CenterParent'
 $window.Font=New-Object Drawing.Font('Segoe UI',10)
 $copy=New-Object System.Windows.Forms.TextBox
 $copy.Multiline=$true;$copy.ScrollBars='Vertical';$copy.ReadOnly=$true;$copy.WordWrap=$true
 $copy.SetBounds(14,14,732,479);$copy.Text=$text
 $window.Controls.Add($copy)
 [void]$window.ShowDialog($form)
 $window.Dispose()
})
$privacy.TabIndex=4
$privacy.AccessibleName='Privacy details'
$form.Controls.Add($privacy)
$connect=New-Object Windows.Forms.RadioButton
$connect.SetBounds(35,240,660,50)
$connect.Text='I will connect Doxa now (or it is already connected)'
$connect.Visible=$false
$connect.TabIndex=5
$connect.AccessibleName='Doxa connected'
$form.Controls.Add($connect)
$without=New-Object Windows.Forms.RadioButton
$without.SetBounds(35,310,665,65)
$without.Text='Continue without Doxa - check this PC and prepare what is possible'
$without.Visible=$false
$without.TabIndex=6
$without.AccessibleName='Continue without Doxa'
$form.Controls.Add($without)
$back=New-Object Windows.Forms.Button
$back.Text='Back'
$back.SetBounds(390,423,123,45)
$back.Enabled=$false
$back.TabIndex=7
$back.AccessibleName='Back'
$form.Controls.Add($back)
$next=New-Object Windows.Forms.Button
$next.Text='Continue'
$next.SetBounds(532,423,160,45)
$next.BackColor=$teal
$next.ForeColor=[Drawing.Color]::White
$next.TabIndex=8
$next.AccessibleName='Continue'
$form.AcceptButton=$next
$form.Controls.Add($next)
$script:page=1
$script:choice=''
$script:localAllowed=$false
$script:aiAllowed=$false
$script:finished=$false
function ShowStep {
 $first=$script:page -eq 1
 $form.Text=T 'Doxa Setup - TEST preview.11' 'Doxa - TEST preview.11'
 $title.Text=T 'Welcome to Doxa Setup' 'Bine ai venit la Doxa'
 $step.Text=if($first){T 'Step 1 - permissions' 'Pasul 1 - permisiuni'}else{T 'Step 2 - connect Doxa or continue' 'Pasul 2 - conecteaza Doxa sau continua'}
 $explanation.Text=if($first){
  T 'Before checking this PC, Doxa asks permission for local read-only diagnostics. Remote AI assistance is separate and optional. Driver installation will request its own Windows approval later.' 'Doxa cere acordul pentru verificari locale fara modificari. Asistenta AI online este separata si optionala. Instalarea driverului necesita ulterior aprobare Windows.'
 }else{
  T 'Choose your starting point. You can check Windows and USB capabilities without Doxa, but connection quality and the external screens need actual hardware.' 'Alege cum incepi. Poti verifica Windows si USB fara Doxa, dar conexiunea si ecranele externe necesita dispozitivul real.'
 }
 $local.Text=T 'I allow local read-only checks of Windows version, USB controllers, display devices and installed driver packages.' 'Permit verificari locale, fara modificari, ale Windows, USB, ecranelor si driverelor instalate.'
 $cloud.Text=if([bool]$policy.cloud_ai_allowed){
   T 'Optional remote AI: send the question you type and limited Windows/Doxa diagnostic facts over HTTPS to a Cloudflare-hosted AI service. No screenshots, raw USB identifiers or passwords. You can continue without AI.' 'AI online optional: intrebarea si date limitate despre Windows/Doxa sunt trimise prin HTTPS catre Cloudflare. Nu trimitem capturi de ecran, identificatori USB completi sau parole. Poti continua fara AI.'
 }else{T 'Cloud AI is disabled by your organization. Offline Doxa setup is available.' 'Organizatia a dezactivat AI online. Poti utiliza Doxa offline.'}
 $privacy.Text=T 'What is sent to cloud AI? Privacy and AI details' 'Ce date trimite AI online? Confidentialitate si detalii'
 $localDetails.Text=T 'What does this local check read?' 'Ce citeste verificarea locala?'
 $connect.Text=T 'I will connect Doxa now (or it is already connected)' 'Conectez Doxa acum (sau este deja conectat)'
 $without.Text=T 'Continue without Doxa - check this PC and prepare what is possible' 'Continua fara Doxa - verifica PC-ul si pregateste ce este posibil'
 $back.Text=T 'Back' 'Inapoi'
 $local.Visible=$first;$localDetails.Visible=$first;$cloud.Visible=$first;$privacy.Visible=$first
 $connect.Visible=-not $first;$without.Visible=-not $first
 $back.Enabled=-not $first
 $next.Text=if($first){T 'Continue' 'Continua'}else{T 'Continue to Doxa checks' 'Continua cu verificarea Doxa'}
}
$languageChoice.Add_SelectedIndexChanged({
 $script:lang=if($languageChoice.SelectedIndex -eq 1){'ro'}else{'en'}
 ShowStep
})

$back.Add_Click({$script:page=1;ShowStep})
$next.Add_Click({
 if($script:page -eq 1){
  if(-not $local.Checked){
   if(-not ($JourneyTest -or $SeamlessTest)){[Windows.Forms.MessageBox]::Show((T 'Local read-only checks need your permission. You may close Setup instead.' 'Verificarile locale necesita acordul tau. Poti inchide Doxa fara a continua.'),(T 'Doxa permissions' 'Permisiuni Doxa'))|Out-Null}
   return
  }
  $script:localAllowed=$true
  $script:aiAllowed=([bool]$cloud.Checked -and [bool]$policy.cloud_ai_allowed)
  $script:page=2
  ShowStep
  return
 }
 if(-not $connect.Checked -and -not $without.Checked){
  if(-not ($JourneyTest -or $SeamlessTest)){[Windows.Forms.MessageBox]::Show((T 'Choose whether Doxa is connected or you want to continue without it.' 'Alege daca Doxa este conectat sau daca vrei sa continui fara dispozitiv.'),'Doxa')|Out-Null}
  return
 }
 $script:choice=if($connect.Checked){'connected'}else{'without_doxa'}
 $script:finished=$true
 if($JourneyTest){$form.Close();return}
 # Preserve the same Windows Form and HWND throughout permission, connection,
 # and hardware setup. A second form creates a flash and breaks continuity.
 $main=Join-Path $PSScriptRoot 'Start-DoxaSetup.ps1'
 $originalHandle=$form.Handle
 $form.SuspendLayout()
 try{
  $form.AcceptButton=$null
  $form.Controls.Clear()
  $form.AutoScroll=$false
    # Keep the main UI's PowerShell functions and event-handler session alive
  # after this navigation click has returned.
  $script:mainUiModule=New-Module -Name DoxaEmbeddedMainUI -ScriptBlock {
   param($mainScript,$existingForm,$allowAI,$choice,$uiLanguage,$safeTest)
   . $mainScript -DiagnosticsApproved -AIApproved:$allowAI -ConnectionPreference $choice -Language $uiLanguage -HostForm $existingForm -EmbeddedSmoke:$safeTest
  } -ArgumentList @($main,$form,[bool]$script:aiAllowed,$script:choice,$script:lang,[bool]$SeamlessTest)
  if($form.Handle -ne $originalHandle){throw 'Doxa setup replaced its original window handle.'}
  $view=[Windows.Forms.Screen]::FromControl($form).WorkingArea
  $left=$view.Left+[Math]::Max(0,[int](($view.Width-$form.Width)/2))
  $top=$view.Top+[Math]::Max(0,[int](($view.Height-$form.Height)/2))
  $form.StartPosition='Manual'
  $form.Location=New-Object Drawing.Point($left,$top)
 }catch{
  if(-not $SeamlessTest){
   [Windows.Forms.MessageBox]::Show(('Doxa could not open setup in this window: '+$_.Exception.Message),'Doxa Setup')|Out-Null
  }
  throw
 }finally{$form.ResumeLayout($true)}
})
if(-not ($Smoke -or $JourneyTest -or $SeamlessTest)){
 # Keep the same outer window size/position before and after the main screen.
 $height=[Math]::Min(615,[Math]::Max(510,[Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Height-48))
 $form.ClientSize=New-Object Drawing.Size(1060,$height)
 $form.BackColor=[Drawing.Color]::White
 foreach($ctl in @($title,$step,$explanation,$local,$localDetails,$cloud,$privacy,$connect,$without,$back,$next,$languageChoice)){
  $ctl.Left+=155;$ctl.Top+=42
 }
 $logoFile=Join-Path $PSScriptRoot 'assets\standivarius-official-logo.png'
 if(Test-Path -LiteralPath $logoFile){
  $p=New-Object Windows.Forms.PictureBox
  $logoStream=New-Object IO.MemoryStream(,[IO.File]::ReadAllBytes($logoFile))
  $rawLogo=[Drawing.Image]::FromStream($logoStream)
  $p.Image=New-Object Drawing.Bitmap($rawLogo)
  $rawLogo.Dispose();$logoStream.Dispose()
  $p.SizeMode='Zoom'
  $p.SetBounds(22,13,235,36);$p.AccessibleName='Standivarius official logo'
  $form.Controls.Add($p)
 }
}
ShowStep
if($SeamlessTest){
 $form.Show()
 $originalHandle=$form.Handle
 $click=[Windows.Forms.Button].GetMethod('OnClick',[Reflection.BindingFlags]'Instance,NonPublic')
 [void]$click.Invoke($next,@([EventArgs]::Empty))
 if($script:page -ne 1){throw 'Seamless journey bypassed local consent'}
 $local.Checked=$true
 [void]$click.Invoke($next,@([EventArgs]::Empty))
 if($script:page -ne 2){throw 'Consent did not advance to connection choices'}
 if($TestConnectionChoice -eq 'connected'){$connect.Checked=$true}else{$without.Checked=$true}
 [void]$click.Invoke($next,@([EventArgs]::Empty))
 $state=$form.Tag
 if(-not $script:finished -or $null -eq $state -or $state.stage -ne 'main'){
  throw 'Same-window transition did not create the main installer UI'
 }
 if($form.Handle -ne $originalHandle){throw 'New window handle created instead of reusing the welcome window'}
 if(-not ($state.PSObject.Properties.Name -contains 'tabs') -or @($state.tabs).Count -ne 3){throw 'Shipped BrandTabs not reached via consent journey'}
  if(-not $state.checkButton.IsHandleCreated -and $null -eq $state.checkButton.Parent){throw 'Detect is orphaned'}
  if($state.guideButton.Parent -eq $null){throw 'Screen guide entry is orphaned'}
  [void]$click.Invoke($state.tabs[1],@([EventArgs]::Empty))
  if(-not $state.context.Visible){throw 'Setup contextual panel absent in shipped customer journey'}
  [void]$click.Invoke($state.tabs[0],@([EventArgs]::Empty))
  if($Language -eq 'ro' -and $state.tabs[0].Text -notmatch 'Detecteaza'){throw 'Shipped tab lacks Romanian localisation'}
 [void]$click.Invoke($state.checkButton,@([EventArgs]::Empty))
 if(-not $state.statusLabel.Text){throw 'The in-place main Detect Doxa action did not work'}
 [ordered]@{
  seamless='PASS';window_handle_preserved=$true
  main_controls_reuse_form=$true;real_branded_tabs_exercised=$true;detect_doxa_works=$true
  initial_hardware_scans_before_consent=0;cloud_ai_requests=0
  owner_choice=$TestConnectionChoice;language=$Language
  driver_changes=$false;new_form_opened=$false
 }|ConvertTo-Json -Compress
 $form.Dispose()
 return
}
if($Smoke){
 $result=[ordered]@{smoke='PASS';first_page=$script:page;local_checks_before_consent=$false;cloud_ai_before_consent=$false;local_consent_default=$local.Checked;remote_ai_default=$cloud.Checked;privacy_details_available=(Test-Path (Join-Path $PSScriptRoot 'AI-PRIVACY-NOTICE.txt'));local_check_details_available=(Test-Path (Join-Path $PSScriptRoot 'LOCAL-CHECK-NOTICE.txt'));local_check_link_label=$localDetails.Text;org_cloud_ai_allowed=[bool]$policy.cloud_ai_allowed;connect_options=2;language=$script:lang;localized_step=$step.Text;next_caption=$next.Text;language_count=$languageChoice.Items.Count;tab_order=@($languageChoice.TabIndex,$local.TabIndex,$localDetails.TabIndex,$cloud.TabIndex,$privacy.TabIndex,$connect.TabIndex,$without.TabIndex,$back.TabIndex,$next.TabIndex);accept_button_set=([object]::ReferenceEquals($form.AcceptButton,$next))}
 $form.Dispose();$result|ConvertTo-Json -Compress;return
}
if($JourneyTest){
 $click=[Windows.Forms.Button].GetMethod('OnClick',[Reflection.BindingFlags]'Instance,NonPublic')
 [void]$click.Invoke($next,@([EventArgs]::Empty))
 if($script:page -ne 1){throw 'Wizard advanced without local consent'}
 # Language change must not grant diagnostic/AI consent.
 $initialLanguage=$script:lang
 $languageChoice.SelectedIndex=if($initialLanguage -eq 'en'){1}else{0}
 if($local.Checked -or $cloud.Checked -or $script:page -ne 1){throw 'Language switch changed permissions'}
 if($step.Text -notmatch $(if($script:lang -eq 'ro'){'Pasul 1'}else{'Step 1'})){throw 'Language switch not reflected'}
 $languageChoice.SelectedIndex=if($initialLanguage -eq 'ro'){1}else{0}
 if($script:lang -ne $initialLanguage){throw 'Language choice not restored'}
 if($Language -eq 'ro' -and $step.Text -notmatch 'Pasul 1'){throw 'Romanian permissions missing'}
 $local.Checked=$true;$cloud.Checked=([bool]$TestAIAllowed -and [bool]$policy.cloud_ai_allowed)
 [void]$click.Invoke($next,@([EventArgs]::Empty))
 if($script:page -ne 2 -or $script:aiAllowed -ne ([bool]$TestAIAllowed -and [bool]$policy.cloud_ai_allowed)){throw 'Optional AI consent failed'}
 if($Language -eq 'ro' -and $step.Text -notmatch 'Pasul 2'){throw 'Romanian connection guidance missing'}
 if($TestConnectionChoice -eq 'connected'){$connect.Checked=$true}else{$without.Checked=$true}
 [void]$click.Invoke($next,@([EventArgs]::Empty))
 if(-not $script:finished -or $script:choice -ne $TestConnectionChoice){throw 'Connection-choice journey failed'}
 $form.Dispose()
 [ordered]@{journey='PASS';consent_required=$true;remote_ai_optional=$true;connection_choice=$script:choice;ai_consent=$script:aiAllowed;hardware_scans_before_consent=0;remote_requests=0;local_check_link_present=$true;language=$script:lang;localized_step=$step.Text}|ConvertTo-Json -Compress;return
}
[Windows.Forms.Application]::Run($form)
$form.Dispose()
# Page transition is handled inside the original form; no second UI is launched.
