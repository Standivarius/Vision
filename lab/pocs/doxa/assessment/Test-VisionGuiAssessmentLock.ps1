param([switch]$Probe)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Enter-VisionGuiAssessmentLock.ps1')

if($Probe){
    try{
        $m=Enter-VisionGuiAssessmentLock
        Exit-VisionGuiAssessmentLock -Mutex $m
        exit 0
    }catch{
        if($_.Exception.Message -like '*Another Vision desktop GUI assessment*'){
            exit 2
        }
        exit 3
    }
}

$first=Enter-VisionGuiAssessmentLock
try{
    $child=Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$PSCommandPath+'"'),'-Probe') -Wait -PassThru -WindowStyle Hidden
    if($child.ExitCode -ne 2){throw ('Cross-process contention expected exit 2, got '+$child.ExitCode)}
}finally{
    Exit-VisionGuiAssessmentLock -Mutex $first
}
$after=Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$PSCommandPath+'"'),'-Probe') -Wait -PassThru -WindowStyle Hidden
if($after.ExitCode -ne 0){throw ('After release expected exit 0, got '+$after.ExitCode)}
[pscustomobject]@{status='PASS';second_process_blocked=$true;subsequent_process_acquired=$true}|ConvertTo-Json -Compress
