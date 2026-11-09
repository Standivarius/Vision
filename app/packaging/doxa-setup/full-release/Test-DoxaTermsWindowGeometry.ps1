# Opt-in WinForms test of the actual customer Terms click handler.
# Never changes display scaling, drivers, system configuration or network state.
# TextScalePercent enlarges the text ONLY (stress test, not a real-DPI test).
param(
 [ValidateSet(100,150,200)][int]$TextScalePercent=100,
 [ValidateRange(540,1600)][int]$WindowWidth=800,
 [ValidateRange(390,1200)][int]$WindowHeight=580
)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$sourceFile=Join-Path (Split-Path $PSScriptRoot -Parent) 'personal-ui\Start-DoxaGuidedSetup.ps1'
$source=Get-Content $sourceFile -Raw -Encoding UTF8
$regex='(?s)\$termsLink\.Add_LinkClicked\(\{\s*(.*?)\s*\r?\n\}\)'
$match=[regex]::Match($source,$regex)
if(-not $match.Success){throw 'Cannot extract live Terms click handler'}
$body=$match.Groups[1].Value.Replace('$PSScriptRoot',("'"+(Split-Path $sourceFile -Parent)+"'"))
$body=$body.Replace('New-Object Drawing.Size(800,580)','New-Object Drawing.Size($WindowWidth,$WindowHeight)')
if($TextScalePercent -ne 100){
 $oldFont='$copy.Font=New-Object Drawing.Font(''Segoe UI'',10.5)'
 $newFont='$copy.Font=New-Object Drawing.Font(''Segoe UI'','+([math]::Round(10.5*$TextScalePercent/100,2))+')'
 if(-not $body.Contains($oldFont)){throw 'Cannot find original body text font'}
 $body=$body.Replace($oldFont,$newFont)
}
$insertion=@'
 $window.Add_Shown({
  [void]$window.BeginInvoke([System.Action]{
   try{
    [Windows.Forms.Application]::DoEvents()
    $inside=($close.Left -ge 0 -and $close.Top -ge 0 -and
       $close.Right -le $footer.ClientSize.Width -and
       $close.Bottom -le $footer.ClientSize.Height)
    $overlap=$copy.Bounds.IntersectsWith($footer.Bounds)
    $title='5. Updates and workplace use'
    $titleIndex=$copy.Find($title,[Windows.Forms.RichTextBoxFinds]::NoHighlight)
    if($titleIndex -lt 0){throw 'Heading not found'}
    $copy.Select($titleIndex,$title.Length)
    $headingStyled=($copy.SelectionFont.Bold -and $copy.SelectionColor.R -eq 157)
    $bodyIndex=$copy.Find('A newer installer or service update may become available.',[Windows.Forms.RichTextBoxFinds]::NoHighlight)
    if($bodyIndex -lt 0){throw 'Body text not found'}
    $copy.Select($bodyIndex,12)
    $bodyPlain=(-not $copy.SelectionFont.Bold)
    $copy.SelectionStart=$copy.TextLength-1
    $copy.SelectionLength=0;$copy.ScrollToCaret()
    [Windows.Forms.Application]::DoEvents()
    $finalPos=$copy.GetPositionFromCharIndex($copy.TextLength-1)
    $lastVisible=($finalPos.Y -ge 0 -and $finalPos.Y -lt $copy.ClientSize.Height)
    $complete=($copy.Text -match '8\. Release status' -and
       $copy.Text -match 'separate permissions')
    $script:result=[ordered]@{
      status='PASS';physical_dpi=[int]$window.DeviceDpi
      close_visible=$inside;footer_overlap=$overlap
      heading_styled=$headingStyled;body_not_bold=$bodyPlain
      final_character_visible=$lastVisible;all_terms_preserved=$complete
    }
   }catch{$script:result=[ordered]@{status='FAIL';error=$_.Exception.Message}}
   finally{$window.Close()}
  })
 })
'@
$show=' try{[void]$window.ShowDialog($form)}finally{$copy.Dispose();$window.Dispose()}'
if(-not $body.Contains($show)){throw 'Terms dialog display statement changed'}
$body=$body.Replace($show,($insertion+[Environment]::NewLine+$show))
$form=New-Object System.Windows.Forms.Form
$form.Text='Doxa Terms UI contract'
$form.ClientSize=New-Object Drawing.Size(980,700)
$form.StartPosition='CenterScreen'
$form.Show()
try{Invoke-Expression $body}finally{$form.Close();$form.Dispose()}
if(-not $script:result){throw 'Terms window did not initialise'}
$r=$script:result
if($r.status -ne 'PASS' -or -not $r.close_visible -or $r.footer_overlap -or
   -not $r.heading_styled -or -not $r.body_not_bold -or
   -not $r.final_character_visible -or -not $r.all_terms_preserved){
 throw ('Terms window geometry/content failed: '+($r|ConvertTo-Json -Compress))
}
[ordered]@{
 status='PASS';text_scale_percent=$TextScalePercent
 requested_window=($WindowWidth.ToString()+'x'+$WindowHeight.ToString())
 actual_physical_dpi=$r.physical_dpi
 close_visible=$r.close_visible;no_footer_overlap=(-not $r.footer_overlap)
 headings_styled=$r.heading_styled;body_plain=$r.body_not_bold
 last_line_visible=$r.final_character_visible
 legal_text_complete=$r.all_terms_preserved
 driver_installs=0;display_setting_changes=0
}|ConvertTo-Json -Compress
