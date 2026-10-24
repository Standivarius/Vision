param(
 [Parameter(Mandatory=$true)][string]$Subject,
 [Parameter(Mandatory=$true)][string]$OutputDir,
 [ValidateSet("stock","vision-domain")][string]$Mode="stock"
)
$ErrorActionPreference="Stop"
$capa="C:\tools\capa-vision-venv\Scripts\capa.exe"
$sigs="C:\tools\capa-sigs-v9.4.0"
$stock="C:\tools\capa-rules-v9.4.0\capa-rules-9.4.0"
$domain=Join-Path $PSScriptRoot "capa_rules"
if(-not(Test-Path $capa)){throw "capa executable missing: $capa"}
if(-not(Test-Path $sigs)){throw "capa signatures missing: $sigs"}
$rules=if($Mode -eq "stock"){$stock}else{$domain}
$subjectPath=(Resolve-Path $Subject).Path
$outDir=[IO.Path]::GetFullPath($OutputDir)
New-Item -ItemType Directory -Force $outDir|Out-Null
$json=Join-Path $outDir ("capa_"+$Mode+".json")
$stderr=Join-Path $outDir ("capa_"+$Mode+".stderr.txt")
$args=@("-r",$rules,"-s",$sigs,"-j",$subjectPath)
$sw=[Diagnostics.Stopwatch]::StartNew()
$p=Start-Process $capa -ArgumentList $args -Wait -PassThru -NoNewWindow -RedirectStandardOutput $json -RedirectStandardError $stderr
$sw.Stop()
$summary=[ordered]@{mode=$Mode;exit_code=$p.ExitCode;seconds=[math]::Round($sw.Elapsed.TotalSeconds,3);sha256=(Get-FileHash $subjectPath -Algorithm SHA256).Hash;json_bytes=(Get-Item $json).Length}
$summary|ConvertTo-Json|Set-Content -Encoding UTF8 (Join-Path $outDir ("capa_"+$Mode+"_timing.json"))
Write-Host ($summary|ConvertTo-Json -Compress)
exit $p.ExitCode