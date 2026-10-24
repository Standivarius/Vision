param(
 [string]$TenantId='',
 [switch]$Authenticate
)
# Read-only DMR Intune access gate. No new tenant or Azure subscription.
# With -Authenticate: Microsoft first-party Graph CLI device-code sign-in.
# Only requests DeviceManagementManagedDevices.Read.All and DeviceManagementApps.Read.All.
# Never prints or persists auth tokens. Lists only the first Intune device page and outputs the current Dell's summary; no Graph writes.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(-not $TenantId){
 # Derive the currently workplace-registered tenant without embedding its identifier in Git.
 $line=@(dsregcmd /status | Where-Object {$_ -match '^\s*WorkplaceTenantId\s*:'}|Select-Object -First 1)
 if($line.Count -eq 1 -and $line[0] -match '([a-fA-F0-9]{8}-(?:[a-fA-F0-9]{4}-){3}[a-fA-F0-9]{12})'){$TenantId=$Matches[1]}
}
if($TenantId -notmatch '^[a-fA-F0-9]{8}-(?:[a-fA-F0-9]{4}-){3}[a-fA-F0-9]{12}$'){throw 'Valid tenant GUID required; pass -TenantId if the Windows device is not workplace registered.'}
$clientId='14d82eec-204b-4c2f-b7e8-296a70dab67e' # Microsoft Graph Command Line Tools
$authority='https://login.microsoftonline.com/'+$TenantId+'/oauth2/v2.0/'
$metadata=Invoke-RestMethod -Method Get -Uri ('https://login.microsoftonline.com/'+$TenantId+'/v2.0/.well-known/openid-configuration') -TimeoutSec 25
if(-not $metadata.device_authorization_endpoint -or -not $metadata.token_endpoint){throw 'Microsoft sign-in metadata lacks device-code endpoints'}
if(-not $Authenticate){
 [ordered]@{
  status='AUTHENTICATION_NOT_STARTED'
  tenant_id=$TenantId
  microsoft_authority_reachable=$true
  graph_app='Microsoft Graph Command Line Tools (Microsoft first-party)'
  requested_permissions=@('DeviceManagementManagedDevices.Read.All','DeviceManagementApps.Read.All')
  tenant_configuration_read=$false
  tenant_modified=$false
  guidance='Rerun with -Authenticate only when the account owner can complete Microsoft device-code sign-in and any admin consent.'
 }|ConvertTo-Json -Depth 3
 return
}
$scope='https://graph.microsoft.com/DeviceManagementManagedDevices.Read.All https://graph.microsoft.com/DeviceManagementApps.Read.All'
$flow=Invoke-RestMethod -Method Post -Uri ([string]$metadata.device_authorization_endpoint) -ContentType 'application/x-www-form-urlencoded' -Body @{client_id=$clientId;scope=$scope} -TimeoutSec 25
Write-Output ('SIGN_IN_URL='+[string]$flow.verification_uri)
Write-Output ('DEVICE_CODE='+[string]$flow.user_code)
Write-Output 'Sign in with DMR Ergonomics Microsoft admin, check the requested read-only permissions, and approve only if authorised.'
$deadline=[DateTime]::UtcNow.AddSeconds([int]$flow.expires_in)
$interval=[math]::Max(5,[int]$flow.interval)
$accessToken=$null
try{
 while([DateTime]::UtcNow -lt $deadline){
  Start-Sleep -Seconds $interval
  $tokenResponse=$null
  try{
   $tokenResponse=Invoke-RestMethod -Method Post -Uri ([string]$metadata.token_endpoint) -ContentType 'application/x-www-form-urlencoded' -Body @{client_id=$clientId;grant_type='urn:ietf:params:oauth:grant-type:device_code';device_code=[string]$flow.device_code} -TimeoutSec 25
  }catch{
   $errorBody=''
   try{$reader=New-Object IO.StreamReader($_.Exception.Response.GetResponseStream());$errorBody=$reader.ReadToEnd()}catch{}
   $known='authorization_pending'
   try{$known=[string](ConvertFrom-Json -InputObject $errorBody).error}catch{}
   if($known -eq 'authorization_pending'){continue}
   if($known -eq 'slow_down'){$interval+=5;continue}
   if($known -eq 'authorization_declined'){throw 'Microsoft sign-in declined; nothing changed'}
   if($known -eq 'expired_token'){throw 'Microsoft sign-in expired; rerun when ready'}
   throw ('Microsoft authentication did not complete: '+$known)
  }
  if($tokenResponse.access_token){$accessToken=[string]$tokenResponse.access_token;break}
 }
 if(-not $accessToken){throw 'Sign-in timed out without completing'}
 $headers=@{Authorization=('Bearer '+$accessToken);Accept='application/json'}
 $queries=[ordered]@{
  intune_apps='https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps?$top=1'
  managed_devices='https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?$top=100'
 }
 $results=[ordered]@{}
 foreach($name in $queries.Keys){
  try{
   $result=Invoke-RestMethod -Method Get -Uri $queries[$name] -Headers $headers -TimeoutSec 25
   if($name -eq 'managed_devices'){
    $matches=@($result.value | Where-Object {[string]$_.deviceName -ieq $env:COMPUTERNAME})
    $results[$name]=[ordered]@{
     response='READ_OK'
     first_page_count=@($result.value).Count
     more_pages=($null -ne $result.PSObject.Properties['@odata.nextLink'] -and [bool]$result.'@odata.nextLink')
     dell_found_on_first_page=($matches.Count -gt 0)
     dell=if($matches.Count){@($matches|ForEach-Object {[ordered]@{device_name=[string]$_.deviceName;management_agent=[string]$_.managementAgent;compliance=[string]$_.complianceState;enrolled=[string]$_.enrolledDateTime;last_sync=[string]$_.lastSyncDateTime}})}else{@()}
    }
   } else { $results[$name]='READ_OK (at least '+@($result.value).Count+' app(s) returned on first page)' }
  }catch{
   $httpStatus=$null
   if($null -ne $_.Exception.PSObject.Properties['Response']){
    try{$httpStatus=[int]$_.Exception.Response.StatusCode}catch{}
   }
   if($null -ne $httpStatus){$results[$name]='HTTP_'+$httpStatus}
   else{$results[$name]='CLIENT_ERROR_'+$_.Exception.GetType().Name}
   # Keep diagnostics in the process, but do not print response bodies or tokens.
  }
 }
 [ordered]@{
  status='INTUNE_READ_ONLY_RESULT'
  tenant_id=$TenantId
  permission_scope='read_only'
  checks=$results
  tenant_modified=$false
  credentials_saved=$false
 }|ConvertTo-Json -Depth 4
}finally{
 $accessToken=$null
 $tokenResponse=$null
 $flow=$null
}
