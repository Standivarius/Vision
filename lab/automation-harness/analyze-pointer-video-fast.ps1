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
using System.Linq;
using System.Text;

public static class VisualPixelScanner {
    sealed class TRow {
        public long frame,qpc; public int poi,visible; public double pointerAge;
        public double vl,vt,vr,vb,sl,st,sr,sb;
    }
    sealed class Sample {
        public int frame; public double videoTime; public long qpc, teleFrame; public double score, pointerAge; public int x,y,dx,dy; public bool present;
    }
    static readonly CultureInfo Inv=CultureInfo.InvariantCulture;
    const int W=1920,H=1080;

    static List<TRow> LoadTelemetry(string path){
        var list=new List<TRow>();
        foreach(var line in File.ReadLines(path)){
            if(String.IsNullOrWhiteSpace(line)||line[0]=='#'||line.StartsWith("frame,")) continue;
            var a=line.Split(','); if(a.Length<22) continue;
            list.Add(new TRow{frame=long.Parse(a[0]),qpc=long.Parse(a[1]),poi=int.Parse(a[5]),visible=int.Parse(a[6]),
                pointerAge=double.Parse(a[13],Inv),vl=double.Parse(a[8],Inv),vt=double.Parse(a[9],Inv),vr=double.Parse(a[10],Inv),vb=double.Parse(a[11],Inv),
                sl=double.Parse(a[18],Inv),st=double.Parse(a[19],Inv),sr=double.Parse(a[20],Inv),sb=double.Parse(a[21],Inv)});
        }
        return list;
    }
    static int Near(List<TRow> t,long q){
        int lo=0,hi=t.Count-1; while(lo<hi){int m=(lo+hi)/2;if(t[m].qpc<q)lo=m+1;else hi=m;}
        if(lo>0 && Math.Abs((double)(t[lo-1].qpc-q))<Math.Abs((double)(t[lo].qpc-q))) return lo-1; return lo;
    }
    static bool Center(TRow r,out int x,out int y){
        x=y=0;if(r.poi!=5||r.visible!=1||r.vr<=r.vl||r.vb<=r.vt)return false;
        double sx=.5*(r.sl+r.sr),sy=.5*(r.st+r.sb);
        x=(int)Math.Round((sx-r.vl)/(r.vr-r.vl)*W); y=(int)Math.Round((sy-r.vt)/(r.vb-r.vt)*H);
        return x>=30&&x<W-30&&y>=30&&y<H-30;
    }
    static double Score(byte[] f,int cx,int cy){
        if(cx<22||cx>=W-22||cy<22||cy>=H-22)return -999;
        double white=0,black=0;int nw=0,nb=0;
        for(int d=6;d<=19;d++){
            for(int s=-1;s<=1;s++){
                white+=f[cy*W+cx+d];nw++; white+=f[cy*W+cx-d];nw++;
                white+=f[(cy+d)*W+cx+s];nw++; white+=f[(cy-d)*W+cx+s];nw++;
            }
            foreach(int s in new[]{-3,3}){
                black+=f[(cy+s)*W+cx+d];nb++; black+=f[(cy+s)*W+cx-d];nb++;
                black+=f[(cy+d)*W+cx+s];nb++; black+=f[(cy-d)*W+cx+s];nb++;
            }
        }
        return white/nw-black/nb;
    }
    static double BestScore(byte[] f,int x,int y,out int bestDx,out int bestDy){
        double best=-999;bestDx=bestDy=0;
        for(int dx=-24;dx<=24;dx+=4) for(int dy=-8;dy<=8;dy+=4){double s=Score(f,x+dx,y+dy);if(s>best){best=s;bestDx=dx;bestDy=dy;}}
        return best;
    }
    static bool ReadExact(Stream s,byte[] b){int off=0;while(off<b.Length){int n=s.Read(b,off,b.Length-off);if(n<=0)return false;off+=n;}return true;}
    static Process StartFfmpeg(string ff,string video,int fps,double start,double dur){
        string filter="crop=1920:1080:1920:0,fps="+fps+",format=gray";
        var psi=new ProcessStartInfo(ff,"-hide_banner -loglevel error -ss "+start.ToString(Inv)+" -t "+dur.ToString(Inv)+" -i \""+video+"\" -vf \""+filter+"\" -f rawvideo -pix_fmt gray pipe:1");
        psi.UseShellExecute=false;psi.RedirectStandardOutput=true;psi.RedirectStandardError=true;psi.CreateNoWindow=true;
        return Process.Start(psi);
    }
    static long[] LoadEventQpc(string path,out long baseQpc){
        baseQpc=0;long fastStart=0,fastEnd=0;
        foreach(var line in File.ReadLines(path)){
            if(line.StartsWith("qpc,"))continue;var a=line.Split(',');if(a.Length<3)continue;
            long q; if(!long.TryParse(a[0],out q))continue;
            if(a[1]=="ffmpeg_started"){int k=a[2].IndexOf("qpc=");if(k>=0)long.TryParse(a[2].Substring(k+4),out baseQpc);}
            if(a[1]=="phase_start"&&a[2]=="fast_horizontal_bursts")fastStart=q;
            if(a[1]=="phase_end"&&a[2]=="fast_horizontal_bursts")fastEnd=q;
        }
        return new[]{fastStart,fastEnd};
    }
    static double Percentile(List<double> x,double p){x.Sort();if(x.Count==0)return 0;int i=(int)Math.Floor((x.Count-1)*p);return x[i];}

