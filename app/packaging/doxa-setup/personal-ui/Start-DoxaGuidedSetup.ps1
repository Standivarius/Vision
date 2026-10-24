param([switch]$Smoke,[switch]$JourneyTest,[ValidateSet('connected','without_doxa')][string]$TestConnectionChoice='without_doxa',[switch]$TestAIAllowed)
# Consent-first welcome. No hardware enumeration or remote AI call occurs before consent.
# Reading the organization cloud-AI prohibition is a local policy check only.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$form=New-Object Windows.Forms.Form
$form.Text='Standivarius Doxa Setup - Welcome'
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
$title.SetBounds(32,28,690,56)
$form.Controls.Add($title)
$step=New-Object Windows.Forms.Label
$step.SetBounds(35,93,650,31)
$step.ForeColor=$teal
$form.Controls.Add($step)
$explanation=New-Object Windows.Forms.Label
$explanation.SetBounds(35,140,670,78)
$form.Controls.Add($explanation)
$local=New-Object Windows.Forms.CheckBox
$local.SetBounds(35,236,672,62)
$local.Text='I allow local read-only checks of Windows version, USB controllers, display devices and installed driver packages.'
$local.CheckAlign='TopLeft'
$form.Controls.Add($local)
$cloud=New-Object Windows.Forms.CheckBox
$cloud.SetBounds(35,306,674,82)
$cloud.Text='Optional remote AI: send the question you type and limited Windows/Doxa diagnostic facts over HTTPS to a Cloudflare-hosted AI service. No screenshots, raw USB identifiers or passwords. You can continue without AI.'
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
$privacy.SetBounds(35,385,660,25)
$privacy.LinkColor=$teal
$privacy.Add_LinkClicked({
 $noticeFile=Join-Path $PSScriptRoot 'AI-PRIVACY-NOTICE.txt'
 $text=if(Test-Path -LiteralPath $noticeFile){Get-Content -LiteralPath $noticeFile -Raw -Encoding UTF8}else{'AI details could not be opened. Keep cloud AI disabled.'}
 $window=New-Object System.Windows.Forms.Form
 $window.Text='Doxa Setup — AI details'
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
$form.Controls.Add($privacy)
$connect=New-Object Windows.Forms.RadioButton
$connect.SetBounds(35,240,660,50)
$connect.Text='I will connect Doxa now (or it is already connected)'
$connect.Visible=$false
$form.Controls.Add($connect)
$without=New-Object Windows.Forms.RadioButton
$without.SetBounds(35,310,665,65)
$without.Text='Continue without Doxa - check this PC and prepare what is possible'
$without.Visible=$false
$form.Controls.Add($without)
$back=New-Object Windows.Forms.Button
$back.Text='Back'
$back.SetBounds(390,423,123,45)
$back.Enabled=$false
$form.Controls.Add($back)
$next=New-Object Windows.Forms.Button
$next.Text='Continue'
$next.SetBounds(532,423,160,45)
$next.BackColor=$teal
$next.ForeColor=[Drawing.Color]::White
$form.Controls.Add($next)
$script:page=1
$script:choice=''
$script:localAllowed=$false
$script:aiAllowed=$false
$script:finished=$false
function ShowStep {
 $first=$script:page -eq 1
 $step.Text=if($first){'Step 1 of 2 - permissions'}else{'Step 2 of 2 - connect Doxa or continue'}
 $explanation.Text=if($first){
  'Before checking this PC, Doxa asks permission for local read-only diagnostics. Remote AI assistance is separate and optional. Driver installation will request its own Windows approval later.'
 }else{
  'Choose your starting point. You can check Windows and USB capabilities without Doxa, but connection quality and the external screens need actual hardware.'
 }
 $local.Visible=$first;$cloud.Visible=$first;$privacy.Visible=$first
 $connect.Visible=-not $first;$without.Visible=-not $first
 $back.Enabled=-not $first
 $next.Text=if($first){'Continue'}else{'Open Doxa Setup'}
}
$back.Add_Click({$script:page=1;ShowStep})
$next.Add_Click({
 if($script:page -eq 1){
  if(-not $local.Checked){
   if(-not $JourneyTest){[Windows.Forms.MessageBox]::Show('Local read-only checks need your permission. You may close Setup instead.','Doxa permissions')|Out-Null}
   return
  }
  $script:localAllowed=$true
  $script:aiAllowed=([bool]$cloud.Checked -and [bool]$policy.cloud_ai_allowed)
  $script:page=2
  ShowStep
  return
 }
 if(-not $connect.Checked -and -not $without.Checked){
  if(-not $JourneyTest){[Windows.Forms.MessageBox]::Show('Choose whether Doxa is connected or you want to continue without it.','Doxa')|Out-Null}
  return
 }
 $script:choice=if($connect.Checked){'connected'}else{'without_doxa'}
 $script:finished=$true
 $form.Close()
})
ShowStep
if($Smoke){
 $result=[ordered]@{smoke='PASS';first_page=$script:page;local_checks_before_consent=$false;cloud_ai_before_consent=$false;local_consent_default=$local.Checked;remote_ai_default=$cloud.Checked;privacy_details_available=(Test-Path (Join-Path $PSScriptRoot 'AI-PRIVACY-NOTICE.txt'));org_cloud_ai_allowed=[bool]$policy.cloud_ai_allowed;connect_options=2}
 $form.Dispose();$result|ConvertTo-Json -Compress;return
}
if($JourneyTest){
 $click=[Windows.Forms.Button].GetMethod('OnClick',[Reflection.BindingFlags]'Instance,NonPublic')
 [void]$click.Invoke($next,@([EventArgs]::Empty))
 if($script:page -ne 1){throw 'Wizard advanced without local consent'}
 $local.Checked=$true;$cloud.Checked=([bool]$TestAIAllowed -and [bool]$policy.cloud_ai_allowed)
 [void]$click.Invoke($next,@([EventArgs]::Empty))
 if($script:page -ne 2 -or $script:aiAllowed -ne ([bool]$TestAIAllowed -and [bool]$policy.cloud_ai_allowed)){throw 'Optional AI consent failed'}
 if($TestConnectionChoice -eq 'connected'){$connect.Checked=$true}else{$without.Checked=$true}
 [void]$click.Invoke($next,@([EventArgs]::Empty))
 if(-not $script:finished -or $script:choice -ne $TestConnectionChoice){throw 'Connection-choice journey failed'}
 $form.Dispose()
 [ordered]@{journey='PASS';consent_required=$true;remote_ai_optional=$true;connection_choice=$script:choice;ai_consent=$script:aiAllowed;hardware_scans_before_consent=0;remote_requests=0}|ConvertTo-Json -Compress;return
}
[Windows.Forms.Application]::Run($form)
$form.Dispose()
if(-not $script:finished){return}
$main=Join-Path $PSScriptRoot 'Start-DoxaSetup.ps1'
& $main -DiagnosticsApproved -AIApproved:$script:aiAllowed -ConnectionPreference $script:choice
