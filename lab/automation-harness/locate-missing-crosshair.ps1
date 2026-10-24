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
public static class CrosshairLocatorScan {
 sealed class R{public long frame,qpc;public int poi,vis;public double vl,vt,vr,vb,sl,st,sr,sb,age;}
 static readonly CultureInfo I=CultureInfo.InvariantCulture; const int W=1920,H=1080; const double F=10000000.0;
 static List<R> Load(string p){var z=new List<R>();foreach(var l in File.ReadLines(p)){if(String.IsNullOrWhiteSpace(l)||l[0]=='#'||l.StartsWith("frame,"))continue;var a=l.Split(',');if(a.Length<22)continue;z.Add(new R{frame=long.Parse(a[0]),qpc=long.Parse(a[1]),poi=int.Parse(a[5]),vis=int.Parse(a[6]),vl=double.Parse(a[8],I),vt=double.Parse(a[9],I),vr=double.Parse(a[10],I),vb=double.Parse(a[11],I),age=double.Parse(a[13],I),sl=double.Parse(a[18],I),st=double.Parse(a[19],I),sr=double.Parse(a[20],I),sb=double.Parse(a[21],I)});}return z;}
 static int Near(List<R> t,long q){int lo=0,hi=t.Count-1;while(lo<hi){int m=(lo+hi)/2;if(t[m].qpc<q)lo=m+1;else hi=m;}if(lo>0&&Math.Abs((double)(t[lo-1].qpc-q))<Math.Abs((double)(t[lo].qpc-q)))return lo-1;return lo;}
 static bool Center(R r,out int x,out int y){x=y=0;if(r.poi!=5||r.vis!=1||r.vr<=r.vl||r.vb<=r.vt)return false;double sx=.5*(r.sl+r.sr),sy=.5*(r.st+r.sb);x=(int)Math.Round((sx-r.vl)/(r.vr-r.vl)*W);y=(int)Math.Round((sy-r.vt)/(r.vb-r.vt)*H);return x>=30&&x<W-30&&y>=30&&y<H-30;}
 static double S(byte[] f,int cx,int cy){if(cx<22||cx>=W-22||cy<22||cy>=H-22)return-999;double w=0,b=0;int nw=0,nb=0;for(int d=6;d<=19;d++){for(int s=-1;s<=1;s++){w+=f[cy*W+cx+d];nw++;w+=f[cy*W+cx-d];nw++;w+=f[(cy+d)*W+cx+s];nw++;w+=f[(cy-d)*W+cx+s];nw++;}foreach(int s in new[]{-3,3}){b+=f[(cy+s)*W+cx+d];nb++;b+=f[(cy+s)*W+cx-d];nb++;b+=f[(cy+d)*W+cx+s];nb++;b+=f[(cy-d)*W+cx+s];nb++;}}return w/nw-b/nb;}
 static double Local(byte[] f,int x,int y){double best=-999;for(int dx=-24;dx<=24;dx+=4)for(int dy=-8;dy<=8;dy+=4)best=Math.Max(best,S(f,x+dx,y+dy));return best;}
 static bool ReadExact(Stream s,byte[] b){int o=0;while(o<b.Length){int n=s.Read(b,o,b.Length-o);if(n<=0)return false;o+=n;}return true;}
 static Process FF(string ff,string v){var psi=new ProcessStartInfo(ff,"-hide_banner -loglevel error -ss 4 -t 15 -i \""+v+"\" -vf \"crop=1920:1080:1920:0,fps=8,format=gray\" -f rawvideo -pix_fmt gray pipe:1");psi.UseShellExecute=false;psi.RedirectStandardOutput=true;psi.RedirectStandardError=true;psi.CreateNoWindow=true;return Process.Start(psi);}
 static long[] Ev(string p,out long b){b=0;long s=0,e=0;foreach(var l in File.ReadLines(p)){if(l.StartsWith("qpc,"))continue;var a=l.Split(',');if(a.Length<3)continue;long q;if(!long.TryParse(a[0],out q))continue;if(a[1]=="ffmpeg_started"){int k=a[2].IndexOf("qpc=");if(k>=0)long.TryParse(a[2].Substring(k+4),out b);}if(a[1]=="phase_start"&&a[2]=="fast_horizontal_bursts")s=q;if(a[1]=="phase_end"&&a[2]=="fast_horizontal_bursts")e=q;}return new[]{s,e};}
 public static void Run(string ff,string run){var t=Load(Path.Combine(run,"visual_telemetry.csv"));long b;var ph=Ev(Path.Combine(run,"test_events.csv"),out b);string v=Path.Combine(run,"desktop.mp4");double off=1.425,threshold=90.82;var outRows=new List<string>();outRows.Add("video_time_sec,telemetry_frame,expected_x,expected_y,local_score,global_score,global_x,global_y,delta_x,delta_y,pointer_age_ms,true_absent");int suspects=0,relocated=0,absent=0,longest=0,cur=0;double firstAbs=0,lastAbs=0;byte[] f=new byte[W*H];using(var p=FF(ff,v)){var st=p.StandardOutput.BaseStream;int fi=0;while(ReadExact(st,f)){double vt=4+fi/8.0;long q=(long)Math.Round(b+(vt+off)*F);var r=t[Near(t,q)];if(r.qpc>=ph[0]&&r.qpc<=ph[1]){int x,y;if(Center(r,out x,out y)){double local=Local(f,x,y);if(local<threshold){suspects++;double gs=-999;int gx=0,gy=0;for(int yy=Math.Max(30,y-24);yy<=Math.Min(H-30,y+24);yy+=3){for(int xx=30;xx<W-30;xx+=3){double sc=S(f,xx,yy);if(sc>gs){gs=sc;gx=xx;gy=yy;}}}bool ta=gs<threshold;if(ta){absent++;cur++;if(cur>longest)longest=cur;if(firstAbs==0)firstAbs=vt;lastAbs=vt;}else{relocated++;cur=0;}outRows.Add(vt.ToString("F3",I)+","+r.frame+","+x+","+y+","+local.ToString("F2",I)+","+gs.ToString("F2",I)+","+gx+","+gy+","+(gx-x)+","+(gy-y)+","+r.age.ToString("F1",I)+","+(ta?1:0));}else cur=0;}}fi++;}p.WaitForExit();var er=p.StandardError.ReadToEnd();if(p.ExitCode!=0)throw new Exception(er);}
 File.WriteAllLines(Path.Combine(run,"crosshair_global_scan.csv"),outRows,Encoding.UTF8);var sb=new StringBuilder();sb.AppendLine("fast_horizontal_suspect_frames="+suspects);sb.AppendLine("crosshair_found_elsewhere="+relocated);sb.AppendLine("crosshair_absent_entire_search_band="+absent);sb.AppendLine("longest_true_absent_samples="+longest);sb.AppendLine("longest_true_absent_ms="+(longest*125));sb.AppendLine("first_absent_video_sec="+firstAbs.ToString("F3",I));sb.AppendLine("last_absent_video_sec="+lastAbs.ToString("F3",I));File.WriteAllText(Path.Combine(run,"crosshair_global_result.txt"),sb.ToString());}
}
'@
Add-Type -TypeDefinition $code -Language CSharp
[CrosshairLocatorScan]::Run($ff,$RunFolder)
Get-Content (Join-Path $RunFolder 'crosshair_global_result.txt')
Get-Content (Join-Path $RunFolder 'crosshair_global_scan.csv')
