$ErrorActionPreference='Stop'
$root=Join-Path $PSScriptRoot 'tools\ffmpeg'
$exe=Get-ChildItem $root -Filter ffmpeg.exe -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1 -ExpandProperty FullName
if($exe){Write-Output $exe;exit 0}
$zip=Join-Path $PSScriptRoot 'tools\ffmpeg-release-essentials.zip'
New-Item -ItemType Directory -Force (Split-Path $zip -Parent)|Out-Null
Invoke-WebRequest -Uri 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' -OutFile $zip
New-Item -ItemType Directory -Force $root|Out-Null
Expand-Archive -Path $zip -DestinationPath $root -Force
Remove-Item $zip -Force
$exe=Get-ChildItem $root -Filter ffmpeg.exe -Recurse|Select-Object -First 1 -ExpandProperty FullName
if(-not$exe){throw 'ffmpeg provisioning failed'}
Write-Output $exe
