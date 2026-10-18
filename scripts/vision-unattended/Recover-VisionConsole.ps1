# Vision owner-authorised unattended RDP-to-physical-console recovery.
# Copied by installer to ACL-protected ProgramData; run as SYSTEM every minute.
# Never bypasses sign-in, touches display drivers, registry, or passwords.
param([switch]$Probe)
$ErrorActionPreference='Stop'
$log=Join-Path $PSScriptRoot 'console-recovery.log'
function Note([string]$message) {
  try {
    if((Test-Path $log) -and (Get-Item $log).Length -gt 1048576) {
      Move-Item $log ($log+'.previous') -Force
    }
    [IO.File]::AppendAllText($log, ((Get-Date -Format o)+' '+$message+[Environment]::NewLine))
  }catch{}
}
function Get-Sessions {
  $raw=@(quser.exe 2>&1)
  if($LASTEXITCODE -ne 0){throw "quser failed exit=$LASTEXITCODE"}
  $rows=@()
  foreach($line in $raw) {
    $clean=([string]$line).TrimStart('>',' ')
    # Matches DELL 2 Disc or DELL rdp-tcp#0 2 Active.
    if($clean -match '^(?<user>\S+)\s+(?:(?<name>\S+)\s+)?(?<id>\d+)\s+(?<state>Active|Disc|Conn)\b') {
      $rows+= [pscustomobject]@{
        user=[string]$Matches['user']
        name=[string]$Matches['name']
        id=[int]$Matches['id']
        state=[string]$Matches['state']
      }
    }
  }
  return $rows
}
try {
  # Self-heal only the existing Vision OpenAI tunnel keeper, never the other tunnel.
  if(-not $Probe){
    try {
      $keeper=Get-ScheduledTask -TaskName 'VisionOpenAITunnelKeepalive' -ErrorAction SilentlyContinue
      if($keeper -and $keeper.State -ne 'Running'){
        Start-ScheduledTask -TaskName 'VisionOpenAITunnelKeepalive'
        Note 'VISION_TUNNEL_KEEPALIVE_RESTARTED'
      }
    }catch{Note ('VISION_TUNNEL_KEEPALIVE_ERROR '+$_.Exception.GetType().Name)}
  }
  $sessions=@(Get-Sessions)
  $owners=@($sessions|Where-Object{$_.user -ieq 'DELL'})
  $disconnected=@($owners|Where-Object{$_.state -eq 'Disc'})
  $consoleInUse=@($sessions|Where-Object{
    $_.name -ieq 'console' -and $_.state -eq 'Active'
  })
  $rdpInUse=@($sessions|Where-Object{
    $_.name -like 'rdp-*' -and $_.state -eq 'Active'
  })
  $status=if($consoleInUse.Count){'CONSOLE_ALREADY_ACTIVE'}
          elseif($rdpInUse.Count){'RDP_ACTIVE_DO_NOT_INTERRUPT'}
          elseif($disconnected.Count -eq 1){'READY_TO_RECOVER'}
          elseif($disconnected.Count -eq 0){'NO_DISCONNECTED_OWNER_SESSION'}
          else{'AMBIGUOUS_MULTIPLE_DISCONNECTED_SESSIONS'}
  if($Probe){
    [pscustomobject]@{status=$status;session_ids=@($owners|ForEach-Object{
       [pscustomobject]@{id=$_.id;state=$_.state;name=$_.name}
    });would_recover=($status -eq 'READY_TO_RECOVER')}|ConvertTo-Json -Compress -Depth 5
    exit 0
  }
  if($status -ne 'READY_TO_RECOVER'){exit 0}
  $id=$disconnected[0].id
  $exe=Join-Path $env:windir 'System32\tscon.exe'
  if(-not(Test-Path $exe)){throw 'tscon.exe missing'}
  $p=Start-Process -FilePath $exe -ArgumentList @([string]$id,'/dest:console') -PassThru -Wait -WindowStyle Hidden
  if($p.ExitCode -eq 0){Note "TRANSFER_OK session=$id"}
  else{Note "TRANSFER_FAILED session=$id exit=$($p.ExitCode)"; exit $p.ExitCode}
}catch{
  Note ('RECOVERY_ERROR '+$_.Exception.GetType().Name+': '+$_.Exception.Message)
  exit 5
}

