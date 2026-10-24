param(
 [Parameter(Mandatory=$true)][string]$Subject,
 [Parameter(Mandatory=$true)][string]$CacheRoot,
 [Parameter(Mandatory=$true)][string]$Needle,
 [ValidateRange(1,12)][int]$DecompileLimit=4
)
$ErrorActionPreference="Stop"
$subject=(Resolve-Path $Subject).Path
$sha=(Get-FileHash $subject -Algorithm SHA256).Hash
$cache=[IO.Path]::GetFullPath($CacheRoot)
New-Item -ItemType Directory -Force $cache|Out-Null
$project="Ghidra_"+$sha.Substring(0,12)
$projFile=Join-Path $cache ($project+".gpr")
$gh=[Environment]::GetEnvironmentVariable("GHIDRA_INSTALL_DIR","User")
$java=[Environment]::GetEnvironmentVariable("JAVA_HOME","User")
if(-not$gh -or -not$java){throw "Ghidra/Java configuration missing"}
$env:JAVA_HOME=$java
$env:Path=(Join-Path $java "bin")+";"+$env:Path
$headless=Join-Path $gh "support\analyzeHeadless.bat"
$scripts=Join-Path $PSScriptRoot "ghidra_scripts"
$safe=($Needle -replace '[^A-Za-z0-9._-]','_')
$out=Join-Path $cache ("xref_"+$safe+".json")
$stdout=Join-Path $cache ("xref_"+$safe+".stdout.txt")
$stderr=Join-Path $cache ("xref_"+$safe+".stderr.txt")
$args=@($cache,$project)
$mode="warm"
if(-not(Test-Path $projFile)){
 $mode="cold"
 $args+=@("-import",$subject,"-analysisTimeoutPerFile","1200")
}else{
 $args+=@("-process",[IO.Path]::GetFileName($subject),"-noanalysis","-readOnly")
}
$args+=@("-scriptPath",$scripts,"-postScript","StringXrefExtract.java",$out,$Needle,[string]$DecompileLimit)
$sw=[Diagnostics.Stopwatch]::StartNew()
& $headless @args 1>$stdout 2>$stderr
$exit=$LASTEXITCODE;$sw.Stop()
$summary=[ordered]@{mode=$mode;exit_code=$exit;elapsed_seconds=[math]::Round($sw.Elapsed.TotalSeconds,3);sha256=$sha;output=$out;project=$projFile}
$summary|ConvertTo-Json|Set-Content -Encoding UTF8 (Join-Path $cache ("xref_"+$safe+"_timing.json"))
Write-Host ($summary|ConvertTo-Json -Compress)
if($exit-ne0){Get-Content $stdout -Tail 40;Get-Content $stderr -Tail 40;exit $exit}
if(-not(Test-Path $out)){throw "No xref output created"}