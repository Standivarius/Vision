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
[void]$languageChoice.Items.Add('Romana')
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
# Keep checkbox glyphs in their own equal-width column. Separate labels are
# top-aligned, and clicking any label toggles its checkbox.
$terms=New-Object Windows.Forms.CheckBox
$terms.SetBounds(35,211,23,23)
$terms.Text=''
$terms.AccessibleName='I agree to the Doxa Setup Terms of Use'
$terms.TabIndex=1
$form.Controls.Add($terms)
$termsLabel=New-Object Windows.Forms.Label
$termsLabel.SetBounds(64,209,421,31)
$termsLabel.Text='I agree to the Doxa Setup Terms of Use.'
$termsLabel.Add_Click({$terms.Checked=(-not $terms.Checked)})
$form.Controls.Add($termsLabel)
$termsLink=New-Object Windows.Forms.LinkLabel
$termsLink.SetBounds(499,209,203,28)
$termsLink.Text='Read Terms of Use'
$termsLink.LinkColor=$teal
$termsLink.TabIndex=2
$termsLink.Add_LinkClicked({
 $file=Join-Path $PSScriptRoot 'DOXA-SETUP-TERMS.txt'
 $message=if(Test-Path -LiteralPath $file){Get-Content -LiteralPath $file -Raw -Encoding UTF8}else{'Terms of Use are unavailable. Close Doxa Setup until they can be read.'}
 $window=New-Object System.Windows.Forms.Form
 $window.Text='Doxa Setup - Terms of Use'
 $window.StartPosition='CenterParent';$window.ClientSize=New-Object Drawing.Size(800,580)
 $window.MinimumSize=New-Object Drawing.Size(540,390)
 $window.FormBorderStyle='Sizable'
 $window.BackColor=[Drawing.Color]::White
 $window.Font=New-Object Drawing.Font('Segoe UI',10)
 $window.Padding=New-Object Windows.Forms.Padding(22,18,22,14)
 $footer=New-Object Windows.Forms.Panel
 $footer.Dock='Bottom';$footer.Height=55
 $close=New-Object Windows.Forms.Button
 $close.Text='Close'
 $close.SetBounds(646,10,106,34)
 $close.Anchor=([Windows.Forms.AnchorStyles]::Right -bor [Windows.Forms.AnchorStyles]::Top)
 $close.DialogResult=[Windows.Forms.DialogResult]::OK
 $footer.Controls.Add($close);$window.Controls.Add($footer)
 $window.AcceptButton=$close;$window.CancelButton=$close
 $copy=New-Object Windows.Forms.RichTextBox
 $copy.Dock='Fill';$copy.ReadOnly=$true;$copy.WordWrap=$true
 $copy.ScrollBars='Vertical';$copy.BorderStyle='None'
 $copy.BackColor=[Drawing.Color]::White
 $copy.Font=New-Object Drawing.Font('Segoe UI',10.5)
 $copy.Text=$message
 # Preserve the legal text; style only its existing title and section headers.
 $headingColor=[Drawing.Color]::FromArgb(157,18,51)
 $headings=[regex]::Matches($copy.Text,'(?m)^(DOXA SETUP - TERMS OF USE|Provider|[1-8]\. [^\r\n]+)\r?$')
 foreach($heading in $headings){
  $copy.Select($heading.Index,$heading.Length)
  $size=if($heading.Value -like 'DOXA SETUP*'){15}else{11}
  $copy.SelectionFont=New-Object Drawing.Font('Segoe UI',$size,[Drawing.FontStyle]::Bold)
  $copy.SelectionColor=$headingColor
 }
 $copy.Select(0,0)
 $window.Controls.Add($copy)
 try{[void]$window.ShowDialog($form)}finally{$copy.Dispose();$window.Dispose()}
})
$form.Controls.Add($termsLink)
$local=New-Object Windows.Forms.CheckBox
$local.SetBounds(35,250,23,23)
$local.Text=''
$local.TabIndex=3
$local.AccessibleName='Allow local read-only Windows USB display and driver checks'
# Native host already asked for this exact permission. Keep visible for
# transparency, but do not ask the person to approve it twice.
if($LocalConsentAlreadyGranted){$local.Checked=$true;$local.Enabled=$false}
$form.Controls.Add($local)
$localLabel=New-Object Windows.Forms.Label
$localLabel.SetBounds(64,247,641,40)
$localLabel.Text='I allow local read-only Windows, USB, display and driver checks.'
$localLabel.Add_Click({if($local.Enabled){$local.Checked=(-not $local.Checked)}})
$form.Controls.Add($localLabel)
$localDetails=New-Object System.Windows.Forms.LinkLabel
$localDetails.SetBounds(64,291,641,26)
$localDetails.Text='What does this local check read?'
$localDetails.LinkColor=$teal
$localDetails.TabIndex=4
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
$cloud.SetBounds(35,327,23,23)
$cloud.Text=''
$cloud.TabIndex=5
$cloud.AccessibleName='Enable optional Online AI Help'
$form.Controls.Add($cloud)
$cloudLabel=New-Object Windows.Forms.Label
$cloudLabel.SetBounds(64,321,641,57)
$cloudLabel.Text='Optional Online AI Help: sends a typed question and limited diagnostic data. No screenshots or passwords.'
$cloudLabel.Add_Click({if($cloud.Enabled){$cloud.Checked=(-not $cloud.Checked)}})
$form.Controls.Add($cloudLabel)
$policyScript=Join-Path $PSScriptRoot 'Get-DoxaCloudAIPolicy.ps1'
$policy=(& $policyScript|Out-String)|ConvertFrom-Json
if(-not [bool]$policy.online_ai_selectable){
 $cloud.Checked=$false
 $cloud.Enabled=$false
 $cloudLabel.Text=if([bool]$policy.online_ai_selectable){
  'Cloud AI is disabled by your organization. Offline Doxa setup is available.'
 }else{'Cloud AI is disabled by your organization. Offline Doxa setup is available.'}
}
$privacy=New-Object System.Windows.Forms.LinkLabel
$privacy.Text='Privacy details for Online AI Help'
$privacy.SetBounds(64,386,641,26)
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
$privacy.TabIndex=6
$privacy.AccessibleName='Privacy details'
$form.Controls.Add($privacy)
$back=New-Object Windows.Forms.Button
$back.Text='Back'
$back.SetBounds(390,423,123,45)
$back.Enabled=$false;$back.Visible=$false
$back.TabIndex=8
$back.AccessibleName='Back'
$form.Controls.Add($back)
$next=New-Object Windows.Forms.Button
$next.Text='Continue'
$next.SetBounds(532,423,160,45)
$next.BackColor=$teal
$next.ForeColor=[Drawing.Color]::White
$next.TabIndex=7
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
 $explanation.Text=T 'Read the Terms of Use and allow local read-only checks. Online AI Help is optional. Driver changes require separate Windows approval.' 'Citeste conditiile si permite verificarile locale. Ajutorul AI online este optional. Driverul necesita aprobare Windows separata.'
 $termsLabel.Text=T 'I agree to the Doxa Setup Terms of Use.' 'Accept Conditiile de utilizare Doxa Setup.'
 $termsLink.Text=T 'Read Terms of Use' 'Citeste conditiile'
 $localLabel.Text=T 'I allow local read-only Windows, USB, display and driver checks.' 'Permit verificari locale pentru Windows, USB, ecrane si drivere.'
 $localDetails.Text=T 'What does this local check read?' 'Ce citeste verificarea locala?'
 $cloudLabel.Text=if($policy.online_ai_selectable){T 'Optional Online AI Help: sends a typed question and limited diagnostic data. No screenshots or passwords.' 'Ajutor AI online optional: trimite intrebarile si date limitate, fara capturi sau parole.'}else{T 'Online AI Help is unavailable or disabled. Offline Doxa Help remains available.' 'Ajutorul AI online este dezactivat. Ajutorul offline ramane disponibil.'}
 $privacy.Text='Privacy details for Online AI Help'
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
  if(-not ($JourneyTest -or $SeamlessTest)){[Windows.Forms.MessageBox]::Show((T 'Please accept the Terms of Use and allow local checks.' 'Accepta conditiile si aproba verificarile locale.'),'Doxa Setup')|Out-Null}
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
 foreach($ctl in @($title,$step,$explanation,$terms,$termsLabel,$termsLink,$local,$localLabel,$localDetails,$cloud,$cloudLabel,$privacy,$back,$next,$languageChoice,$languageLabel)){
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
 terms_of_use_available=(Test-Path (Join-Path $PSScriptRoot 'DOXA-SETUP-TERMS.txt'));
  checkbox_alignment_pass=($terms.Left -eq $local.Left -and $local.Left -eq $cloud.Left -and
    $termsLabel.Left -eq $localLabel.Left -and $localLabel.Left -eq $cloudLabel.Left -and
    [Math]::Abs($terms.Top-$termsLabel.Top) -le 5 -and
    [Math]::Abs($local.Top-$localLabel.Top) -le 5 -and
    [Math]::Abs($cloud.Top-$cloudLabel.Top) -le 8);
  terms_checkbox_text=$termsLabel.Text;
  online_privacy_link_text=$privacy.Text;
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
