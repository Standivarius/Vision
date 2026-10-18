# One-time owner-approved Windows elevation; never executes repo-writable code as SYSTEM.
param([switch]$Uninstall,[switch]$NoImmediateHandoff)
$ErrorActionPreference='Stop'
$taskName='VisionConsoleRecovery'
$root=Join-Path $env:ProgramData 'StandivariusVisionConsoleRecovery'
$source=Join-Path $PSScriptRoot 'Recover-VisionConsole.ps1'
$destination=Join-Path $root 'Recover-VisionConsole.ps1'
$p=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if(-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
 Write-Error 'Run once as administrator (Start-Process -Verb RunAs).'
 exit 5
}
if($Uninstall){
 $old=Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
 if($old){Unregister-ScheduledTask -TaskName $taskName -Confirm:$false}
 Write-Host "REMOVED $taskName. Historical logs preserved: $root"
 exit 0
}
if(-not(Test-Path $source)){throw "Source missing: $source"}
[void][IO.Directory]::CreateDirectory($root)
$acl=New-Object Security.AccessControl.DirectorySecurity
$acl.SetAccessRuleProtection($true,$false)
$adminOwner=[Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
$acl.SetOwner($adminOwner)
foreach($grant in @(
  @{sid='S-1-5-18';rights='FullControl'},
  @{sid='S-1-5-32-544';rights='FullControl'},
  @{sid='S-1-5-32-545';rights='ReadAndExecute'}
)){
 $sid=[Security.Principal.SecurityIdentifier]::new($grant.sid)
 $rule=[Security.AccessControl.FileSystemAccessRule]::new($sid,[Security.AccessControl.FileSystemRights]$grant.rights,[Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit',[Security.AccessControl.PropagationFlags]::None,[Security.AccessControl.AccessControlType]::Allow)
 $acl.AddAccessRule($rule)
}
Set-Acl -Path $root -AclObject $acl
Copy-Item -LiteralPath $source -Destination $destination -Force
# SYSTEM-executed script owner must be Administrators, not the creator/user.
$fileAcl=Get-Acl -LiteralPath $destination
$fileAcl.SetOwner($adminOwner)
Set-Acl -LiteralPath $destination -AclObject $fileAcl
$actual=Get-Acl -LiteralPath $destination
if($actual.GetOwner([Security.Principal.SecurityIdentifier]).Value -ne 'S-1-5-32-544'){
 throw 'SYSTEM executable script owner must be Administrators'
}
foreach($ace in $actual.Access){
 if($ace.IdentityReference.Value -match 'S-1-5-32-545|\\Users$' -and ($ace.FileSystemRights -band [Security.AccessControl.FileSystemRights]::Write) -ne 0){
  throw 'Unsafe ACL: Users can write SYSTEM executable script'
 }
}
$action=New-ScheduledTaskAction -Execute (Join-Path $env:windir 'System32\WindowsPowerShell\v1.0\powershell.exe') -Argument ('-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$destination+'"')
$trigger=New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration (New-TimeSpan -Days 3650)
$principal=New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings=New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew
$task=Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force
if(-not $task){throw 'Scheduled task installation failed'}
try{
 $t=Get-ScheduledTask -TaskName 'VisionOpenAITunnelKeepalive' -ErrorAction SilentlyContinue
 if($t -and $t.State -ne 'Running'){Start-ScheduledTask -TaskName 'VisionOpenAITunnelKeepalive';Write-Host 'Started existing Vision tunnel keepalive'}
}catch{Write-Warning 'Tunnel keepalive check could not complete'}
$probe=@(& powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $destination -Probe)
$check=Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
@{status='INSTALLED';task=$taskName;principal=$check.Principal.UserId;runlevel=[string]$check.Principal.RunLevel;task_state=[string]$check.State;script_path=$destination;hash=(Get-FileHash $destination -Algorithm SHA256).Hash;probe=($probe -join '');auto_recovery='one disconnected owner session only';security='no unlock, no drivers, no Windows policy change'}|ConvertTo-Json -Depth 5
if(-not $NoImmediateHandoff){
 $mySession=[Diagnostics.Process]::GetCurrentProcess().SessionId
 $quser=(quser.exe 2>&1|Out-String)
 $myActiveRdp=@($quser -split [char]10|Where-Object{$_ -match ('^\s*>?\s*DELL\s+rdp-\S+\s+'+$mySession+'\s+Active\b')})
 if($myActiveRdp.Count){
   Write-Host "Console transfer after installation: session $mySession"
   & (Join-Path $env:windir 'System32\tscon.exe') $mySession /dest:console
 }
}

