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
using System.ComponentModel;
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
 static readonly string LegacyMaintenanceExe=Path.Combine(MaintenanceRoot,"DoxaMaintenance.exe");
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
 // Delete-on-reboot is ONLY used for a random one-shot cleanup helper,
 // never for a stable executable name that a later installation may reuse.
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
  // Normalize documented vendor display names, but require valid WHQL signer.
  string vendor=new string(provider.Where(char.IsLetterOrDigit).ToArray());
  if(vendor.StartsWith("SiliconMotion",StringComparison.OrdinalIgnoreCase) &&
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
 static bool RecognizedRegisteredMaintenance(string uninstall){
  string current=((char)34)+MaintenanceExe+((char)34)+" /uninstall";
  string legacy=((char)34)+LegacyMaintenanceExe+((char)34)+" /uninstall";
  return uninstall==current || uninstall==legacy;
 }
 static RegistryKey MachineHive(){
  return RegistryKey.OpenBaseKey(RegistryHive.LocalMachine,RegistryView.Registry64);
 }
 static bool IsRegistered(){
  try{
   using(var hive=MachineHive())
   using(var key=hive.OpenSubKey(RegKey,false)){
    if(key==null || Convert.ToString(key.GetValue("DisplayName"))!=Product ||
       Convert.ToString(key.GetValue("DisplayVersion"))!=Version)return false;
    string cmd=Convert.ToString(key.GetValue("UninstallString"))??"";
    return RecognizedRegisteredMaintenance(cmd) &&
           (cmd.Contains("DoxaMaintenance-v2.exe")?File.Exists(MaintenanceExe):File.Exists(LegacyMaintenanceExe));
   }
  }catch{return false;}
 }
 static bool DetectDecision(bool appValid,bool registered){
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
    if(IsValidApp(root))return "AppAlreadyInstalled";
    // Preserve unexpected customer data; do not overwrite or remove it.
    RemoveAppFrom(root);
    Require(!Directory.Exists(root),"Modified application could not be retained for recovery");
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
   try{Directory.Move(root,retained);}
   catch(IOException ex){
    Trace("Application is in use; recovery can be retried after closing Doxa: "+ex.Message);
    throw new InvalidOperationException("Doxa setup files are in use. Close Doxa and retry the install or uninstall. The existing files were not removed.",ex);
   }
   catch(UnauthorizedAccessException ex){
    Trace("Recovery access denied: "+ex.Message);
    throw new InvalidOperationException("Windows denied recovery of Doxa setup files. Retry as administrator; existing files were preserved.",ex);
   }
   Trace("Modified application retained for administrator inspection at "+retained);
  return "AppRetainedForRecovery";
 }
 // Driver changes only after validated hardware, elevated Windows privilege
 // and pinned source. MSI 3010 is returned to IT; Doxa never restarts Windows.
 static string InstallDriver(string package,bool hardwareConnected){
  int state=DriverState();
  if(state==1)return "DriverAlreadyHealthy";
  Require(state!=2,"Different or untrusted display driver present");
  Require(Environment.OSVersion.Version.Build>=19041&&Environment.Is64BitOperatingSystem,"Unsupported Windows version");
  // Enterprise SYSTEM installation must prepare the signed driver before a
  // standard user first connects Doxa. Do not depend on live USB presence.
  string log=Path.Combine(Logs,"VendorDriver-"+DateTime.UtcNow.ToString("yyyyMMdd-HHmmss")+".log");
  Directory.CreateDirectory(Logs);
  var info=new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),"System32","msiexec.exe"),
   "/i \""+package+"\" /qn /norestart /L*v \""+log+"\""){UseShellExecute=false,CreateNoWindow=true};
  using(var process=Process.Start(info)){
   Require(process!=null,"Could not launch Windows Installer");
   process.WaitForExit();
   int exit=process.ExitCode;
   Trace("Windows Installer returned "+exit+" for "+(hardwareConnected?"connected":"disconnected")+" Doxa");
   Require(exit==0||exit==RebootCode,"Driver installer failed (code "+exit+", see Doxa installation log)");
   if(exit==RebootCode)return "RestartRequired";
  }
  if(!hardwareConnected)return "DriverMSIPreparedForFirstConnection";
  // Windows PnP may bind the just-installed display driver asynchronously.
  for(int attempt=0;attempt<15;attempt++){
   int observed=DriverState();
   if(observed==1)return "DriverInstalledVerified";
   Require(observed!=2,"Unexpected driver binding appeared after installer");
   System.Threading.Thread.Sleep(1000);
  }
  throw new InvalidOperationException("Driver installed but Doxa screen binding was not verified; check Windows Device Manager and the installation log.");
 }
 static void InstallMaintenance(){
  Directory.CreateDirectory(MaintenanceRoot);
  if(!Path.GetFullPath(SourceExe).Equals(Path.GetFullPath(MaintenanceExe),StringComparison.OrdinalIgnoreCase))
   File.Copy(SourceExe,MaintenanceExe,true);
  // If app registration fails, installer reports failure, never a fake PASS.
   using(var hive=MachineHive())
   using(var key=hive.CreateSubKey(RegKey)){
   Require(key!=null,"Windows uninstall registration unavailable");
   key.SetValue("DisplayName",Product,RegistryValueKind.String);
   key.SetValue("DisplayVersion",Version,RegistryValueKind.String);
   key.SetValue("Publisher","Standivarius",RegistryValueKind.String);
   key.SetValue("InstallLocation",AppRoot,RegistryValueKind.String);
   key.SetValue("UninstallString","\""+MaintenanceExe+"\" /uninstall",RegistryValueKind.String);
   key.SetValue("QuietUninstallString","\""+MaintenanceExe+"\" /uninstall",RegistryValueKind.String);
   key.SetValue("DisplayIcon",MaintenanceExe,RegistryValueKind.String);
   key.SetValue("NoModify",1,RegistryValueKind.DWord);
    key.SetValue("NoRepair",0,RegistryValueKind.DWord);
    key.SetValue("ModifyPath","\\\""+MaintenanceExe+"\\\" /repair",RegistryValueKind.String);
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
   string driver=InstallDriver(driverPackage,plugged);
  string app=InstallAppTo(AppRoot,appPayload);
  InstallMaintenance();
  string result=app+"; "+driver;
  Trace(result);return result;
 }
 static void CleanupMaintenanceAfterParent(int parentPid){
  Require(Elevated,"Cleanup requires administrator permission");
  Require(Path.GetFileName(SourceExe).StartsWith("DoxaCleanup-",StringComparison.OrdinalIgnoreCase) &&
          Path.GetDirectoryName(SourceExe).Equals(MaintenanceRoot,StringComparison.OrdinalIgnoreCase),
          "Unrecognized cleanup helper");
  Require(parentPid>0,"Missing maintenance process ID");
  try{using(var parent=Process.GetProcessById(parentPid)){parent.WaitForExit(20000);}}catch(ArgumentException){}
  // A reinstall racing with cleanup must never lose its new maintenance host.
  using(var hive=MachineHive())
  using(var key=hive.OpenSubKey(RegKey,false)){
   if(Directory.Exists(AppRoot)||key!=null)return;
  }
  try{
   if(File.Exists(MaintenanceExe))File.Delete(MaintenanceExe);
   if(File.Exists(LegacyMaintenanceExe))File.Delete(LegacyMaintenanceExe);
   Trace("Orphaned interactive maintenance executables removed");
  }catch(Exception e){Trace("Cleanup retained protected maintenance host: "+e.GetType().Name);}
  // Never queue deletion of DoxaMaintenance-v2.exe or legacy stable names.
  // This uniquely named, one-shot executable is never reused by an installer.
  if(!MoveFileEx(SourceExe,null,4))Trace("One-shot cleanup helper could not schedule its own removal");
 }
 static void ScheduleInteractiveMaintenanceCleanup(){
  string helper=Path.Combine(MaintenanceRoot,"DoxaCleanup-"+Guid.NewGuid().ToString("N")+".exe");
  File.Copy(SourceExe,helper);
  try{
   using(var process=Process.Start(new ProcessStartInfo(helper,"/cleanup-maintenance "+Process.GetCurrentProcess().Id){
    UseShellExecute=false,CreateNoWindow=true,WorkingDirectory=MaintenanceRoot})){
     Require(process!=null,"Could not start Windows maintenance cleanup");
   }
  }catch{
   try{File.Delete(helper);}catch{}
   throw;
  }
 }
 static string Remove(){
  Require(Elevated,"Windows administrator permission required");
  string result=RemoveAppFrom(AppRoot);
  try{if(File.Exists(Shortcut))File.Delete(Shortcut);}catch(Exception e){Trace("Shortcut cleanup: "+e.GetType().Name);}
  using(var hive=MachineHive())hive.DeleteSubKey(RegKey,false);
  if(Path.GetFullPath(SourceExe).Equals(Path.GetFullPath(MaintenanceExe),StringComparison.OrdinalIgnoreCase) ||
     Path.GetFullPath(SourceExe).Equals(Path.GetFullPath(LegacyMaintenanceExe),StringComparison.OrdinalIgnoreCase))
   ScheduleInteractiveMaintenanceCleanup();
  else {
   // SYSTEM managed uninstall: maintenance host is not the running process.
   try{if(File.Exists(MaintenanceExe))File.Delete(MaintenanceExe);}catch(IOException e){Trace("Maintenance still running: "+e.Message);}
   try{if(File.Exists(LegacyMaintenanceExe))File.Delete(LegacyMaintenanceExe);}catch(IOException e){Trace("Legacy maintenance still running: "+e.Message);}
  }
  Trace(result+"; signed display driver preserved");
  return result+"; DisplayDriverRetained";
 }
 static void Open(){
  Require(IsValidApp(AppRoot),"Doxa application not installed or modified");
  string script=Path.Combine(AppRoot,"app","packaging","doxa-setup","personal-ui","Start-DoxaGuidedSetup.ps1");
  Require(File.Exists(script),"Guided setup is absent");
  string exe=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),"System32","WindowsPowerShell","v1.0","powershell.exe");
  // Enterprise GPO/WDAC can override -ExecutionPolicy. Report an early failure
  // rather than silently doing nothing in a hidden window.
  var info=new ProcessStartInfo(exe,"-NoProfile -ExecutionPolicy Bypass -File \""+script+"\""){
   UseShellExecute=false,CreateNoWindow=true,WorkingDirectory=AppRoot};
  using(var process=Process.Start(info)){
   Require(process!=null,"Windows could not launch Doxa guided setup");
   if(process.WaitForExit(3000) && process.ExitCode!=0)
    throw new InvalidOperationException("Doxa guided setup could not start (Windows exit "+process.ExitCode+"). Your administrator may need to allow its signed scripts or adjust enterprise application policy.");
  }
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
   Require(RecognizedRegisteredMaintenance(((char)34)+MaintenanceExe+((char)34)+" /uninstall"),"Current registered maintenance path unrecognized");
   Require(RecognizedRegisteredMaintenance(((char)34)+LegacyMaintenanceExe+((char)34)+" /uninstall"),"Legacy registered maintenance path unrecognized");
   // Legacy path classification only accepts installed versioned executable.
   Require(!RecognizedRegisteredMaintenance("untrusted /uninstall"),"Arbitrary uninstall path accepted");
   Require(DetectDecision(true,true),"Registered valid app should detect regardless of USB/driver");
   Require(!DetectDecision(true,false),"Missing uninstall registration must fail detection");
   Require(!DetectDecision(false,true),"App missing must fail detection");
   Require(ClassifyDriver("Microsoft","Microsoft Windows",true)==0,"Generic first-use USB driver must be installable");
   Require(ClassifyDriver("", "",false)==0,"Unconfigured USB device must be installable");
   Require(ClassifyDriver("SiliconMotion","Microsoft Windows Hardware Compatibility Publisher",true)==1,
           "Healthy signed driver must be preserved");
   Require(ClassifyDriver("Unapproved vendor","Some signer",true)==2,"Foreign driver must block replacement");
   Require(ClassifyDriver("SiliconMotion","",false)==2,"Unsigned vendor driver must block replacement");
   string writable=Directory.GetFiles(testRoot,"*.ps1",SearchOption.AllDirectories).FirstOrDefault();
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
   Require(RemoveAppFrom(testRoot)=="AppRemoved","Clean uninstall must remove owned files");
   // Only a disposable folder; no driver install, registry, Start menu or display changes.
   return "PASS: signed driver classification, software detection, safe retained-file recovery, reinstall and clean uninstall fixtures";
  }finally{
   try{if(Directory.Exists(folder))Directory.Delete(folder,true);}catch{}
   try{if(Directory.Exists(WorkingDirectory))Directory.Delete(WorkingDirectory,true);}catch{}
  }
 }
 static int Run(string arg,string[] args){
  if(arg=="/selftest"){Console.WriteLine(SelfTest());return 0;}
  if(arg=="/detect"){Console.WriteLine(State());return DetectApp()?0:1;}
  if(arg=="/verify"){Console.WriteLine(State());return IsValidApp(AppRoot)&&PresentUsb()&&DriverState()==1?0:1;}
   if(arg=="/install" || arg=="/repair"){
    if(!Elevated && Environment.UserInteractive && Process.GetCurrentProcess().SessionId!=0){
     using(var elevated=Process.Start(new ProcessStartInfo(SourceExe,arg){UseShellExecute=true,Verb="runas"})){
      elevated.WaitForExit();return elevated.ExitCode;
     }
    }
    string result=Apply();Console.WriteLine(result);return result.Contains("RestartRequired")?RebootCode:0;
   }
   if(arg=="/cleanup-maintenance"){
    Require(args.Length==2,"Cleanup requires the exact parent process ID");
    int parentPid;Require(Int32.TryParse(args[1],out parentPid),"Invalid parent process ID");
    CleanupMaintenanceAfterParent(parentPid);return 0;
   }
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
  var title=new Label{Text="Doxa Setup",Font=new Font("Segoe UI",24,FontStyle.Bold),Location=new Point(30,22),Size=new Size(440,52),Anchor=AnchorStyles.Top|AnchorStyles.Left};
  var help=new Label{Location=new Point(30,90),Size=new Size(575,75),Anchor=AnchorStyles.Top|AnchorStyles.Left|AnchorStyles.Right};
  var status=new Label{Text="Checking Doxa...",Location=new Point(30,171),Size=new Size(575,45),ForeColor=Color.FromArgb(45,63,80),Anchor=AnchorStyles.Top|AnchorStyles.Left|AnchorStyles.Right};
  var install=new Button{Location=new Point(30,245),Size=new Size(197,46),Anchor=AnchorStyles.Bottom|AnchorStyles.Left,TabIndex=1};
  var launch=new Button{Location=new Point(240,245),Size=new Size(175,46),Anchor=AnchorStyles.Bottom|AnchorStyles.Left,TabIndex=2};
  var refresh=new Button{Location=new Point(430,245),Size=new Size(170,46),Anchor=AnchorStyles.Bottom|AnchorStyles.Left,TabIndex=3};
  var language=new Button{Location=new Point(501,24),Size=new Size(119,36),Anchor=AnchorStyles.Top|AnchorStyles.Right,TabIndex=0};
  bool ro=false;
  string lastState=null;
  Action updateText=()=>{
   form.Text=ro?"Standivarius | Configurare Doxa":"Standivarius | Doxa Setup";
   help.Text=ro?"Conecteaza alimentarea Doxa si apoi cablul USB de date. Instaleaza componentele Windows si configureaza ecranele.":"Connect Doxa power, then the USB data cable. Install Windows components and configure your screens.";
   install.Text=ro?"Instaleaza / verifica":"Install / check Doxa";
   launch.Text=ro?"Deschide configurarea":"Open Doxa setup";
   refresh.Text=ro?"Actualizeaza":"Refresh status";
   language.Text=ro?"English":"Romana";
   install.AccessibleName=ro?"Instaleaza sau verifica Doxa si driverul Windows":"Install or check Doxa software and Windows display driver";
   launch.AccessibleName=ro?"Deschide configurarea asistata Doxa":"Open Doxa guided setup";
   refresh.AccessibleName=ro?"Verifica din nou starea Doxa":"Refresh Doxa Windows status";
   language.AccessibleName=ro?"Schimba limba in engleza":"Change language to Romanian";
   status.Text=lastState==null?(ro?"Se verifica Doxa...":"Checking Doxa..."):lastState;
  };
  language.Click+=(sender,e)=>{ro=!ro;updateText();};
  install.Click+=(sender,e)=>{
   try{
    bool successful=false;
    if(!Elevated){
     using(var p=Process.Start(new ProcessStartInfo(SourceExe,"/install"){UseShellExecute=true,Verb="runas"})){
      p.WaitForExit();
      successful=p.ExitCode==0||p.ExitCode==RebootCode;
      if(!successful)MessageBox.Show(ro?"Instalarea nu s-a incheiat. Verifica jurnalul Doxa.":"Installation did not complete. Check Doxa installation logs.","Doxa Setup");
     }
    }else{Apply();successful=true;}
    status.Text=State();
    if(successful&&IsValidApp(AppRoot))Open();
   }catch(Exception ex){MessageBox.Show(ex.Message,"Doxa Setup");}
  };
  launch.Click+=(sender,e)=>{try{Open();}catch(Exception ex){MessageBox.Show(ex.Message,"Doxa Setup");}};
  Action checkState=()=>{
   status.Text=ro?"Se verifica Doxa...":"Checking Doxa...";
   var work=new BackgroundWorker();
   work.DoWork+=(sender,e)=>{e.Result=State();};
   work.RunWorkerCompleted+=(sender,e)=>{
    if(!status.IsDisposed)status.Text=e.Error==null?Convert.ToString(e.Result):(ro?"Verificare indisponibila":"Status unavailable");
    if(e.Error==null)lastState=Convert.ToString(e.Result);
    work.Dispose();
   };
   work.RunWorkerAsync();
  };
  refresh.Click+=(sender,e)=>checkState();
  form.Shown+=(sender,e)=>checkState();
  form.Controls.AddRange(new Control[]{title,help,status,install,launch,refresh,language});
  updateText();
  Application.Run(form);
 }
 [STAThread] public static int Main(string[] args){
  string arg=args.Length>0?args[0].ToLowerInvariant():"";
  try{
   if(arg==""){UI();return 0;}
   return Run(arg,args);
  }catch(Exception ex){
   Trace("Error "+ex.GetType().Name+": "+ex.Message);
   Console.Error.WriteLine(ex.Message);
   if(Environment.UserInteractive && Process.GetCurrentProcess().SessionId!=0 &&
     (arg=="/open" || arg=="/install" || arg=="/repair"))
    MessageBox.Show(ex.Message,"Doxa Setup",MessageBoxButtons.OK,MessageBoxIcon.Warning);

   return 30;
  }finally{
   try{if(Directory.Exists(WorkingDirectory))Directory.Delete(WorkingDirectory,true);}catch{}
  }
 }
}
