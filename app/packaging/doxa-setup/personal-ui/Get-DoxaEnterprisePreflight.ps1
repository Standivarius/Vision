param(
 [string]$EvidencePath=''
)
# Read-only enterprise preflight contract. No tenant login, policy changes, or installation.
# Windows-only factual observations, independent of Remote Desktop display arrangement.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$personal=Join-Path $PSScriptRoot 'Get-DoxaSetupExperience.ps1'
$arguments=@{Fault='none';Language='en'}
if($EvidencePath){$arguments.EvidencePath=$EvidencePath}
$report=(& $personal @arguments | Out-String) | ConvertFrom-Json
$obs=$report.observed
$hardware=$obs.hardware_ready
$code=if($report.code -eq 'unsupported_windows'){'unsupported_windows'}
 elseif($report.code -eq 'driver_untrusted'){'untrusted_driver_requires_it'}
 elseif($report.code -eq 'driver_missing'){'driver_not_observed'}
 elseif($obs.signed_driver_present -and $obs.pnp_doxa_panels_missing.Count -gt 0){'driver_present_some_panels_unavailable'}
 elseif($hardware){'verified_signed_driver_and_hardware'}
 else{'diagnostics_inconclusive'}
$next=if($code -eq 'verified_signed_driver_and_hardware'){
 'No driver installation indicated. Verify interactive-session graphics only on a local physical console.'
} elseif($code -eq 'driver_present_some_panels_unavailable'){
 'Driver identity is valid; check hardware power/cables before considering driver installation.'
} elseif($code -eq 'driver_not_observed'){
 'Check driver store and device inventory; install only a separately approved package through Windows/Intune.'
} else {
 'Do not deploy blindly. Review security and hardware evidence through authorized IT tools.'
}
[ordered]@{
 schema_version=1
 diagnostic_purpose='intune_preflight_read_only'
 decision_code=$code
 next_step=($next+$(if([string]$obs.driver_version_qualification -eq 'signed_version_unreviewed'){
  ' Signed driver version is unreviewed by Doxa; do not automatically downgrade or replace working hardware. An approved IT MSI manifest is still required for deployment.'
 }else{''}))
 driver_version_qualification=[string]$obs.driver_version_qualification
 driver_version_review_needed=[bool]$obs.driver_version_review_needed
 hardware_ready=[bool]$hardware
 signed_driver_present=[bool]$obs.signed_driver_present
 driver_version=[string]$obs.driver_version
 pnp_doxa_panel_count=@($obs.pnp_doxa_panels).Count
 pnp_doxa_panels_missing=@($obs.pnp_doxa_panels_missing)
 session_kind=[string]$obs.session_kind
 remote_desktop_count_is_not_physical_topology=([string]$obs.session_kind -eq 'remote')
 app_control_policy='not_checked'
 tenant_intune_license='not_checked'
 driver_redistribution_approval='not_granted'
 signed_package_approval='not_granted'
 machine_mutation_performed=$false
 authorization_required_before_install=$true
} | ConvertTo-Json -Depth 8
