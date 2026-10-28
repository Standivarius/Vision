// Doxa Fault Lab, Windows CCD topology exercise. Developer-only, not part of retail payload.
// Read-only: list / preflight. "trial" temporarily drops ONE non-primary external path.
// Independent detached watchdog restores snapshot and then falls back to saved topology.
// No PnP enable/disable, driver removal, reboot, registry persistence or AI execution.
using System;
using System.IO;
using System.Linq;
using System.Text;
using System.Diagnostics;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Xml.Serialization;
using System.Windows.Forms;
using System.Threading;

[StructLayout(LayoutKind.Sequential)]
public struct DoxaLuid { public uint LowPart; public int HighPart; }
[StructLayout(LayoutKind.Sequential)]
public struct DoxaRational { public uint Numerator, Denominator; }
[StructLayout(LayoutKind.Sequential)]
public struct DoxaSource { public DoxaLuid adapterId; public uint id, modeInfoIdx, statusFlags; }
[StructLayout(LayoutKind.Sequential)]
public struct DoxaTarget {
 public DoxaLuid adapterId;
 public uint id, modeInfoIdx, outputTechnology, rotation, scaling;
 public DoxaRational refreshRate;
 public uint scanLineOrdering;
 [MarshalAs(UnmanagedType.Bool)] public bool targetAvailable;
 public uint statusFlags;
}
[StructLayout(LayoutKind.Sequential)]
public struct DoxaPath { public DoxaSource sourceInfo; public DoxaTarget targetInfo; public uint flags; }
[StructLayout(LayoutKind.Sequential)]
public struct DoxaMode {
 public uint infoType,id;
 public DoxaLuid adapterId;
 [MarshalAs(UnmanagedType.ByValArray, SizeConst=48)] public byte[] data;
}
[StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)]
public struct DoxaHeader { public uint type,size; public DoxaLuid adapterId; public uint id; }
[StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)]
public struct DoxaSourceName {
 public DoxaHeader header;
 [MarshalAs(UnmanagedType.ByValTStr,SizeConst=32)] public string viewGdiDeviceName;
}
[StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)]
public struct DoxaTargetName {
 public DoxaHeader header;
 public uint flags, outputTechnology;
 public ushort edidManufactureId, edidProductCodeId;
 public uint connectorInstance;
 [MarshalAs(UnmanagedType.ByValTStr,SizeConst=64)] public string monitorFriendlyDeviceName;
 [MarshalAs(UnmanagedType.ByValTStr,SizeConst=128)] public string monitorDevicePath;
}
[Serializable]
public class DoxaSavedTopology {
 public string originalPrimary;
 public string disabledDevice;
 public int session;
 public DateTime createdUtc;
 public DoxaPath[] paths;
 public DoxaMode[] modes;
}
public class DoxaDisplayPath {
 const uint QDC_ONLY_ACTIVE_PATHS=2;
 const uint SDC_USE_SUPPLIED_DISPLAY_CONFIG=0x20,SDC_VALIDATE=0x40,SDC_APPLY=0x80;
 const uint SDC_USE_DATABASE_CURRENT=0x0F;
 const int ERROR_INSUFFICIENT_BUFFER=122;
 [DllImport("user32.dll")] static extern int GetDisplayConfigBufferSizes(uint flags,out uint paths,out uint modes);
 [DllImport("user32.dll")] static extern int QueryDisplayConfig(uint flags,ref uint paths,[Out] DoxaPath[] pathsArray,ref uint modes,[Out] DoxaMode[] modesArray,IntPtr topologyId);
 [DllImport("user32.dll")] static extern int SetDisplayConfig(uint pathCount,[In] DoxaPath[] paths,uint modeCount,[In] DoxaMode[] modes,uint flags);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int DisplayConfigGetDeviceInfo(ref DoxaSourceName source);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int DisplayConfigGetDeviceInfo(ref DoxaTargetName target);
 static void Check(int error,string operation){if(error!=0)throw new InvalidOperationException(operation+" returned Windows "+error);}
 static DoxaSavedTopology Snapshot(){
  for(int attempt=0;attempt<5;attempt++){
   uint p,m;Check(GetDisplayConfigBufferSizes(QDC_ONLY_ACTIVE_PATHS,out p,out m),"DisplayConfigBufferSizes");
   if(p==0||p>32||m>96)throw new InvalidOperationException("Unexpected number of active display paths");
   DoxaPath[] paths=new DoxaPath[p];DoxaMode[] modes=new DoxaMode[m];
   uint pc=p,mc=m;
   int result=QueryDisplayConfig(QDC_ONLY_ACTIVE_PATHS,ref pc,paths,ref mc,modes,IntPtr.Zero);
   if(result==ERROR_INSUFFICIENT_BUFFER)continue;
   Check(result,"QueryDisplayConfig");
   Array.Resize(ref paths,(int)pc);Array.Resize(ref modes,(int)mc);
   return new DoxaSavedTopology{paths=paths,modes=modes,
    session=Process.GetCurrentProcess().SessionId,createdUtc=DateTime.UtcNow,
    originalPrimary=Screen.PrimaryScreen==null?"":Screen.PrimaryScreen.DeviceName};
  }
  throw new InvalidOperationException("Display topology changed during inventory");
 }
 static string SourceName(DoxaSource x){
  DoxaSourceName info=new DoxaSourceName();
  info.header=new DoxaHeader{type=1,size=(uint)Marshal.SizeOf(typeof(DoxaSourceName)),adapterId=x.adapterId,id=x.id};
  int status=DisplayConfigGetDeviceInfo(ref info);
  return status==0?(info.viewGdiDeviceName??""):"";
 }
 static string TargetName(DoxaTarget x){
  DoxaTargetName info=new DoxaTargetName();
  info.header=new DoxaHeader{type=2,size=(uint)Marshal.SizeOf(typeof(DoxaTargetName)),adapterId=x.adapterId,id=x.id};
  int status=DisplayConfigGetDeviceInfo(ref info);
  return status==0?(info.monitorFriendlyDeviceName??""):"";
 }
 static bool IsEmbedded(uint tech){
  // Internal laptop panels: INTERNAL, LVDS, embedded DisplayPort, embedded UDI.
  return tech==0x80000000u || tech==6 || tech==11 || tech==13;
 }
 static List<string> Describe(DoxaSavedTopology snap){
  var result=new List<string>();
  for(int i=0;i<snap.paths.Length;i++){
   var path=snap.paths[i];string device=SourceName(path.sourceInfo),friendly=TargetName(path.targetInfo);
   bool isPrimary=String.Equals(device,snap.originalPrimary,StringComparison.OrdinalIgnoreCase);
   bool internalPanel=IsEmbedded(path.targetInfo.outputTechnology);
   result.Add("index="+i+" device="+device+" name=\""+friendly+"\" primary="+isPrimary+" internal="+internalPanel+
    " output="+path.targetInfo.outputTechnology+" target="+path.targetInfo.id);
  }
  return result;
 }
 static int TargetIndex(DoxaSavedTopology snap,string device){
  if(snap.paths.Length<3)throw new InvalidOperationException("Need at least three active display paths to disable one");
  var names=snap.paths.Select(p=>SourceName(p.sourceInfo)).ToArray();
  var matches=Enumerable.Range(0,names.Length).Where(i=>String.Equals(names[i],device,StringComparison.OrdinalIgnoreCase)).ToArray();
  if(matches.Length!=1)throw new InvalidOperationException("Specify one unique active Windows device name from --list");
  int index=matches[0];var selected=snap.paths[index];
  if(String.IsNullOrWhiteSpace(snap.originalPrimary))throw new InvalidOperationException("Cannot identify primary monitor");
  if(String.Equals(device,snap.originalPrimary,StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("Primary display cannot be disabled");
  if(IsEmbedded(selected.targetInfo.outputTechnology))throw new InvalidOperationException("Internal laptop panel cannot be disabled");
  string panelIdentity=TargetName(selected.targetInfo);
  if(!new[]{"L","T","R"}.Contains(panelIdentity,StringComparer.OrdinalIgnoreCase))
   throw new InvalidOperationException("Only a recognized Doxa L/T/R panel can be selected; generic external monitors are not eligible");
  if(!selected.targetInfo.targetAvailable)throw new InvalidOperationException("Selected display target unavailable");
  // Fail closed for clone paths or virtual modes that cannot be uniquely attributed.
  if(names.Count(n=>String.Equals(n,device,StringComparison.OrdinalIgnoreCase))!=1)throw new InvalidOperationException("Cloned display not supported");
  if(snap.paths.Count(p=>String.Equals(SourceName(p.sourceInfo),snap.originalPrimary,StringComparison.OrdinalIgnoreCase))!=1)
   throw new InvalidOperationException("Primary source identity is not unique");
  if(snap.paths.Count(p=>IsEmbedded(p.targetInfo.outputTechnology))<1)
   throw new InvalidOperationException("No active independent internal laptop display detected");
  return index;
 }
 static DoxaPath[] Without(DoxaSavedTopology snap,int index){
  return snap.paths.Where((p,i)=>i!=index).ToArray();
 }
 static void WriteSnapshot(string file,DoxaSavedTopology snap){
  using(var stream=new FileStream(file,FileMode.CreateNew,FileAccess.Write,FileShare.None)){
   new XmlSerializer(typeof(DoxaSavedTopology)).Serialize(stream,snap);
   stream.Flush(true);
  }
 }
 static DoxaSavedTopology ReadSnapshot(string file){
  if(!File.Exists(file)||new FileInfo(file).Length>1000000)throw new InvalidOperationException("Invalid saved topology");
  using(var stream=File.OpenRead(file))return (DoxaSavedTopology)new XmlSerializer(typeof(DoxaSavedTopology)).Deserialize(stream);
 }

 static string RunsRoot {
  get {return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
   "Standivarius","DoxaFaultLab","runs");}
 }
 static string[] PendingSnapshots(){
  if(!Directory.Exists(RunsRoot))return new string[0];
  return Directory.GetFiles(RunsRoot,"topology.xml.armed",SearchOption.AllDirectories)
   .Where(a=>!File.Exists(a.Substring(0,a.Length-".armed".Length)+".done") ||
      !File.ReadAllText(a.Substring(0,a.Length-".armed".Length)+".done").StartsWith("RESTORED"))
   .ToArray();
 }
 static void RequireNoPendingTrial(){
  var pending=PendingSnapshots();
  if(pending.Length!=0)throw new InvalidOperationException(
   "Another display test is pending or its rollback failed; confirm all screens and recover the existing trial before starting a new one. First marker: "+pending[0]);
 }
 static string SerializeTopology(DoxaSavedTopology snapshot){
  using(var writer=new StringWriter()){
   new XmlSerializer(typeof(DoxaSavedTopology)).Serialize(writer,snapshot);
   return writer.ToString();
  }
 }
 static bool Restore(string file){
  var snapshot=ReadSnapshot(file);
  if(snapshot.session!=Process.GetCurrentProcess().SessionId)throw new InvalidOperationException("Wrong Windows user session for topology restore");
  int result=SetDisplayConfig((uint)snapshot.paths.Length,snapshot.paths,(uint)snapshot.modes.Length,snapshot.modes,
   SDC_APPLY|SDC_USE_SUPPLIED_DISPLAY_CONFIG);
  if(result!=0){
   // Last persistent CCD topology (temporary trial was not saved to database).
   result=SetDisplayConfig(0,null,0,null,SDC_APPLY|SDC_USE_DATABASE_CURRENT);
  }
  return result==0;
 }
 static void Watchdog(string file,int seconds){
  string ready=file+".ready",armed=file+".armed",done=file+".done";
  try{
   var saved=ReadSnapshot(file);
   if(saved.session!=Process.GetCurrentProcess().SessionId)throw new InvalidOperationException("Watchdog launched in wrong session");
   File.WriteAllText(ready,"ARMED");
   int ticks=0;
   // Independently revert after timeout even if the calling tool crashes.
   while(ticks++ < seconds*10){
    if(File.Exists(armed)){break;}
    Thread.Sleep(100);
   }
   if(!File.Exists(armed))return;
   Thread.Sleep(seconds*1000);
   // If an operator already restored it manually, NEVER reapply the older
   // snapshot while a later test may have started.
   if(File.Exists(done) && File.ReadAllText(done).StartsWith("RESTORED"))return;
   bool restored=Restore(file);
   File.WriteAllText(done,restored?"RESTORED":"FAILED: use Windows+P, Extend or Display settings");
  }catch(Exception ex){
   try{File.WriteAllText(done,"FAILED "+ex.GetType().Name+" "+ex.Message);}catch{}
  }
 }
 static void Trial(string device,int seconds,string ack){
  if(seconds<15||seconds>90)throw new InvalidOperationException("Recovery seconds must be between 15 and 90");
  if(Process.GetCurrentProcess().SessionId==0||SystemInformation.TerminalServerSession)
   throw new InvalidOperationException("Live display test requires local interactive Windows session");
  // Interprocess trial lock + persistent pending markers prevent overlapping
  // snapshots: second watchdog could otherwise restore a reduced topology.
  using(var trialGate=new Mutex(false,@"Local\StandivariusDoxaFaultLabTrialGate")){
   if(!trialGate.WaitOne(0))throw new InvalidOperationException("A Doxa display trial is already being prepared");
   try {
  RequireNoPendingTrial();
  var snapshot=Snapshot();
  int index=TargetIndex(snapshot,device);
  if(ack!="DISABLE "+device)throw new InvalidOperationException("Explicit target confirmation missing");
  var reduced=Without(snapshot,index);
  Check(SetDisplayConfig((uint)reduced.Length,reduced,(uint)snapshot.modes.Length,snapshot.modes,
    SDC_VALIDATE|SDC_USE_SUPPLIED_DISPLAY_CONFIG),"Dry-run topology validation");
  string folder=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
    "Standivarius","DoxaFaultLab","runs",Guid.NewGuid().ToString("N"));
  Directory.CreateDirectory(folder);
  string file=Path.Combine(folder,"topology.xml");
  snapshot.disabledDevice=device;
  WriteSnapshot(file,snapshot);
  string self=System.Reflection.Assembly.GetExecutingAssembly().Location;
  var process=new ProcessStartInfo(self,"--watchdog \""+file+"\" "+seconds);
  process.UseShellExecute=false;process.CreateNoWindow=true;process.WindowStyle=ProcessWindowStyle.Hidden;
  var watchdog=Process.Start(process);
  if(watchdog==null)throw new InvalidOperationException("Independent rollback watchdog failed to launch");
  bool ready=false;
  for(int i=0;i<80;i++){
   if(File.Exists(file+".ready")){ready=true;break;}
   if(watchdog.HasExited)break;
   Thread.Sleep(100);
  }
  if(!ready)throw new InvalidOperationException("Watchdog did not confirm readiness. No display changes attempted.");
  File.WriteAllText(file+".armed","APPLYING");
  int change=SetDisplayConfig((uint)reduced.Length,reduced,(uint)snapshot.modes.Length,snapshot.modes,
    SDC_APPLY|SDC_USE_SUPPLIED_DISPLAY_CONFIG);
  if(change!=0){
   // Watchdog still restores after deadline if any side effect occurred.
   throw new InvalidOperationException("Windows refused temporary display change ("+change+"). Watchdog remains armed.");
  }
  Console.WriteLine("TEMPORARILY_DISABLED="+device);
  Console.WriteLine("AUTO_RESTORE_SECONDS="+seconds);
  Console.WriteLine("RESTORE_BACKUP="+file);
  Console.WriteLine("MANUAL_RESTORE_COMMAND=\""+self+"\" --restore \""+file+"\"");
  Console.WriteLine("Recovery watchdog independently restores the original CCD topology after the timeout.");
   }finally{trialGate.ReleaseMutex();}
  }
 }
 static int Main(string[] args){
  try{
   if(args.Length==0||args[0]=="--list"){
    var snap=Snapshot();Console.WriteLine("PRIMARY="+snap.originalPrimary);
    Console.WriteLine("ACTIVE_PATH_COUNT="+snap.paths.Length);
    foreach(string line in Describe(snap))Console.WriteLine(line);
    return 0;
   }
   if(args[0]=="--snapshot-test"&&args.Length==1){
    var snapshot=Snapshot();
    string dir=Path.Combine(Path.GetTempPath(),"DoxaCCD-SnapshotTest-"+Guid.NewGuid().ToString("N"));
    Directory.CreateDirectory(dir);string file=Path.Combine(dir,"snapshot.xml");
    try{
     WriteSnapshot(file,snapshot);
     var restored=ReadSnapshot(file);
     if(SerializeTopology(restored)!=SerializeTopology(snapshot))
      throw new InvalidOperationException("Topology path/mode content changed during backup roundtrip");
     Console.WriteLine("PASS: complete active Windows topology backup serialized and restored in memory; NO DISPLAY CHANGE");
     return 0;
    }finally{Directory.Delete(dir,true);}
   }
   if(args[0]=="--preflight"&&args.Length==2){
    var snap=Snapshot();int index=TargetIndex(snap,args[1]);
    var remaining=Without(snap,index);
    int status=SetDisplayConfig((uint)remaining.Length,remaining,(uint)snap.modes.Length,snap.modes,SDC_VALIDATE|SDC_USE_SUPPLIED_DISPLAY_CONFIG);
    Console.WriteLine("SELECTED="+args[1]+"; primary protected="+snap.originalPrimary+"; Windows CCD validation="+status);
    if(status!=0)return 2;
    Console.WriteLine("PREFLIGHT_PASS_NO_CHANGE");
    return 0;
   }
   if(args[0]=="--trial"&&args.Length==4){
    int seconds;
    if(!int.TryParse(args[2],out seconds))throw new InvalidOperationException("Invalid seconds");
    Trial(args[1],seconds,args[3]);return 0;
   }
   if(args[0]=="--watchdog"&&args.Length==3){
    int sec;
    if(!int.TryParse(args[2],out sec)||sec<15||sec>90)throw new InvalidOperationException("Invalid watchdog seconds");
    Watchdog(args[1],sec);return 0;
   }
   if(args[0]=="--restore"&&args.Length==2){
    bool ok=Restore(args[1]);
    if(ok)File.WriteAllText(args[1]+".done","RESTORED MANUALLY");
    Console.WriteLine("RESTORE="+(ok?"PASS":"FAILED"));return ok?0:3;
   }
   if(args[0]=="--pending"&&args.Length==1){
    string[] pending=PendingSnapshots();
    Console.WriteLine("PENDING_TRIALS="+pending.Length);
    foreach(string path in pending)Console.WriteLine(path);
    return pending.Length==0?0:4;
   }
   if(args[0]=="--guard-test"&&args.Length==1){
    RequireNoPendingTrial();
    string testDir=Path.Combine(RunsRoot,"selftest-"+Guid.NewGuid().ToString("N"));
    Directory.CreateDirectory(testDir);
    string marker=Path.Combine(testDir,"topology.xml.armed");
    try{
     File.WriteAllText(marker,"TEST NO DISPLAY CHANGE");
     bool rejected=false;
     try{RequireNoPendingTrial();}catch(InvalidOperationException){rejected=true;}
     if(!rejected)throw new InvalidOperationException("Concurrent trial marker was not rejected");
     Console.WriteLine("PASS: overlapping-trial guard rejected pending recovery; NO DISPLAY CHANGE");
     return 0;
    }finally{Directory.Delete(testDir,true);}
   }
   throw new InvalidOperationException("Use --list, --preflight DEVICE, --trial DEVICE SECONDS ACK, --restore BACKUP");
  }catch(Exception ex){Console.Error.WriteLine("FAULT_LAB_ERROR="+ex.Message);return 1;}
 }
}