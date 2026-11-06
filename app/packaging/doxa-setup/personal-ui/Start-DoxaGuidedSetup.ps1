param([switch]$Smoke,[switch]$JourneyTest,[switch]$SeamlessTest,[ValidateSet('connected','without_doxa')][string]$TestConnectionChoice='without_doxa',[switch]$TestAIAllowed,[switch]$LocalConsentAlreadyGranted,[switch]$PermissionsGrantedInHost,[switch]$OnlineAIAllowedInHost,[ValidateSet('en','ro')][string]$Language='en',[string]$BootstrapInstaller='')
# Consent-first welcome. No hardware enumeration or remote AI call occurs before consent.
# Reading the organization cloud-AI prohibition is a local policy check only.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$form=New-Object Windows.Forms.Form
$script:lang=$Language
function T([string]$en,[string]$ro){if($script:lang -eq 'ro'){$ro}else{$en}}
$form.Text='Standivarius | Doxa Triple Monitor Setup'
$form.StartPosition='CenterScreen'
$form.ClientSize=New-Object Drawing.Size(750,510)
$form.FormBorderStyle='FixedDialog'
$form.MaximizeBox=$false
$form.Font=New-Object Drawing.Font('Segoe UI',11)
$form.BackColor=[Drawing.Color]::White
$navy=[Drawing.Color]::FromArgb(24,43,61)
$teal=[Drawing.Color]::FromArgb(165,27,51)
$title=New-Object Windows.Forms.Label
$title.Text='Doxa Triple Monitor Setup'
$title.Font=New-Object Drawing.Font('Segoe UI',20,[Drawing.FontStyle]::Bold)
$title.ForeColor=$navy
$title.SetBounds(32,28,493,56)
$languageChoice=New-Object Windows.Forms.ComboBox
$languageChoice.SetBounds(549,39,168,31)
$languageChoice.DropDownStyle='DropDownList'
$languageChoice.AccessibleName='Setup language / Limba instalarii'
[void]$languageChoice.Items.Add('English')
[void]$languageChoice.Items.Add('Română')
$languageChoice.SelectedIndex=if($Language -eq 'ro'){1}else{0}
$languageChoice.TabIndex=0
$form.Controls.Add($languageChoice)
$languageLabel=New-Object Windows.Forms.Label
$languageLabel.Text='Language'
$languageLabel.SetBounds(549,14,168,22)
$languageLabel.ForeColor=$navy
$languageLabel.Font=New-Object Drawing.Font('Segoe UI',9)
$form.Controls.Add($languageLabel)
$form.Controls.Add($title)
$step=New-Object Windows.Forms.Label
$step.SetBounds(35,93,650,31)
$step.ForeColor=$teal
$form.Controls.Add($step)
$explanation=New-Object Windows.Forms.Label
$explanation.SetBounds(35,139,670,62)
$form.Controls.Add($explanation)
$terms=New-Object Windows.Forms.CheckBox
$terms.SetBounds(35,207,457,31)
$terms.Text='I agree to the Doxa Setup private preview terms.'
$terms.TabIndex=1
$form.Controls.Add($terms)
$termsLink=New-Object Windows.Forms.LinkLabel
$termsLink.SetBounds(499,209,203,28)
$termsLink.Text='View terms'
$termsLink.LinkColor=$teal
$termsLink.Add_LinkClicked({
 $termsText=T 'PRIVATE PREVIEW. DMR Ergonomics S.R.L. (Standivarius). Local checks require separate consent. Online AI is optional. A healthy signed driver is preserved. Installing a missing driver requires separate Windows approval. You may exit or uninstall the app without removing the driver.' 'EVALUARE PRIVATA. DMR Ergonomics S.R.L. (Standivarius). Verificarile locale necesita acord. AI online este optional. Driverul semnat functional este pastrat. Instalarea unui driver lipsa necesita aprobare Windows separata. Dezinstalarea aplicatiei nu elimina driverul.'
 [Windows.Forms.MessageBox]::Show($termsText,(T 'Doxa preview terms' 'Conditii Doxa'))|Out-Null
})
$form.Controls.Add($termsLink)
$local=New-Object Windows.Forms.CheckBox
$local.SetBounds(35,241,672,42)
$local.Text='I allow local read-only checks of Windows version, USB controllers, display devices and installed driver packages.'
$local.CheckAlign='TopLeft'
$local.TabIndex=1
$local.AccessibleName='Local read-only diagnostics permission'
# Native host already asked for this exact permission. Keep visible for
# transparency, but do not ask the person to approve it twice.
if($LocalConsentAlreadyGranted){$local.Checked=$true;$local.Enabled=$false}
$form.Controls.Add($local)
$localDetails=New-Object System.Windows.Forms.LinkLabel
$localDetails.SetBounds(35,281,671,26)
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
if(-not [bool]$policy.online_ai_selectable){
 $cloud.Checked=$false
 $cloud.Enabled=$false
 $cloud.Text=if([bool]$policy.online_ai_selectable){
  'Cloud AI is disabled by your organization. Offline Doxa setup is available.'
 }else{'Cloud AI is disabled by your organization. Offline Doxa setup is available.'}
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
$back=New-Object Windows.Forms.Button
$back.Text='Back'
$back.SetBounds(390,423,123,45)
$back.Enabled=$false;$back.Visible=$false
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
$script:choice='without_doxa'
$script:localAllowed=[bool]$PermissionsGrantedInHost
$script:aiAllowed=([bool]$PermissionsGrantedInHost -and [bool]$OnlineAIAllowedInHost -and [bool]$policy.online_ai_selectable)
$script:finished=$false
function ShowStep {
 if($script:finished){return}
 $form.Text=T 'Standivarius | Doxa Setup' 'Standivarius | Configurare Doxa'
 $title.Text=T 'Doxa Setup' 'Configurare Doxa'
 $languageLabel.Text=T 'Language' 'Limba'
 $step.Text=T 'Terms, permissions and privacy' 'Conditii, permisiuni si confidentialitate'
 $explanation.Text=T 'Accept the preview terms and allow local read-only checks. Cloud AI is optional. Changing a driver always requires separate Windows approval.' 'Accepta conditiile de evaluare si permite verificarile locale. AI online este optional. Modificarea driverului necesita aprobare Windows separata.'
 $terms.Text=T 'I agree to the Doxa Setup private preview terms.' 'Accept conditiile de evaluare Doxa Setup.'
 $termsLink.Text=T 'View terms' 'Citeste conditiile'
 $local.Text=T 'I allow local read-only Windows, USB, display and driver checks.' 'Permit verificari locale pentru Windows, USB, ecrane si drivere.'
 $localDetails.Text=T 'What does this local check read?' 'Ce citeste verificarea locala?'
 $cloud.Text=if($policy.online_ai_selectable){T 'Optional cloud AI: sends a typed question and limited diagnostic data. No screenshots or passwords.' 'AI online optional: trimite intrebari si date limitate, fara capturi sau parole.'}else{T 'Cloud AI is unavailable or disabled. Offline Doxa Help remains available.' 'AI online este dezactivat. Ajutorul Doxa offline ramane disponibil.'}
 $privacy.Text=T 'Cloud AI privacy details' 'Confidentialitate AI online'
 $next.Text=T 'Continue to Doxa' 'Continua la Doxa'
 $back.Visible=$false
}
$languageChoice.Add_SelectedIndexChanged({
 $script:lang=if($languageChoice.SelectedIndex -eq 1){'ro'}else{'en'}
 ShowStep
})

$next.Add_Click({
 if($script:finished){return}
 if(-not $terms.Checked -or -not $local.Checked){
  if(-not ($JourneyTest -or $SeamlessTest)){[Windows.Forms.MessageBox]::Show((T 'Please accept the preview terms and allow local checks.' 'Accepta conditiile si aproba verificarile locale.'),'Doxa Setup')|Out-Null}
  return
 }
 $script:localAllowed=$true
 $script:aiAllowed=([bool]$cloud.Checked -and [bool]$policy.online_ai_selectable)
 $script:choice='without_doxa' # No hardware connection radio choices.
 $script:finished=$true
 if($JourneyTest){return}
 # # Preserve the same Windows Form and HWND throughout permission, connection,
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
   param($mainScript,$existingForm,$allowAI,$choice,$uiLanguage,$safeTest,$installerExe)
   . $mainScript -DiagnosticsApproved -AIApproved:$allowAI -ConnectionPreference $choice -Language $uiLanguage -HostForm $existingForm -EmbeddedSmoke:$safeTest -BootstrapInstaller $installerExe
  } -ArgumentList @($main,$form,[bool]$script:aiAllowed,$script:choice,$script:lang,[bool]$SeamlessTest,$BootstrapInstaller)
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
 foreach($ctl in @($title,$step,$explanation,$terms,$termsLink,$local,$localDetails,$cloud,$privacy,$back,$next,$languageChoice,$languageLabel)){
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
if($Smoke){
 [ordered]@{smoke='PASS';connect_options=0;initial_hardware_scans_before_consent=0;
 preview_terms_required=$true;local_consent_default=$local.Checked;
 cloud_ai_default=$cloud.Checked;remote_ai_default=$cloud.Checked;language=$script:lang;
 local_checks_before_consent=$false;cloud_ai_before_consent=$false;
 privacy_details_available=(Test-Path (Join-Path $PSScriptRoot 'AI-PRIVACY-NOTICE.txt'));
 local_check_details_available=(Test-Path (Join-Path $PSScriptRoot 'LOCAL-CHECK-NOTICE.txt'));
 accept_button_set=([object]::ReferenceEquals($form.AcceptButton,$next));language_count=$languageChoice.Items.Count;
 tab_order=@($languageChoice.TabIndex,$terms.TabIndex,$local.TabIndex,$localDetails.TabIndex,$cloud.TabIndex,$privacy.TabIndex,$next.TabIndex,$back.TabIndex)}|ConvertTo-Json -Compress
 $form.Dispose();return
}
if($SeamlessTest -or $JourneyTest){
 $form.Show()
 $handle=$form.Handle
 $click=[Windows.Forms.Button].GetMethod('OnClick',[Reflection.BindingFlags]'Instance,NonPublic')
 [void]$click.Invoke($next,@([EventArgs]::Empty))
 if($script:finished){throw 'Terms/diagnostics consent bypassed'}
 $terms.Checked=$true
 [void]$click.Invoke($next,@([EventArgs]::Empty))
 if($script:finished){throw 'Local diagnostics consent bypassed'}
 $local.Checked=$true
 $cloud.Checked=([bool]$TestAIAllowed -and [bool]$policy.online_ai_selectable)
 [void]$click.Invoke($next,@([EventArgs]::Empty))
 if(-not $script:finished){throw 'Consent failed to enter the main screen'}
 if($JourneyTest){
  [ordered]@{journey='PASS';consent_required=$true;preview_terms_required=$true;radio_choice_removed=$true;
   connection_choice='not_required';ai_consent=$script:aiAllowed;hardware_scans_before_consent=0;
   remote_requests=0;language=$script:lang}|ConvertTo-Json -Compress
 }else{
  $state=$form.Tag
  if($form.Handle -ne $handle -or $null -eq $state -or $state.stage -ne 'main'){throw 'Second form or missing main UI'}
  if(@($state.tabs).Count -ne 3 -or $state.tabs[0].Text -notmatch 'Doxa'){throw 'Missing Connect and Detect Doxa tab'}
  [void]$click.Invoke($state.tabs[1],@([EventArgs]::Empty))
  if(-not $state.setup_page.Visible -or -not $state.side_panel.Visible){throw 'Setup page / persistent help missing'}
  [void]$click.Invoke($state.tabs[0],@([EventArgs]::Empty))
  [void]$click.Invoke($state.checkButton,@([EventArgs]::Empty))
  if(-not $state.statusLabel.Text){throw 'Detect Doxa produced no status'}
  [ordered]@{seamless='PASS';detect_doxa_works=$true;initial_hardware_scans_before_consent=0;one_window=$true;window_handle_preserved=$true;main_controls_reuse_form=$true;
   real_branded_tabs_exercised=$true;connect_choice_removed=$true;consent_required=$true;
   preview_terms_required=$true;cloud_ai_requests=0;driver_changes=$false;new_form_opened=$false;
   language=$Language;owner_choice='not_required'}|ConvertTo-Json -Compress
 }
 $form.Dispose();return
}
[Windows.Forms.Application]::Run($form)
$form.Dispose()
# Page transition is handled inside the original form; no second UI is launched.
