
param([string]$CandidateSqVersion='')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest

$appRoot=Split-Path -Parent $PSScriptRoot
$repoRoot=Split-Path -Parent $appRoot

function Assert-Contains([string]$RelativePath,[string]$Needle,[string]$Label){
    $path=Join-Path $repoRoot $RelativePath
    if(-not(Test-Path $path -PathType Leaf)){throw "$Label missing file: $RelativePath"}
    $text=[IO.File]::ReadAllText($path)
    if(-not$text.Contains($Needle)){throw "$Label compatibility contract changed in $RelativePath; expected: $Needle"}
}

# Velopack continuity: these identities deliberately remain Visual for the current alpha line.
Assert-Contains 'app\version.cmake' 'set(VISUAL_PACKAGE_ID "Standivarius.Visual")' 'package id'
Assert-Contains 'app\version.cmake' 'set(VISUAL_RELEASE_CHANNEL "alpha")' 'release channel'
Assert-Contains 'app\packaging\package.ps1' "'--packId','Standivarius.Visual'" 'packId'
Assert-Contains 'app\packaging\package.ps1' "'--mainExe','visual_app.exe'" 'main executable'
Assert-Contains 'app\packaging\package.ps1' "'--channel','alpha'" 'package channel'

# Visible branding is Vision while the binary/internal identity remains compatible.
Assert-Contains 'app\packaging\package.ps1' "'--packTitle','Standivarius - Vision'" 'friendly title'
Assert-Contains 'app\src\version.rc.in' 'VALUE "InternalName", "Visual\0"' 'PE internal name'
Assert-Contains 'app\src\version.rc.in' 'VALUE "ProductName", "Standivarius - Vision\0"' 'PE product name'

# Existing user state, update policy and single-instance identities must remain readable.
Assert-Contains 'app\src\settings_store.cpp' 'root /= L"Standivarius";' 'settings vendor root'
Assert-Contains 'app\src\settings_store.cpp' 'root /= L"Visual";' 'settings compatibility root'
Assert-Contains 'app\src\velopack_entry.cpp' 'Local\\Standivarius.Visual.App.v1' 'application mutex'
Assert-Contains 'app\src\velopack_entry.cpp' 'L"VisualDetailWindow"' 'detail window class'
Assert-Contains 'app\src\velopack_entry.cpp' 'L"VISUAL_UPDATE_MODE"' 'update policy environment variable'
Assert-Contains 'app\src\velopack_entry.cpp' 'L"SOFTWARE\\Standivarius\\Visual"' 'update policy registry key'
Assert-Contains 'app\src\setup_orchestrator.cpp' 'Local\\Standivarius.Visual.Setup.v1' 'setup mutex'
Assert-Contains 'app\src\setup_orchestrator.cpp' 'return local / L"Standivarius" / L"Visual";' 'persistent product root'

# Deployed service/schema contracts are not branding surfaces.
Assert-Contains 'support\doxa-cloud\vision-assistant-worker\wrangler.toml' 'name = "doxa-visual-assistant"' 'assistant service name'
Assert-Contains 'app\src\setup_orchestrator.cpp' 'visual_installed' 'setup schema visual_installed'
Assert-Contains 'app\src\setup_orchestrator.cpp' 'visual_version' 'setup schema visual_version'

if($CandidateSqVersion){
    if(-not(Test-Path $CandidateSqVersion -PathType Leaf)){throw "Candidate sq.version not found: $CandidateSqVersion"}
    $sq=[IO.File]::ReadAllText((Resolve-Path $CandidateSqVersion))
    foreach($pair in @(
        @('<id>Standivarius.Visual</id>','candidate package id'),
        @('<title>Standivarius - Vision</title>','candidate friendly title'),
        @('<mainExe>visual_app.exe</mainExe>','candidate main executable'),
        @('<channel>alpha</channel>','candidate channel'),
        @('<shortcutAumid>velopack.Standivarius.Visual</shortcutAumid>','candidate AUMID')
    )){
        if(-not$sq.Contains($pair[0])){throw "$($pair[1]) mismatch in candidate sq.version"}
    }
}

Write-Host 'Vision branding compatibility guard OK: visible brand=Vision; alpha compatibility identity=Visual.'
