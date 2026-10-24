$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type @'
using System;using System.Runtime.InteropServices;public class MoveWin{[DllImport("user32.dll")]public static extern bool MoveWindow(IntPtr h,int x,int y,int w,int hgt,bool repaint);}
'@
$repo=Resolve-Path (Join-Path $PSScriptRoot '..\..');$exe=Join-Path $repo 'app\build\Release\visual_app.exe'
$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss';$out=Join-Path $repo "lab\benchmarks\raster_reconstruction\runs\$($stamp)__office_shortlist";New-Item -ItemType Directory -Force $out|Out-Null
$screens=@([Windows.Forms.Screen]::AllScreens);$src=$screens|Where-Object DeviceName -eq '\\.\DISPLAY1'|Select-Object -First 1;$dst=$screens|Where-Object DeviceName -eq '\\.\DISPLAY2'|Select-Object -First 1
if(-not$src){$src=$screens[0]};if(-not$dst){$dst=$screens[1]}
function Capture([string]$app,[int]$z,[int]$m){
 Get-Process visual_app -ErrorAction SilentlyContinue|Stop-Process -Force;Start-Sleep -Milliseconds 500
 $log=Join-Path $out "$($app)_mode_$($m)_$($z)x.csv";$vp=Start-Process $exe -ArgumentList @('--source','0','--dest','1','--zoom',"$z",'--reconstruction',"$m",'--log',$log) -PassThru
 $deadline=(Get-Date).AddSeconds(5);$ready=$false;while((Get-Date)-lt$deadline){if((Test-Path $log)-and(Select-String -Path $log -Pattern '# event=first_render_frame' -SimpleMatch -Quiet -ErrorAction SilentlyContinue)){$ready=$true;break};if($vp.HasExited){break};Start-Sleep -Milliseconds 100};if(-not$ready){throw "No render $app mode=$m zoom=$z"};Start-Sleep -Milliseconds 250
 $bmp=New-Object Drawing.Bitmap $dst.Bounds.Width,$dst.Bounds.Height;$g=[Drawing.Graphics]::FromImage($bmp);$g.CopyFromScreen($dst.Bounds.X,$dst.Bounds.Y,0,0,$dst.Bounds.Size);$g.Dispose();$bmp.Save((Join-Path $out "$($app)_mode_$($m)_$($z)x.png"),[Drawing.Imaging.ImageFormat]::Png);$bmp.Dispose()
 if(-not$vp.HasExited){Stop-Process $vp.Id -Force};Wait-Process $vp.Id -ErrorAction SilentlyContinue;Start-Sleep -Milliseconds 450
}
$word=$null;$doc=$null;$excel=$null;$book=$null;$ws=$null;$nl=[Environment]::NewLine
try{
 $word=New-Object -ComObject Word.Application;$word.Visible=$true;$doc=$word.Documents.Add();$sel=$word.Selection
 $sel.Font.Name='Segoe UI';$sel.Font.Size=10;$sel.TypeText('Vision Word raster fixture'+$nl+'The quick brown fox jumps over the lazy dog. Il1 O0 rn m. 0123456789'+$nl)
 $sel.Font.Size=11;$sel.TypeText('Regular 11 pt: Customer account status, September 2026. Fine punctuation ,.;:!?()[]'+$nl)
 $sel.Font.Bold=1;$sel.TypeText('Bold 11 pt: TOTAL 1,234.56  REVIEW  COMPLETE'+$nl);$sel.Font.Bold=0
 $sel.Font.Name='Georgia';$sel.Font.Size=12;$sel.TypeText('Georgia 12 pt: Serif shapes expose ringing and stroke deformation.'+$nl)
 $sel.Font.Name='Consolas';$sel.Font.Size=10;$sel.TypeText('Consolas 10 pt: viewport = crop(x, y, width, height); 0O1Il'+$nl)
 $word.ActiveWindow.WindowState=0;$word.ActiveWindow.Left=0;$word.ActiveWindow.Top=0;$word.ActiveWindow.Width=1200;$word.ActiveWindow.Height=700;Start-Sleep -Seconds 1
 foreach($z in 2,4){foreach($m in 0,2,3){Capture 'word' $z $m}}
 $doc.Close(0);$word.Quit();[Runtime.InteropServices.Marshal]::ReleaseComObject($doc)|Out-Null;[Runtime.InteropServices.Marshal]::ReleaseComObject($word)|Out-Null;$doc=$null;$word=$null;Start-Sleep -Seconds 1
 $excel=New-Object -ComObject Excel.Application;$excel.Visible=$true;$book=$excel.Workbooks.Add();$ws=$book.Worksheets.Item(1)
 $data=@(@('Item','Q1','Q2','Q3','Total'),@('Revenue','128.42','132.08','141.77','402.27'),@('Margin','18.2%','19.7%','20.1%','19.3%'),@('Status','Review','Complete','Pending','Review'))
 for($rr=0;$rr-lt$data.Count;$rr++){for($cc=0;$cc-lt$data[$rr].Count;$cc++){$ws.Cells.Item($rr+1,$cc+1)=$data[$rr][$cc]}}
 $ws.Range('A1:E4').Font.Name='Segoe UI';$ws.Range('A1:E4').Font.Size=10;$ws.Range('A1:E1').Font.Bold=$true;$ws.Columns.Item('A:E').ColumnWidth=16
 $excel.WindowState=-4143;$excel.Left=0;$excel.Top=0;$excel.Width=1200;$excel.Height=700;Start-Sleep -Seconds 1
 foreach($z in 2,4){foreach($m in 0,2,3){Capture 'excel' $z $m}}
 $book.Close($false);$excel.Quit();[Runtime.InteropServices.Marshal]::ReleaseComObject($ws)|Out-Null;[Runtime.InteropServices.Marshal]::ReleaseComObject($book)|Out-Null;[Runtime.InteropServices.Marshal]::ReleaseComObject($excel)|Out-Null;$ws=$null;$book=$null;$excel=$null
} finally {Get-Process visual_app -ErrorAction SilentlyContinue|Stop-Process -Force;if($doc){$doc.Close(0)};if($word){$word.Quit()};if($book){$book.Close($false)};if($excel){$excel.Quit()}}
Get-ChildItem $out -Filter *.png|Select-Object Name,Length|Format-Table -AutoSize;Write-Output "OUTPUT=$out"
