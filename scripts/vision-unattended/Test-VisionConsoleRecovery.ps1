# Zero-side-effect tests for owner-only disconnected session recovery policy.
$ErrorActionPreference='Stop'
$script=Join-Path $PSScriptRoot 'Recover-VisionConsole.ps1'
function Check([string]$name,[string[]]$sessions,[string]$expected){
 $global:VisionMockQuser=$sessions
 function global:quser.exe {
   $global:LASTEXITCODE=0
   return $global:VisionMockQuser
 }
 try{
  $text=(& $script -Probe|Out-String).Trim()
  if($LASTEXITCODE -ne 0){throw "Probe exit=$LASTEXITCODE"}
  $r=$text|ConvertFrom-Json
  if($r.status -ne $expected){throw "$name got $($r.status), expected $expected"}
  if($r.would_recover -ne ($expected -eq 'READY_TO_RECOVER')){throw "$name bad mutation flag"}
  Write-Host "PASS $name $expected"
 }finally{
  Remove-Item Function:\quser.exe -ErrorAction SilentlyContinue
  Remove-Variable -Name VisionMockQuser -Scope Global -ErrorAction SilentlyContinue
 }
}
$header='USERNAME SESSIONNAME ID STATE IDLE LOGON'
Check 'disconnected single owner' @($header,'DELL                 2 Disc . 10/18/2026') 'READY_TO_RECOVER'
Check 'active remote session' @($header,'DELL rdp-tcp#1 2 Active . 10/18/2026') 'RDP_ACTIVE_DO_NOT_INTERRUPT'
Check 'active physical console' @($header,'DELL console 2 Active . 10/18/2026') 'CONSOLE_ALREADY_ACTIVE'
Check 'no owner session' @($header,'other console 3 Active . 10/18/2026') 'CONSOLE_ALREADY_ACTIVE'
Check 'multiple disconnected owner sessions' @($header,'DELL 2 Disc . 10/18/2026','DELL 4 Disc . 10/18/2026') 'AMBIGUOUS_MULTIPLE_DISCONNECTED_SESSIONS'
# Compile installer task specification without registration/elevation, no mutation.
$trigger=New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration (New-TimeSpan -Days 3650)
$principal=New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
if($trigger.Repetition.Interval -ne 'PT1M' -or $principal.UserId -ne 'SYSTEM'){throw 'Task specification invalid'}
'PASS recovery task specification'

