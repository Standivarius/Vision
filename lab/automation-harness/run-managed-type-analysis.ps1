param(
 [Parameter(Mandatory=$true)][string]$Assembly,
 [Parameter(Mandatory=$true)][string]$OutputDir,
 [string[]]$Types=@(),
 [string]$Filter='Caret|Focus|Tracking|TextSelection|ScreenModel|Ahoi|UIA|Magnif|Event'
)
$ErrorActionPreference='Stop'
$assemblyPath=(Resolve-Path $Assembly).Path
$outDir=[IO.Path]::GetFullPath($OutputDir)
New-Item -ItemType Directory -Force $outDir|Out-Null
$cmd='C:\tools\ilspycmd-11.1\tools\net10.0\any\ilspycmd.dll'
if(-not(Test-Path $cmd)){throw "ilspycmd missing: $cmd"}
$base=[IO.Path]::GetFileName($assemblyPath)
$typeList=Join-Path $outDir ('types_'+$base+'.txt')
$sw=[Diagnostics.Stopwatch]::StartNew()
& dotnet $cmd -l c $assemblyPath | Set-Content -Encoding UTF8 $typeList
& dotnet $cmd -l i $assemblyPath | Add-Content -Encoding UTF8 $typeList
$decomp=@()
foreach($type in $Types){
 $safe=($type -replace '[^A-Za-z0-9._-]','_')
 $out=Join-Path $outDir ('type_'+$safe+'.cs')
 & dotnet $cmd -t $type $assemblyPath | Set-Content -Encoding UTF8 $out
 if($LASTEXITCODE-ne0){throw "ilspycmd failed for $type"}
 $decomp += [pscustomobject]@{type=$type;path=$out;bytes=(Get-Item $out).Length}
}
$sw.Stop()
$hits=@(Select-String -Path $typeList -Pattern $Filter -CaseSensitive:$false|ForEach-Object{$_.Line})
$result=[ordered]@{
 assembly=$assemblyPath
 sha256=(Get-FileHash $assemblyPath -Algorithm SHA256).Hash
 elapsed_seconds=[math]::Round($sw.Elapsed.TotalSeconds,3)
 type_list=$typeList
 relevant_types=$hits
 decompiled_types=$decomp
}
$result|ConvertTo-Json -Depth 5|Set-Content -Encoding UTF8 (Join-Path $outDir ('managed_analysis_'+$base+'.json'))
Write-Host ($result|ConvertTo-Json -Depth 5 -Compress)