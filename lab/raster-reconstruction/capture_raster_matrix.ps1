param([int[]]$Zooms=@(2,3,4),[int[]]$Modes=@(0,1,2,3))
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
$repo=Resolve-Path (Join-Path $PSScriptRoot '..\..')
$exe=Join-Path $repo 'app\build\Release\visual_app.exe'
$edge='C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
if(-not(Test-Path $edge)){$edge='C:\Program Files\Microsoft\Edge\Application\msedge.exe'}
$fixture=(Resolve-Path (Join-Path $PSScriptRoot 'text_quality_fixture.html')).Path
$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss';$out=Join-Path $repo "lab\benchmarks\raster_reconstruction\runs\$($stamp)__text_matrix";New-Item -ItemType Directory -Force $out|Out-Null
$screens=@([Windows.Forms.Screen]::AllScreens);if($screens.Count-lt2){throw 'Two displays required'}
$source=$screens|Where-Object DeviceName -eq '\\.\DISPLAY1'|Select-Object -First 1;$dest=$screens|Where-Object DeviceName -eq '\\.\DISPLAY2'|Select-Object -First 1
if(-not$source){$source=$screens[0]};if(-not$dest){$dest=$screens[1]}
$url='file:///'+($fixture -replace '\\','/')
$edgeP=Start-Process $edge -ArgumentList @('--new-window',"--window-position=$($source.Bounds.X),$($source.Bounds.Y)","--window-size=$($source.Bounds.Width),$($source.Bounds.Height)",$url) -PassThru
Start-Sleep -Seconds 2
$rows=@()
try{
 foreach($z in $Zooms){foreach($m in $Modes){
  Get-Process visual_app -ErrorAction SilentlyContinue|Stop-Process -Force;Start-Sleep -Milliseconds 500
  $log=Join-Path $out "mode_$($m)_$($z)x.csv"
  $vp=Start-Process $exe -ArgumentList @('--source','0','--dest','1','--zoom',"$z",'--reconstruction',"$m",'--log',$log) -PassThru
  $deadline=(Get-Date).AddSeconds(5);$ready=$false
  while((Get-Date)-lt$deadline){
    if((Test-Path $log) -and (Select-String -Path $log -SimpleMatch '# event=first_render_frame' -Quiet -ErrorAction SilentlyContinue)){$ready=$true;break}
    if($vp.HasExited){break};Start-Sleep -Milliseconds 100
  }
  if(-not$ready){throw "Vision did not render mode=$m zoom=$z before capture"}
  Start-Sleep -Milliseconds 250
  $bmp=New-Object Drawing.Bitmap $dest.Bounds.Width,$dest.Bounds.Height
  $g=[Drawing.Graphics]::FromImage($bmp);$g.CopyFromScreen($dest.Bounds.X,$dest.Bounds.Y,0,0,$dest.Bounds.Size);$g.Dispose()
  $png=Join-Path $out "mode_$($m)_$($z)x.png";$bmp.Save($png,[Drawing.Imaging.ImageFormat]::Png);$bmp.Dispose()
  if(-not$vp.HasExited){Stop-Process $vp.Id -Force};Wait-Process -Id $vp.Id -ErrorAction SilentlyContinue;Start-Sleep -Milliseconds 400
  $fr=@(Import-Csv $log|Where-Object{$_.frame-match'^\d+$'})
  $rows += [pscustomobject]@{zoom=$z;mode=$m;frames=$fr.Count;present_fail=@($fr|Where-Object{[uint64]$_.present_hr-ne0}).Count;png=$png}
 }}
} finally { Get-Process visual_app -ErrorAction SilentlyContinue|Stop-Process -Force; if($edgeP -and -not$edgeP.HasExited){Stop-Process $edgeP.Id -Force -ErrorAction SilentlyContinue}}
$rows|Export-Csv -NoTypeInformation (Join-Path $out 'matrix.csv');$rows|Format-Table -AutoSize;Write-Output "OUTPUT=$out"
