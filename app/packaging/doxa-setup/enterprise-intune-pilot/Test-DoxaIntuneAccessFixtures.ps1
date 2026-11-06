# Offline, non-network test of the delegated Graph Intune status reader.
# Mocks the Microsoft endpoints and signs into no real account.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$client=Join-Path $PSScriptRoot 'Check-DoxaIntuneAccess.ps1'
$global:DoxaIntuneFixture='empty'
function global:Start-Sleep {param([int]$Seconds)}
function global:Invoke-RestMethod {
 param([string]$Method,[string]$Uri,[string]$ContentType,$Body,$Headers,[int]$TimeoutSec)
 if($Uri -match 'well-known/openid-configuration'){
  return [pscustomobject]@{device_authorization_endpoint='https://mock.local/device-authorization';token_endpoint='https://mock.local/token'}
 }
 if($Uri -eq 'https://mock.local/device-authorization'){
  return [pscustomobject]@{verification_uri='https://login.microsoft.com/device';user_code='MOCK_ONLY';device_code='none';expires_in=25;interval=5}
 }
 if($Uri -eq 'https://mock.local/token'){return [pscustomobject]@{access_token='IN_MEMORY_MOCK_NOT_REAL'}}
 if($Uri -match 'deviceAppManagement/mobileApps'){return [pscustomobject]@{value=@()}}
 if($Uri -match 'deviceManagement/managedDevices'){
  $d=[pscustomobject]@{deviceName=$env:COMPUTERNAME;managementAgent='mdm';complianceState='unknown';enrolledDateTime='2026-10-24T18:42:00Z';lastSyncDateTime='2026-10-24T19:00:00Z'}
  if($global:DoxaIntuneFixture -eq 'empty'){return [pscustomobject]@{value=@()}}
  if($global:DoxaIntuneFixture -eq 'dell'){return [pscustomobject]@{value=@($d)}}
  if($global:DoxaIntuneFixture -eq 'nextPage'){return [pscustomobject]@{value=@();'@odata.nextLink'='https://example.invalid/next'}}
 }
 throw ('Unexpected mock request: '+$Uri)
}
try{
 foreach($case in @('empty','dell','nextPage')){
  $global:DoxaIntuneFixture=$case
  $output=@(& $client -Authenticate)
  # Extract exactly the JSON section, avoiding login preview lines.
  $text=$output -join [Environment]::NewLine
  $start=$text.IndexOf('{')
  if($start -lt 0){throw ('JSON not returned for '+$case)}
  $v=$text.Substring($start) | ConvertFrom-Json
  if($v.status -ne 'INTUNE_READ_ONLY_RESULT' -or $null -eq $v.checks.managed_devices.PSObject.Properties['response'] -or $v.checks.managed_devices.response -ne 'READ_OK'){
   Write-Output ('FIXTURE_CHECKS='+($v.checks|ConvertTo-Json -Compress))
   throw ('Wrong Graph status: '+$case)
  }
  if($case -eq 'empty' -and ($v.checks.managed_devices.dell_found_on_first_page -or $v.checks.managed_devices.more_pages)){throw 'Empty list regression'}
  if($case -eq 'dell' -and (-not $v.checks.managed_devices.dell_found_on_first_page -or $v.checks.managed_devices.more_pages)){throw 'Dell found regression'}
  if($case -eq 'nextPage' -and (-not $v.checks.managed_devices.more_pages -or $v.checks.managed_devices.dell_found_on_first_page)){throw 'Pagination regression'}
 }
 'DOXA_INTUNE_GRAPH_READ_FIXTURES=PASS (3 scenarios, zero real authentication)'
}finally{
 Remove-Variable DoxaIntuneFixture -Scope Global -ErrorAction SilentlyContinue
 Remove-Item Function:\Invoke-RestMethod -ErrorAction SilentlyContinue
 Remove-Item Function:\Start-Sleep -ErrorAction SilentlyContinue
}
