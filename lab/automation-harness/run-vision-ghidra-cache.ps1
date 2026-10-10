param(
 [Parameter(Mandatory=$true)][string]$Subject,
 [Parameter(Mandatory=$true)][string]$RunDir,
 [ValidateSet("Cold","Warm")][string]$Mode="Warm",
 [ValidateSet("metadata","deep")][string]$QueryMode="metadata"
)
$ErrorActionPreference="Stop"
$full=Resolve-Path $Subject
$sha=(Get-FileHash $full -Algorithm SHA256).Hash
$run=[IO.Path]::GetFullPath($RunDir)
New-Item -ItemType Directory -Force $run|Out-Null
$cache=Join-Path $run ("ghidra_cache_"+$sha.Substring(0,12))
New-Item -ItemType Directory -Force $cache|Out-Null
$project="VisionCache_"+$sha.Substring(0,12)
$gh=[Environment]::GetEnvironmentVariable("GHIDRA_INSTALL_DIR","User")
$java=[Environment]::GetEnvironmentVariable("JAVA_HOME","User")
if(-not$gh -or -not$java){throw "Ghidra/Java configuration missing"}
$env:JAVA_HOME=$java
$env:Path=(Join-Path $java "bin")+";"+$env:Path
$headless=Join-Path $gh "support\analyzeHeadless.bat"
$scripts=Join-Path $PSScriptRoot "ghidra_scripts"
$out=Join-Path $run ("cache_"+$Mode.ToLower()+"_"+$QueryMode+"_result.json")
$stdout=Join-Path $run ("cache_"+$Mode.ToLower()+"_"+$QueryMode+"_stdout.txt")
$stderr=Join-Path $run ("cache_"+$Mode.ToLower()+"_"+$QueryMode+"_stderr.txt")
$procArgs=@($cache,$project)
if($Mode -eq "Cold"){
 $procArgs+=@("-import",$full.Path,"-analysisTimeoutPerFile","600")
}else{
 $projFile=Join-Path $cache ($project+".gpr")
 if(-not(Test-Path $projFile)){throw "No saved Ghidra project at $projFile"}
 $procArgs+=@("-process",[IO.Path]::GetFileName($full.Path),"-noanalysis","-readOnly")
}
$procArgs+=@("-scriptPath",$scripts,"-postScript","VisionCacheExtract.java",$out,$QueryMode)
$timer=[Diagnostics.Stopwatch]::StartNew()
& $headless @procArgs 1>$stdout 2>$stderr
$exit=$LASTEXITCODE
$timer.Stop()
$summary=[ordered]@{mode=$Mode;query_mode=$QueryMode;exit_code=$exit;elapsed_seconds=[math]::Round($timer.Elapsed.TotalSeconds,3);sha256=$sha;extract_exists=(Test-Path $out);project_exists=(Test-Path (Join-Path $cache ($project+".gpr")))}
$summary|ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $run ("cache_"+$Mode.ToLower()+"_"+$QueryMode+"_timing.json"))
Write-Host ($summary|ConvertTo-Json -Compress)
if($exit-ne0){Get-Content $stdout -Tail 30;Get-Content $stderr -Tail 30;exit $exit}
if(-not(Test-Path $out)){throw "Ghidra script produced no result"}