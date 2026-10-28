// Standivarius Doxa Setup: shared personal and enterprise Windows host.
// .NET Framework Windows desktop EXE; the signed vendor driver and application
// are embedded; no network, LLM, automatic reboot or Windows display-mode writes.
using System;
using System.IO;
using System.Linq;
using System.Text;
using System.Drawing;
using System.Diagnostics;
using System.Management;
using System.Collections;
using System.Collections.Generic;
using System.IO.Compression;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Security.Principal;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using Microsoft.Win32;

internal class DoxaHost {
 const string Product="Standivarius Doxa Setup";
 const string Version="0.4.0-preview.12";
 const string DriverFilename="SMIUSBDisplaySW770.msi";
 const string DriverHash="3379B46DA029423748E2D2E64DB2015B50136E310A492E31857CC726719192D4";
 const string UsbPrefix=@"USB\VID_090C&PID_770A";
 const int RebootCode=3010;
 static readonly string ProgramFiles=Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
 static readonly string AppRoot=Path.Combine(ProgramFiles,"Standivarius","DoxaSetup");
 static readonly string MaintenanceRoot=Path.Combine(ProgramFiles,"Standivarius","DoxaMaintenance");
 static readonly string MaintenanceExe=Path.Combine(MaintenanceRoot,"DoxaMaintenance-v2.exe");
 static readonly string Logs=Path.Combine(MaintenanceRoot,"Logs");
 static readonly string Shortcut=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonStartMenu),"Programs","Standivarius Doxa Setup.lnk");
 static readonly string RegKey=@"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\StandivariusDoxaSetup";
 static readonly string Stage=Path.Combine(Path.GetTempPath(),"Doxa-"+Guid.NewGuid().ToString("N"));
 static readonly string ElevatedStage=Path.Combine(MaintenanceRoot,"Stage-"+Guid.NewGuid().ToString("N"));
 static bool Elevated {get{return new WindowsPrincipal(WindowsIdentity.GetCurrent()).IsInRole(WindowsBuiltInRole.Administrator);}}
 static string SourceExe {get{return Assembly.GetExecutingAssembly().Location;}}
 [DllImport("cfgmgr32.dll",EntryPoint="CM_Locate_DevNodeW",CharSet=CharSet.Unicode)]
 static extern int LocateDevice(out uint device,string id,uint flags);
 [DllImport("kernel32.dll",EntryPoint="MoveFileExW",CharSet=CharSet.Unicode,SetLastError=true)]
 static extern bool MoveFileEx(string existing,string replacement,uint flags);
 static void Require(bool okay,string reason){if(!okay)throw new InvalidOperationException(reason);}
 static void Trace(string message){
  try{Directory.CreateDirectory(Logs);File.AppendAllText(Path.Combine(Logs,"Doxa-Installer.log"),DateTime.UtcNow.ToString("o")+" "+message+Environment.NewLine);}
  catch{/* Auditing must not break a read-only check. */}
 }
 static string SHA(string f){using(var s=File.OpenRead(f))using(var h=SHA256.Create())return BitConverter.ToString(h.ComputeHash(s)).Replace("-","");}
 static bool ValidDriver(string f){return File.Exists(f)&&SHA(f).Equals(DriverHash,StringComparison.OrdinalIgnoreCase);}
 static bool PresentUsb(){
  try{
   using(var q=new ManagementObjectSearcher("SELECT PNPDeviceID FROM Win32_PnPEntity"))
   foreach(ManagementObject m in q.Get()){
    var id=Convert.ToString(m["PNPDeviceID"])??"";
    if(!id.StartsWith(UsbPrefix,StringComparison.OrdinalIgnoreCase))continue;
    uint node;
    if(LocateDevice(out node,id,0)==0)return true;
   }
  }catch{/* Deny install if live hardware cannot be established. */}
  return false;
 }
 // 0: no driver bound to matching hardware; 1: verified vendor + MS HW signer;
 // 2: matching identity bound to a different/untrusted package. Do not replace.
 static int ClassifyDriver(string provider,string signer,bool signed){
  // Microsoft USB composite/generic bindings and unconfigured PnP instances
  // are NOT foreign display drivers. They are legitimate first-install states.
  if(String.IsNullOrWhiteSpace(provider) ||
     provider.Equals("Microsoft",StringComparison.OrdinalIgnoreCase) ||
     provider.Equals("Microsoft Windows",StringComparison.OrdinalIgnoreCase))return 0;
  if(provider.Equals("SiliconMotion",StringComparison.OrdinalIgnoreCase)&&
     signed && signer.Equals("Microsoft Windows Hardware Compatibility Publisher",StringComparison.OrdinalIgnoreCase))return 1;
  return 2; // Unknown third-party display binding or untrusted vendor signature.
 }
 static int DriverState(){
  bool trusted=false;
  try{
   using(var q=new ManagementObjectSearcher("SELECT DeviceID,IsSigned,DriverProviderName,Signer FROM Win32_PnPSignedDriver"))
   foreach(ManagementObject m in q.Get()){
    if(!(Convert.ToString(m["DeviceID"])??"").StartsWith(UsbPrefix,StringComparison.OrdinalIgnoreCase))continue;
    var provider=Convert.ToString(m["DriverProviderName"])??"";
    var signer=Convert.ToString(m["Signer"])??"";
    var signed=m["IsSigned"]!=null && Convert.ToBoolean(m["IsSigned"]);
    int state=ClassifyDriver(provider,signer,signed);
    if(state==2)return 2;
    if(state==1)trusted=true;
   }
  }catch{return 2;} // A driver-query failure never authorizes replacing a driver.
  return trusted?1:0;
 }
 static string State(){
  bool valid=IsValidApp(AppRoot),usb=PresentUsb();
  int driver=DriverState();
  return (valid?"AppInstalled":"AppMissing")+" "+
   (driver==1?"DriverValid":driver==2?"DriverUntrusted":"DriverMissing")+" "+
   (usb?"USBDetected":"USBAbsent");
 }
 static bool IsRegistered(){
  try{
   if(!File.Exists(MaintenanceExe))return false;
   using(var key=Registry.LocalMachine.OpenSubKey(RegKey,false)){
    return key!=null && Convert.ToString(key.GetValue("DisplayName"))==Product
     && Convert.ToString(key.GetValue("DisplayVersion"))==Version
     && Convert.ToString(key.GetValue("UninstallString"))=="\""+MaintenanceExe+"\" /uninstall";
   }
  }catch{return false;}
 } static bool DetectDecision(bool appValid,bool registered){
  // Endpoint managers detect software installation only. Hardware connection
  // and driver health belong to /verify; USB hotplug must never flap /detect.
  return appValid && registered;
 }
 static bool DetectApp(){
  return DetectDecision(IsValidApp(AppRoot),IsRegistered());
 }
 static string AllowedPath(string root,string rel){
  Require(!Path.IsPathRooted(rel)&&rel.Length>1&&!rel.Contains(":")&&!rel.Contains("..")&&!rel.Contains("\\\\"),
   "Untrusted ZIP path");
  string full=Path.GetFullPath(Path.Combine(root,rel.Replace('/',Path.DirectorySeparatorChar)));
  Require(full.StartsWith(Path.GetFullPath(root).TrimEnd('\\')+"\\",StringComparison.OrdinalIgnoreCase),"Untrusted ZIP path");
  return full;
 }
 static Dictionary<string,object> Json(string f){
  return new JavaScriptSerializer(){MaxJsonLength=1000000}.Deserialize<Dictionary<string,object>>(File.ReadAllText(f,Encoding.UTF8));
 }
 static bool IsValidApp(string folder){
  try{
   string manifest=Path.Combine(folder,"manifest.json");
   if(!File.Exists(manifest))return false;
   var m=Json(manifest);
   if((string)m["product"]!=Product||(string)m["preview_version"]!=Version)return false;
   var allowed=new HashSet<string>(StringComparer.OrdinalIgnoreCase){"manifest.json"};
   int source=0;
   foreach(var field in new[]{"files","generated_files"}){
    foreach(object o in (IEnumerable)m[field]){
     var d=(Dictionary<string,object>)o;
     string rel=(string)d["file"],hash=(string)d["sha256"];
     if(!allowed.Add(rel)||hash.Length!=64)return false;
     string path=AllowedPath(folder,rel);
     if(!File.Exists(path)||!SHA(path).Equals(hash,StringComparison.OrdinalIgnoreCase))return false;
     if(field=="files")source++;
    }
   }
   if(source!=20||allowed.Count!=23)return false;
   var files=Directory.GetFiles(folder,"*",SearchOption.AllDirectories);
   return files.Length==allowed.Count&&files.All(f=>allowed.Contains(f.Substring(folder.TrimEnd('\\').Length+1).Replace('\\','/')));
  }catch{return false;}
 }
 static void ExtractApplication(string payload,string destination){
  Require(File.Exists(payload),"Missing embedded Doxa application");
  Directory.CreateDirectory(destination);
  using(var archive=ZipFile.OpenRead(payload)){
   foreach(var e in archive.Entries){
    if(String.IsNullOrEmpty(e.Name))continue;
    string path=AllowedPath(destination,e.FullName);
    Require(!File.Exists(path),"Duplicate application archive member");
    Directory.CreateDirectory(Path.GetDirectoryName(path));
    e.ExtractToFile(path);
   }
  }
  Require(IsValidApp(destination),"Application payload integrity failed");
 }
 static string ReadEmbedded(string name,string resource,string work){
  string path=Path.Combine(work,name);
  using(var stream=Assembly.GetExecutingAssembly().GetManifestResourceStream(resource)){
   Require(stream!=null,"Installer executable is incomplete: "+name);
   Directory.CreateDirectory(work);
   using(var f=File.Create(path))stream.CopyTo(f);
  }
  return path;
 }
 static string WorkingDirectory {get{return Elevated?ElevatedStage:Stage;}}
 static string VerifyAndUnpackDriver(){
  string path=ReadEmbedded(DriverFilename,"Doxa.Driver",WorkingDirectory);
  Require(ValidDriver(path),"Embedded driver does not match verified package");
  return path;
 }
 static string VerifyAndUnpackApplication(){
  string path=ReadEmbedded("DoxaSetupPayload.zip","Doxa.App",WorkingDirectory);
  return path;
 }
 static string InstallAppTo(string root,string payload){
  Directory.CreateDirectory(Path.GetDirectoryName(root));
  if(Directory.Exists(root)){
   Require(IsValidApp(root),"Existing application changed: refusing overwrite");
   return "AppAlreadyInstalled";
  }
  string staged=Path.Combine(Path.GetDirectoryName(root),"doxa-staging-"+Guid.NewGuid().ToString("N"));
  try{
   ExtractApplication(payload,staged);
   Directory.Move(staged,root);
   return "AppInstalled";
  }finally{if(Directory.Exists(staged))Directory.Delete(staged,true);}
 }
 static string RemoveAppFrom(string root){
  if(!Directory.Exists(root))return "AppAlreadyRemoved";
  var folder=new DirectoryInfo(root);
  Require((folder.Attributes & FileAttributes.ReparsePoint)==0,
    "Doxa application folder is redirected; refusing unsafe removal");
  if(IsValidApp(root)){
   Directory.Delete(root,true);
   return "AppRemoved";
  }
  // Do not delete unknown or modified files. Atomically move the whole
  // application directory aside on the same volume so uninstall and a clean
  // subsequent reinstall can finish without destroying third-party content.
  string parent=Path.GetDirectoryName(root);
  string retained=Path.Combine(parent,"DoxaRetained-"+Guid.NewGuid().ToString("N"));
  Directory.Move(root,retained);
  Trace("Modified application retained for administrator inspection at "+retained);
  return "AppRetainedForRecovery";
 }
 // Driver changes only after validated hardware, elevated Windows privilege
 // and pinned source. MSI 3010 is returned to IT; Doxa never restarts Windows.
 static string InstallDriver(string package){
  int state=DriverState();
  if(state==1)return "DriverAlreadyHealthy";
  Require(state!=2,"Different or untrusted display driver present");
  Require(PresentUsb(),"Doxa is not connected");
  Require(Environment.OSVersion.Version.Build>=19041&&Environment.Is64BitOperatingSystem,"Unsupported Windows version");
  string log=Path.Combine(Logs,"VendorDriver-"+DateTime.UtcNow.ToString("yyyyMMdd-HHmmss")+".log");
  Directory.CreateDirectory(Logs);
  var info=new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),"System32","msiexec.exe"),
   "/i \""+package+"\" /qn /norestart /L*v \""+log+"\""){UseShellExecute=false,CreateNoWindow=true};
  int exit;using(var p=Process.Start(info)){p.WaitForExit();exit=p.ExitCode;}
  Trace("Windows Installer returned "+exit);
  Require(exit==0||exit==RebootCode,"Driver installation failed; Windows Installer code "+exit+" (see log)");
  if(exit==RebootCode)return "RestartRequired";
  Require(DriverState()==1,"Driver MSI finished but signed Windows driver was not verified");
  return "DriverInstalledVerified";
 }
 static void InstallMaintenance(){
  Directory.CreateDirectory(MaintenanceRoot);
  if(!Path.GetFullPath(SourceExe).Equals(Path.GetFullPath(MaintenanceExe),StringComparison.OrdinalIgnoreCase))
   File.Copy(SourceExe,MaintenanceExe,true);
  // If app registration fails, installer reports failure, never a fake PASS.
  using(var key=Registry.LocalMachine.CreateSubKey(RegKey)){
   Require(key!=null,"Windows uninstall registration unavailable");
   key.SetValue("DisplayName",Product,RegistryValueKind.String);
   key.SetValue("DisplayVersion",Version,RegistryValueKind.String);
   key.SetValue("Publisher","Standivarius",RegistryValueKind.String);
   key.SetValue("InstallLocation",AppRoot,RegistryValueKind.String);
   key.SetValue("UninstallString","\""+MaintenanceExe+"\" /uninstall",RegistryValueKind.String);
   key.SetValue("QuietUninstallString","\""+MaintenanceExe+"\" /uninstall",RegistryValueKind.String);
   key.SetValue("DisplayIcon",MaintenanceExe,RegistryValueKind.String);
   key.SetValue("NoModify",1,RegistryValueKind.DWord);
   key.SetValue("NoRepair",1,RegistryValueKind.DWord);
  }
  try{
   Directory.CreateDirectory(Path.GetDirectoryName(Shortcut));
   dynamic shell=Activator.CreateInstance(Type.GetTypeFromProgID("WScript.Shell"));
   dynamic link=shell.CreateShortcut(Shortcut);
   link.TargetPath=MaintenanceExe;link.Arguments="/open";
   link.WorkingDirectory=AppRoot;link.Description=Product;link.Save();
  }catch(Exception e){Trace("Start menu shortcut unavailable: "+e.GetType().Name);}
 }
 static string Apply(){
  Require(Elevated,"Windows administrator permission required");
  string driverPackage=VerifyAndUnpackDriver();
  string appPayload=VerifyAndUnpackApplication();
  // Fail BEFORE creating an app entry if a connected device needs driver work
  // and the native Windows Installer fails. A disconnected endpoint may stage
  // only the application; the driver is deferred until Doxa is connected.
  bool plugged=PresentUsb();
  int current=DriverState();
  Require(current!=2,"Unexpected driver identity: installation refused");
  string driver=plugged?InstallDriver(driverPackage):"DriverDeferredUntilConnection";
  string app=InstallAppTo(AppRoot,appPayload);
  InstallMaintenance();
  string result=app+"; "+driver;
  Trace(result);return result;
 }
 static string Remove(){
  Require(Elevated,"Windows administrator permission required");
  string result=RemoveAppFrom(AppRoot);
  try{if(File.Exists(Shortcut))File.Delete(Shortcut);}catch(Exception e){Trace("Shortcut cleanup: "+e.GetType().Name);}
  Registry.LocalMachine.DeleteSubKey(RegKey,false);
  // Never queue delete-on-reboot: a reinstall could lose this executable.
  // Delete immediately from SYSTEM deployments; when invoked as Windows
  // Apps & Features, retain the running maintenance executable instead.
  if(File.Exists(MaintenanceExe) &&
     !Path.GetFullPath(SourceExe).Equals(Path.GetFullPath(MaintenanceExe),StringComparison.OrdinalIgnoreCase))
    File.Delete(MaintenanceExe);
  Trace(result+"; signed display driver preserved");
  return result+"; DisplayDriverRetained";
 }
 static void Open(){
  Require(IsValidApp(AppRoot),"Doxa application not installed or modified");
  string script=Path.Combine(AppRoot,"app","packaging","doxa-setup","personal-ui","Start-DoxaGuidedSetup.ps1");
  Require(File.Exists(script),"Guided setup is absent");
  string exe=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),"System32","WindowsPowerShell","v1.0","powershell.exe");
  Process.Start(new ProcessStartInfo(exe,"-NoProfile -ExecutionPolicy Bypass -File \""+script+"\""){
   UseShellExecute=false,CreateNoWindow=true,WorkingDirectory=AppRoot});
 }
 static string SelfTest(){
  string folder=Path.Combine(Path.GetTempPath(),"Doxa-Validation-"+Guid.NewGuid().ToString("N"));
  string testRoot=Path.Combine(folder,"installed");
  string testPayload=null;
  try{
   string vendor=VerifyAndUnpackDriver();
   Require(ValidDriver(vendor),"Driver fingerprint failure");
   testPayload=VerifyAndUnpackApplication();
   Require(InstallAppTo(testRoot,testPayload)=="AppInstalled","Fresh app installation failed");
   Require(IsValidApp(testRoot),"Installed app invalid");
   Require(InstallAppTo(testRoot,testPayload)=="AppAlreadyInstalled","Repeat install should be idempotent");
   Require(DetectDecision(true,true),"Registered valid app should detect regardless of USB/driver");
   Require(!DetectDecision(true,false),"Missing uninstall registration must fail detection");
   Require(!DetectDecision(false,true),"App missing must fail detection");
   Require(ClassifyDriver("Microsoft","Microsoft Windows",true)==0,"Generic first-use USB driver must be installable");
   Require(ClassifyDriver("", "",false)==0,"Unconfigured USB device must be installable");
   Require(ClassifyDriver("SiliconMotion","Microsoft Windows Hardware Compatibility Publisher",true)==1,
           "Healthy signed driver must be preserved");
   Require(ClassifyDriver("Unapproved vendor","Some signer",true)==2,"Foreign driver must block replacement");
   Require(ClassifyDriver("SiliconMotion","",false)==2,"Unsigned vendor driver must block replacement");   string writable=Directory.GetFiles(testRoot,"*.ps1",SearchOption.AllDirectories).FirstOrDefault();
   Require(writable!=null,"Fixture has no script for tamper test");
   File.AppendAllText(writable,"\n# altered");
   Require(!IsValidApp(testRoot),"Modified app not rejected");
   Require(RemoveAppFrom(testRoot)=="AppRetainedForRecovery","Modified installation must be safely retained");
   Require(!Directory.Exists(testRoot),"Modified installation must no longer block reinstall");
   var retained=Directory.GetDirectories(folder,"DoxaRetained-*");
   Require(retained.Length==1 && File.Exists(Path.Combine(retained[0],"manifest.json")),
           "Modified application was not preserved for recovery");
   Require(InstallAppTo(testRoot,testPayload)=="AppInstalled","Fresh reinstall after recovery must succeed");
   Require(IsValidApp(testRoot),"Freshly reinstalled application must verify");
   Require(RemoveAppFrom(testRoot)=="AppRemoved","Clean uninstall must remove owned files");   // Only a disposable folder; no driver install, registry, Start menu or display changes.
   return "PASS: signed driver classification, software detection, safe retained-file recovery, reinstall and clean uninstall fixtures";
  }finally{
   try{if(Directory.Exists(folder))Directory.Delete(folder,true);}catch{}
   try{if(Directory.Exists(WorkingDirectory))Directory.Delete(WorkingDirectory,true);}catch{}
  }
 }
 static int Run(string arg){
  if(arg=="/selftest"){Console.WriteLine(SelfTest());return 0;}
  if(arg=="/detect"){Console.WriteLine(State());return DetectApp()?0:1;}
  if(arg=="/verify"){Console.WriteLine(State());return IsValidApp(AppRoot)&&PresentUsb()&&DriverState()==1?0:1;}
  if(arg=="/install"){string result=Apply();Console.WriteLine(result);return result.Contains("RestartRequired")?RebootCode:0;}
  if(arg=="/uninstall"){
   if(!Elevated && Environment.UserInteractive){
    using(var elevated=Process.Start(new ProcessStartInfo(SourceExe,"/uninstall"){UseShellExecute=true,Verb="runas"})){
     elevated.WaitForExit();return elevated.ExitCode;
    }
   }
   Console.WriteLine(Remove());return 0;
  }
  if(arg=="/open"){Open();return 0;}
  throw new ArgumentException("Unknown command");
 }
 static void UI(){
  Application.EnableVisualStyles();
  var form=new Form{Text="Standivarius | Doxa Setup",ClientSize=new Size(650,365),MinimumSize=new Size(570,345),StartPosition=FormStartPosition.CenterScreen,
   BackColor=Color.White,Font=new Font("Segoe UI",11),AutoScaleMode=AutoScaleMode.Dpi};
  var title=new Label{Text="Doxa Setup",Font=new Font("Segoe UI",24,FontStyle.Bold),Location=new Point(30,22),Size=new Size(580,52)};
  var help=new Label{Text="Connect Doxa to power and the laptop's USB data port.\nInstall the Windows components, then arrange your screens.",Location=new Point(30,90),Size=new Size(580,60)};
  var status=new Label{Text=State(),Location=new Point(30,171),Size=new Size(580,45),ForeColor=Color.FromArgb(45,63,80)};
  var install=new Button{Text="Install / check Doxa",Location=new Point(30,245),Size=new Size(197,44)};
  var launch=new Button{Text="Open Doxa setup",Location=new Point(240,245),Size=new Size(175,44)};
  var refresh=new Button{Text="Refresh status",Location=new Point(430,245),Size=new Size(155,44)};
  install.Click+=(s,e)=>{
   try{
    bool successful=false;
    if(!Elevated){
     using(var p=Process.Start(new ProcessStartInfo(SourceExe,"/install"){UseShellExecute=true,Verb="runas"})){
      p.WaitForExit();
      successful=p.ExitCode==0||p.ExitCode==RebootCode;
      if(!successful)MessageBox.Show("Installation did not complete. See Doxa installation logs.","Doxa Setup");
     }
    }else{Apply();successful=true;}
    status.Text=State();
    if(successful&&IsValidApp(AppRoot))Open();
   }catch(Exception ex){MessageBox.Show(ex.Message,"Doxa Setup");}
  };
  launch.Click+=(s,e)=>{try{Open();}catch(Exception ex){MessageBox.Show(ex.Message,"Doxa Setup");}};
  refresh.Click+=(s,e)=>status.Text=State();
  form.Controls.AddRange(new Control[]{title,help,status,install,launch,refresh});
  Application.Run(form);
 }
 [STAThread] public static int Main(string[] args){
  string arg=args.Length>0?args[0].ToLowerInvariant():"";
  try{
   if(arg==""){UI();return 0;}
   return Run(arg);
  }catch(Exception ex){
   Trace("Error "+ex.GetType().Name+": "+ex.Message);
   Console.Error.WriteLine(ex.Message);

   return 30;
  }finally{
   try{if(Directory.Exists(WorkingDirectory))Directory.Delete(WorkingDirectory,true);}catch{}
  }
 }
}
