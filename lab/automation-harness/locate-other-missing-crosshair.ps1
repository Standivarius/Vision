param([string]$RunFolder='C:\dev\Visual\lab\benchmarks\visual_regression\runs\2026-09-24_08-03-26__pointer_visibility')
$ErrorActionPreference='Stop'
$ff=(Get-Command ffmpeg.exe -ErrorAction SilentlyContinue).Source
if(-not $ff){$ff=Get-ChildItem 'C:\dev\Visual' -Filter ffmpeg.exe -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1 -ExpandProperty FullName}
if(-not $ff){throw 'ffmpeg.exe not found'}
$code=@'
using System;
using System.IO;
using System.Diagnostics;
using System.Collections.Generic;
using System.Globalization;
using System.Text;
using System.Linq;
public static class OtherCrosshairScan {
 static readonly CultureInfo I=CultureInfo.InvariantCulture; const int W=1920,H=1080;
 sealed class Target{public double t;public long tf;public int ex,ey;public double local,age;}
 static double Score(byte[] f,int cx,int cy){if(cx<22||cx>=W-22||cy<22||cy>=H-22)return-999;double w=0,b=0;int nw=0,nb=0;for(int d=6;d<=19;d++){for(int s=-1;s<=1;s++){w+=f[cy*W+cx+d];nw++;w+=f[cy*W+cx-d];nw++;w+=f[(cy+d)*W+cx+s];nw++;w+=f[(cy-d)*W+cx+s];nw++;}foreach(int s in new[]{-3,3}){b+=f[(cy+s)*W+cx+d];nb++;b+=f[(cy+s)*W+cx-d];nb++;b+=f[(cy+d)*W+cx+s];nb++;b+=f[(cy-d)*W+cx+s];nb++;}}return w/nw-b/nb;}
 static bool ReadExact(Stream s,byte[] b){int o=0;while(o<b.Length){int n=s.Read(b,o,b.Length-o);if(n<=0)return false;o+=n;}return true;}
 static Process FF(string ff,string v){var psi=new ProcessStartInfo(ff,"-hide_banner -loglevel error -ss 15.5 -t 4 -i \""+v+"\" -vf \"crop=1920:1080:1920:0,fps=8,format=gray\" -f rawvideo -pix_fmt gray pipe:1");psi.UseShellExecute=false;psi.RedirectStandardOutput=true;psi.RedirectStandardError=true;psi.CreateNoWindow=true;return Process.Start(psi);}
 public static void Run(string ff,string run){
  var targets=new Dictionary<int,Target>();foreach(var l in File.ReadLines(Path.Combine(run,"pixel_fast_scores.csv"))){if(l.StartsWith("frame,"))continue;var a=l.TrimStart('\uFEFF').Split(',');if(a.Length<11)continue;double t=double.Parse(a[1],I),sc=double.Parse(a[7],I);if(t<15.5||t>19.1||sc>=90.82)continue;int idx=(int)Math.Round((t-15.5)*8);targets[idx]=new Target{t=t,tf=long.Parse(a[3]),ex=int.Parse(a[5]),ey=int.Parse(a[6]),local=sc,age=double.Parse(a[4],I)};}
  var lines=new List<string>();lines.Add("video_time_sec,telemetry_frame,expected_x,expected_y,local_score,global_score,global_x,global_y,delta_x,delta_y,pointer_age_ms,true_absent");int found=0,absent=0,longest=0,cur=0;byte[] f=new byte[W*H];
  using(var p=FF(ff,Path.Combine(run,"desktop.mp4"))){var st=p.StandardOutput.BaseStream;int fi=0;while(ReadExact(st,f)){Target q;if(targets.TryGetValue(fi,out q)){double best=-999;int bx=0,by=0;for(int y=30;y<H-30;y+=6)for(int x=30;x<W-30;x+=6){double s=Score(f,x,y);if(s>best){best=s;bx=x;by=y;}}int cbx=bx,cby=by;for(int y=Math.Max(30,cby-8);y<=Math.Min(H-30,cby+8);y++)for(int x=Math.Max(30,cbx-8);x<=Math.Min(W-30,cbx+8);x++){double s=Score(f,x,y);if(s>best){best=s;bx=x;by=y;}}bool ta=best<90.82;if(ta){absent++;cur++;if(cur>longest)longest=cur;}else{found++;cur=0;}lines.Add(q.t.ToString("F3",I)+","+q.tf+","+q.ex+","+q.ey+","+q.local.ToString("F2",I)+","+best.ToString("F2",I)+","+bx+","+by+","+(bx-q.ex)+","+(by-q.ey)+","+q.age.ToString("F1",I)+","+(ta?1:0));}fi++;}p.WaitForExit();var er=p.StandardError.ReadToEnd();if(p.ExitCode!=0)throw new Exception(er);}
  File.WriteAllLines(Path.Combine(run,"crosshair_fullscreen_scan.csv"),lines,Encoding.UTF8);var sb=new StringBuilder();sb.AppendLine("suspect_frames="+targets.Count);sb.AppendLine("crosshair_found_somewhere="+found);sb.AppendLine("crosshair_absent_fullscreen="+absent);sb.AppendLine("longest_absent_samples="+longest);sb.AppendLine("longest_absent_ms="+(longest*125));File.WriteAllText(Path.Combine(run,"crosshair_fullscreen_result.txt"),sb.ToString());
 }
}
'@
Add-Type -TypeDefinition $code -Language CSharp
[OtherCrosshairScan]::Run($ff,$RunFolder)
Get-Content (Join-Path $RunFolder 'crosshair_fullscreen_result.txt')
Get-Content (Join-Path $RunFolder 'crosshair_fullscreen_scan.csv')