    public static void Run(string ff,string run){
        string video=Path.Combine(run,"desktop.mp4"),tele=Path.Combine(run,"visual_telemetry.csv"),events=Path.Combine(run,"test_events.csv");
        var rows=LoadTelemetry(tele);long baseQpc;var phase=LoadEventQpc(events,out baseQpc);const double freq=10000000.0;int fps=8;double start=4,dur=15;
        var offsets=new List<double>();for(double o=.40;o<=1.8001;o+=.025)offsets.Add(Math.Round(o,3));
        var sum=new double[offsets.Count];var count=new int[offsets.Count];byte[] frame=new byte[W*H];
        using(var p=StartFfmpeg(ff,video,fps,start,dur)){
            var s=p.StandardOutput.BaseStream;int fi=0;
            while(ReadExact(s,frame)){
                double vt=start+fi/(double)fps;
                for(int oi=0;oi<offsets.Count;oi++){
                    long q=(long)Math.Round(baseQpc+(vt+offsets[oi])*freq);var r=rows[Near(rows,q)];
                    if(r.qpc<phase[0]||r.qpc>phase[1])continue;int x,y;if(!Center(r,out x,out y))continue;int dx,dy;double sc=BestScore(frame,x,y,out dx,out dy);sum[oi]+=sc;count[oi]++;
                }fi++;
            }
            p.WaitForExit();string err=p.StandardError.ReadToEnd();if(p.ExitCode!=0)throw new Exception("ffmpeg pass1: "+err);
        }
        int best=0;for(int i=1;i<offsets.Count;i++){double ai=count[i]>0?sum[i]/count[i]:-999,ab=count[best]>0?sum[best]/count[best]:-999;if(ai>ab)best=i;}
        double bestOffset=offsets[best],bestAvg=count[best]>0?sum[best]/count[best]:-999;
        var samples=new List<Sample>();
        using(var p=StartFfmpeg(ff,video,fps,start,dur)){
            var s=p.StandardOutput.BaseStream;int fi=0;
            while(ReadExact(s,frame)){
                double vt=start+fi/(double)fps;long q=(long)Math.Round(baseQpc+(vt+bestOffset)*freq);var r=rows[Near(rows,q)];int x,y;
                if(Center(r,out x,out y)){int dx,dy;double sc=BestScore(frame,x,y,out dx,out dy);samples.Add(new Sample{frame=fi,videoTime=vt,qpc=q,teleFrame=r.frame,pointerAge=r.pointerAge,x=x,y=y,score=sc,dx=dx,dy=dy});}
                fi++;
            }
            p.WaitForExit();string err=p.StandardError.ReadToEnd();if(p.ExitCode!=0)throw new Exception("ffmpeg pass2: "+err);
        }
        var scs=samples.Select(z=>z.score).ToList();double med=Percentile(new List<double>(scs),.5),p20=Percentile(new List<double>(scs),.2);double threshold=Math.Max(45,Math.Min(100,med*.5));
        foreach(var z in samples)z.present=z.score>=threshold;
        int missing=samples.Count(z=>!z.present),longest=0,cur=0,end=-1;for(int i=0;i<samples.Count;i++){if(!samples[i].present){cur++;if(cur>longest){longest=cur;end=i;}}else cur=0;}
        double longestMs=1000.0*longest/fps;double ls=longest>0?samples[end-longest+1].videoTime:0,le=longest>0?samples[end].videoTime:0;
        using(var w=new StreamWriter(Path.Combine(run,"pixel_fast_scores.csv"),false,Encoding.UTF8)){
            w.WriteLine("frame,video_time_sec,qpc,telemetry_frame,pointer_age_ms,expected_x,expected_y,score,dx,dy,present");
            foreach(var z in samples)w.WriteLine(String.Join(",",z.frame,z.videoTime.ToString("F3",Inv),z.qpc,z.teleFrame,z.pointerAge.ToString("F3",Inv),z.x,z.y,z.score.ToString("F2",Inv),z.dx,z.dy,z.present?1:0));
        }
        var ranked=Enumerable.Range(0,offsets.Count).Select(i=>new{O=offsets[i],N=count[i],A=count[i]>0?sum[i]/count[i]:-999}).OrderByDescending(x=>x.A).Take(8).ToList();
        var low=samples.OrderBy(x=>x.score).Take(12).ToList();
        var sb=new StringBuilder();
        sb.AppendLine("analysis_fps="+fps);sb.AppendLine("best_offset_sec="+bestOffset.ToString("F3",Inv));sb.AppendLine("calibration_avg_score="+bestAvg.ToString("F2",Inv));
        sb.AppendLine("pointer_samples="+samples.Count);sb.AppendLine("median_score="+med.ToString("F2",Inv));sb.AppendLine("p20_score="+p20.ToString("F2",Inv));sb.AppendLine("threshold="+threshold.ToString("F2",Inv));
        sb.AppendLine("missing_samples="+missing);sb.AppendLine("missing_fraction="+(samples.Count>0?(missing/(double)samples.Count).ToString("F4",Inv):"0"));sb.AppendLine("longest_missing_ms="+longestMs.ToString("F1",Inv));sb.AppendLine("longest_missing_start_sec="+ls.ToString("F3",Inv));sb.AppendLine("longest_missing_stop_sec="+le.ToString("F3",Inv));
        sb.AppendLine("TOP_OFFSETS");foreach(var x in ranked)sb.AppendLine(x.O.ToString("F3",Inv)+","+x.N+","+x.A.ToString("F2",Inv));
        sb.AppendLine("LOWEST_SCORES");foreach(var z in low)sb.AppendLine(z.videoTime.ToString("F3",Inv)+","+z.teleFrame+","+z.score.ToString("F2",Inv)+","+z.dx+","+z.dy+","+z.pointerAge.ToString("F1",Inv));
        File.WriteAllText(Path.Combine(run,"pixel_fast_result.txt"),sb.ToString());
    }
}
'@
Add-Type -TypeDefinition $code -Language CSharp
[VisualPixelScanner]::Run($ff,$RunFolder)
Get-Content (Join-Path $RunFolder 'pixel_fast_result.txt')
