# One desktop GUI assessment at a time across all PowerShell sessions on
# this interactive Windows desktop. Independent of Vision bridge health.
$ErrorActionPreference='Stop'

function Enter-VisionGuiAssessmentLock {
    $name='Local\StandivariusVisionGuiAssessmentV1'
    $mutex=[System.Threading.Mutex]::new($false,$name)
    $owned=$false
    try {
        try {
            $owned=$mutex.WaitOne(0)
        }catch [System.Threading.AbandonedMutexException] {
            # Previous holder crashed or was killed; OS released the lock.
            $owned=$true
        }
        if(-not $owned){
            throw 'BLOCKED: Another Vision desktop GUI assessment is already running'
        }
        return $mutex
    }catch{
        if(-not $owned){$mutex.Dispose()}
        throw
    }
}

function Exit-VisionGuiAssessmentLock {
    param([Parameter(Mandatory=$true)][System.Threading.Mutex]$Mutex)
    try {
        $Mutex.ReleaseMutex()
    }finally{
        $Mutex.Dispose()
    }
}
