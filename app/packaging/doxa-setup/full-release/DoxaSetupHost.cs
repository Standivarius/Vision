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
  static bool PreserveWorkingDirectoryOnMsiTimeout=false;
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
 static string FriendlyState(string raw,bool romanian){
  bool app=raw.Contains("AppInstalled");
  bool driver=raw.Contains("DriverValid");
  bool foreign=raw.Contains("DriverUntrusted");
  bool connected=raw.Contains("USBDetected");
  if(foreign)return romanian?
   "Driver neidentificat. Configurarea s-a oprit pentru a proteja ecranele.":
   "Unrecognized display driver. Setup is stopped to protect your screens.";
  if(!app)return romanian?
   "Configurarea Doxa nu este instalata. Apasa Instaleaza / verifica.":
   "Doxa setup is not installed. Choose Install / check Doxa.";
  if(!connected)return romanian?
   "Doxa nu este conectat. Conecteaza alimentarea, apoi cablul USB de date.":
   "Doxa is not connected. Connect power first, then the USB data cable.";
  if(!driver)return romanian?
   "Doxa este conectat, dar driverul nu este confirmat. Verifica instalarea.":
   "Doxa is connected, but its driver is not verified. Check installation.";
  return romanian?
   "Doxa si driverul semnat sunt detectate. Verifica ecranele in Windows.":
   "Doxa and its signed driver are detected. Check your screens in Windows.";
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
   if(source!=21||allowed.Count!=24)return false;
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
  static void RequireSupportedWindows(){
   Require(Environment.Is64BitOperatingSystem,"Windows 64-bit is required");
   int build=0;
   try{
    using(var search=new ManagementObjectSearcher("SELECT BuildNumber FROM Win32_OperatingSystem"))
    foreach(ManagementObject item in search.Get()){
     if(Int32.TryParse(Convert.ToString(item["BuildNumber"]),out build))break;
    }
   }catch(Exception ex){throw new InvalidOperationException("Windows version could not be checked: "+ex.GetType().Name);}
   Require(build>=19041,"Unsupported Windows version (build "+build+")");
  }
  static bool VerifyDriverDecision(bool app,bool usb,bool trusted){return app&&usb&&trusted;}
  static bool VerifyPanelDecision(bool app,bool usb,bool trusted,IEnumerable<string> names){
   if(!VerifyDriverDecision(app,usb,trusted))return false;
   var found=new HashSet<string>(names??Enumerable.Empty<string>(),StringComparer.OrdinalIgnoreCase);
   return new[]{"Generic Monitor (L)","Generic Monitor (T)","Generic Monitor (R)"}.All(found.Contains);
  }
  static bool ThreeDoxaPanelsPresent(){
   try{
    var monitors=new List<string>();
    using(var q=new ManagementObjectSearcher("SELECT Name,PNPClass,PNPDeviceID FROM Win32_PnPEntity WHERE PNPClass='Monitor'"))
    foreach(ManagementObject item in q.Get()){
     string id=Convert.ToString(item["PNPDeviceID"])??"";uint node;
     // Exclude disconnected/ghost PnP monitor records, which may retain a friendly name.
     if(!String.IsNullOrWhiteSpace(id) && LocateDevice(out node,id,0)==0)monitors.Add(Convert.ToString(item["Name"])??"");
    }
    return VerifyPanelDecision(true,true,true,monitors);
   }catch{return false;}
  }
  static string InstallDriver(string package,bool hardwareConnected){
  int state=DriverState();
  if(state==1)return "DriverAlreadyHealthy";
  Require(state!=2,"Different or untrusted display driver present");

  // Enterprise SYSTEM installation must prepare the signed driver before a
  // standard user first connects Doxa. Do not depend on live USB presence.
  string log=Path.Combine(Logs,"VendorDriver-"+DateTime.UtcNow.ToString("yyyyMMdd-HHmmss")+".log");
  Directory.CreateDirectory(Logs);
  var info=new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),"System32","msiexec.exe"),
   "/i \""+package+"\" /qn /norestart /L*v \""+log+"\""){UseShellExecute=false,CreateNoWindow=true};
   using(var process=Process.Start(info)){
   Require(process!=null,"Could not launch Windows Installer");
    // Never terminate msiexec mid-transaction; an overlong run is explicit,
    // with logs preserved for IT. The process may still be running.
    if(!process.WaitForExit(600000)){
      PreserveWorkingDirectoryOnMsiTimeout=true;
      Trace("Vendor MSI timeout; staging retained at "+WorkingDirectory);
      throw new InvalidOperationException("Vendor MSI still running after 10 minutes. Extracted MSI is retained; check Windows Installer and Doxa logs before retrying.");
    }
   int exit=process.ExitCode;
   Trace("Windows Installer returned "+exit+" for "+(hardwareConnected?"connected":"disconnected")+" Doxa");
   Require(exit==0||exit==RebootCode,"Driver installer failed (code "+exit+", see Doxa installation log)");
   if(exit==RebootCode)return "RestartRequired";
  }
  if(!hardwareConnected)return "DriverMSIPreparedForFirstConnection";
  // Windows PnP may bind the just-installed display driver asynchronously.
  for(int attempt=0;attempt<60;attempt++){
   int observed=DriverState();
   if(observed==1)return "DriverInstalledVerified";
   Require(observed!=2,"Unexpected driver binding appeared after installer");
   System.Threading.Thread.Sleep(1000);
  }
  Trace("Driver MSI succeeded; PnP binding still pending after 60 seconds");
   return "DriverBindingPending"; // software is installed; hardware /verify remains incomplete.
 }
  static string RepairRegistrationCommand(string path){
   return "\""+path+"\" /repair";
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
     key.SetValue("ModifyPath",RepairRegistrationCommand(MaintenanceExe),RegistryValueKind.String);
  }
  try{
   Directory.CreateDirectory(Path.GetDirectoryName(Shortcut));
   dynamic shell=Activator.CreateInstance(Type.GetTypeFromProgID("WScript.Shell"));
   dynamic link=shell.CreateShortcut(Shortcut);
   link.TargetPath=MaintenanceExe;link.Arguments="/open";
   link.WorkingDirectory=AppRoot;link.Description=Product;link.Save();
  }catch(Exception e){Trace("Start menu shortcut unavailable: "+e.GetType().Name);}
 }
  // Source-testable gate: never invoke vendor custom actions during first-run
  // personal preparation, a disconnected install, or a healthy-driver no-op.
  static bool MayRunVendorMsi(bool applicationOnly,bool usbPresent,int driverBinding){
   return !applicationOnly && usbPresent && driverBinding==0;
  }
  static string Apply(bool applicationOnly=false){
  Require(Elevated,"Windows administrator permission required");
  RequireSupportedWindows();
   string driverPackage=VerifyAndUnpackDriver();
  string appPayload=VerifyAndUnpackApplication();
  // An enterprise disconnected pre-provisioning run INVOKES the vendor MSI.
   // Its first-use hardware behavior is not yet physically qualified.
    bool plugged=PresentUsb();
   int current=DriverState();
   Require(current!=2,"Unexpected driver identity: installation refused");
   // First-run personal setup installs APPLICATION ONLY. The guided connection
   // page must run before a user can initiate the signed driver action.
   // Enterprise also never invokes vendor MSI before USB hardware is present:
   // vendor disconnected MSI custom actions have not passed a physical test.
   string driver=applicationOnly?"DriverNotChangedAwaitingConnection":
    !plugged?"DriverDeferredUntilConnected":
    current==1?"DriverAlreadyHealthy":
    MayRunVendorMsi(applicationOnly,plugged,current)?InstallDriver(driverPackage,true):
    "DriverDeferredUntilConnected";
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
  static void Open(bool localConsentAlreadyGranted=false,bool onlineAiAllowed=false){
   Require(IsValidApp(AppRoot),"Doxa application not installed or modified");
  string script=Path.Combine(AppRoot,"app","packaging","doxa-setup","personal-ui","Start-DoxaGuidedSetup.ps1");
  Require(File.Exists(script),"Guided setup is absent");
  string exe=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),"System32","WindowsPowerShell","v1.0","powershell.exe");
  // Enterprise GPO/WDAC can override -ExecutionPolicy. Report an early failure
  // rather than silently doing nothing in a hidden window.
   var info=new ProcessStartInfo(exe,"-NoProfile -ExecutionPolicy Bypass -File \""+script+"\""+
    (localConsentAlreadyGranted?" -LocalConsentAlreadyGranted -PermissionsGrantedInHost":"")+(onlineAiAllowed?" -OnlineAIAllowedInHost":"")){
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
   Require(RepairRegistrationCommand(MaintenanceExe)==((char)34)+MaintenanceExe+((char)34)+" /repair","Windows repair registration must contain quoted executable without backslashes");
    Require(RecognizedRegisteredMaintenance(((char)34)+MaintenanceExe+((char)34)+" /uninstall"),"Current registered maintenance path unrecognized");
   Require(RecognizedRegisteredMaintenance(((char)34)+LegacyMaintenanceExe+((char)34)+" /uninstall"),"Legacy registered maintenance path unrecognized");
   // Legacy path classification only accepts installed versioned executable.
   Require(!RecognizedRegisteredMaintenance("untrusted /uninstall"),"Arbitrary uninstall path accepted");
   Require(FriendlyState("AppInstalled DriverValid USBDetected",false).Contains("signed driver"),"English ready status not human readable");
   Require(FriendlyState("AppInstalled DriverValid USBAbsent",true).Contains("alimentarea"),"Romanian disconnected guidance missing");
   Require(FriendlyState("AppMissing DriverValid USBDetected",false).Contains("not installed"),"Customer missing app status missing");
    Require(VerifyDriverDecision(true,true,true),"Trusted driver and USB should pass machine verification");
    Require(!VerifyDriverDecision(true,false,true),"Missing connected USB must fail machine verification");
    Require(VerifyPanelDecision(true,true,true,new[]{"Generic Monitor (L)","Generic Monitor (T)","Generic Monitor (R)"}),"Three monitor identities must pass panel PnP check");
    Require(!VerifyPanelDecision(true,true,true,new[]{"Generic Monitor (L)","Generic Monitor (R)"}),"Two panels must fail verification");
    Require(DetectDecision(true,true),"Registered valid app should detect regardless of USB/driver");
   Require(!DetectDecision(true,false),"Missing uninstall registration must fail detection");
   Require(!DetectDecision(false,true),"App missing must fail detection");
    Require(!MayRunVendorMsi(true,true,0),"Personal app preparation must never execute MSI");
    Require(!MayRunVendorMsi(false,false,0),"USB-disconnected installation must never execute MSI");
    Require(!MayRunVendorMsi(false,true,1),"Healthy driver must never execute MSI");
    Require(!MayRunVendorMsi(false,true,2),"Untrusted driver must never execute MSI");
    Require(MayRunVendorMsi(false,true,0),"Only present USB with missing driver may request MSI");
    Require(ClassifyDriver("Microsoft","Microsoft Windows",true)==0,"Generic first-use USB driver must be installable");
   Require(ClassifyDriver("", "",false)==0,"Unconfigured USB device must be installable");
    Require(ClassifyDriver("SiliconMotion","Microsoft Windows Hardware Compatibility Publisher",true)==1,
            "Healthy signed driver must be preserved");
    Require(ClassifyDriver("Silicon Motion, Inc.","Microsoft Windows Hardware Compatibility Publisher",true)==1,
            "Documented alternate manufacturer spelling must be recognized");
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
   try{if(!PreserveWorkingDirectoryOnMsiTimeout && Directory.Exists(WorkingDirectory))Directory.Delete(WorkingDirectory,true);}catch{}
  }
 }
 static int Run(string arg,string[] args){
  if(arg=="/selftest"){Console.WriteLine(SelfTest());return 0;}
  if(arg=="/detect"){Console.WriteLine(State());return DetectApp()?0:1;}
  if(arg=="/verify"){Console.WriteLine(State());return VerifyDriverDecision(IsValidApp(AppRoot),PresentUsb(),DriverState()==1)?0:1;}
   if(arg=="/verify-panels"){
    bool app=IsValidApp(AppRoot),usb=PresentUsb(),driver=DriverState()==1;
    bool pnp=app&&usb&&driver&&ThreeDoxaPanelsPresent();
    Console.WriteLine(pnp?"ThreeDoxaPnPMonitorIdentitiesPresent; ExtendModeNotVerified":"ThreeDoxaPnPMonitorIdentitiesNotVerified");
    return pnp?0:1;
   }
   if(arg=="/install" || arg=="/repair" || arg=="/prepare"){
     if(!Elevated && Environment.UserInteractive && Process.GetCurrentProcess().SessionId!=0){
      using(var elevated=Process.Start(new ProcessStartInfo(SourceExe,arg){UseShellExecute=true,Verb="runas"})){
       Require(elevated!=null,"Could not request Windows administrator approval");
       Require(elevated.WaitForExit(720000),"Elevated installation is still running; check Windows Installer before retrying");
       return elevated.ExitCode;
      }
     }
     string result=Apply(arg=="/prepare");Console.WriteLine(result);return result.Contains("RestartRequired")?RebootCode:0;
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
  var form=new Form{Text="Standivarius | Doxa Triple Monitor Setup",ClientSize=new Size(830,590),MinimumSize=new Size(790,580),StartPosition=FormStartPosition.CenterScreen,Font=new Font("Segoe UI",10),BackColor=Color.White,AutoScaleMode=AutoScaleMode.Dpi};
  bool ro=false,accepted=false,running=false;string snapshot=null;
  var brand=new Label{Text="STANDIVARIUS",Location=new Point(30,15),Size=new Size(220,30),Font=new Font("Segoe UI",11,FontStyle.Bold)};
  var langLabel=new Label{Text="Language",Location=new Point(538,20),Size=new Size(75,28)};
  var lang=new ComboBox{Location=new Point(622,16),Size=new Size(175,32),DropDownStyle=ComboBoxStyle.DropDownList,AccessibleName="Current setup language"};
  lang.Items.Add("English");lang.Items.Add("Română");lang.SelectedIndex=0;
  var photo=new PictureBox{Location=new Point(30,54),Size=new Size(160,142),SizeMode=PictureBoxSizeMode.Zoom,AccessibleName="Doxa Pro 3 product photograph"};
  try{using(var stream=System.Reflection.Assembly.GetExecutingAssembly().GetManifestResourceStream("Doxa.ProductPhoto")){if(stream!=null)using(var im=Image.FromStream(stream))photo.Image=new Bitmap(im);}}catch(Exception ex){Trace("Photo unavailable: "+ex.GetType().Name);}
  var title=new Label{Text="Doxa Triple Monitor Setup",Location=new Point(211,67),Size=new Size(575,60),Font=new Font("Segoe UI",24,FontStyle.Bold)};
  var subtitle=new Label{Location=new Point(213,137),Size=new Size(575,55)};
  var separator=new Panel{Location=new Point(30,209),Size=new Size(765,2),BackColor=Color.LightGray};
  var step=new Label{Location=new Point(31,225),Size=new Size(750,45),Font=new Font("Segoe UI",15,FontStyle.Bold)};
  var terms=new CheckBox{Location=new Point(31,285),Size=new Size(740,30),TabIndex=1};
  var termsDetails=new LinkLabel{Location=new Point(57,319),Size=new Size(600,27),TabIndex=2};
  var local=new CheckBox{Location=new Point(31,366),Size=new Size(743,51),TabIndex=3};
  var cloud=new CheckBox{Location=new Point(31,438),Size=new Size(744,42),TabIndex=4};
  var status=new Label{Location=new Point(32,279),Size=new Size(740,45),Visible=false};
  var usb=new Label{Location=new Point(32,340),Size=new Size(740,36),Visible=false};
  var driver=new Label{Location=new Point(32,391),Size=new Size(740,46),Visible=false};
  var app=new Label{Location=new Point(32,454),Size=new Size(740,29),Visible=false};
  var back=new Button{Text="Back",Location=new Point(31,516),Size=new Size(124,45),Visible=false};
  var refresh=new Button{Location=new Point(164,516),Size=new Size(170,45),Visible=false};
  var install=new Button{Location=new Point(344,516),Size=new Size(213,45),Visible=false};
  var open=new Button{Location=new Point(568,516),Size=new Size(228,45),Visible=false};
  var next=new Button{Location=new Point(568,516),Size=new Size(228,45),TabIndex=5,BackColor=Color.FromArgb(165,27,51),ForeColor=Color.White};
  form.Controls.AddRange(new Control[]{brand,langLabel,lang,photo,title,subtitle,separator,step,terms,termsDetails,local,cloud,status,usb,driver,app,back,refresh,install,open,next});
  string termsEn="DOXA SETUP PREVIEW TERMS - 29 OCTOBER 2026\r\n\r\n"+
   "Publisher: DMR ERGONOMICS S.R.L. (Standivarius).\r\n\r\n"+
   "1. This early access application helps configure the Doxa Pro 3 triple monitor. Driver changes require separate Windows approval. The first personal setup installs the application only; an existing healthy signed display driver is preserved.\r\n\r\n"+
   "2. With separate consent, local checks inspect Windows version, USB and display presence and driver status. No local checks run before approval.\r\n\r\n"+
   "3. Optional Doxa AI assistance may transmit a typed question and restricted diagnostic details over HTTPS if this device is enrolled. It is off by default. No screen images or passwords are uploaded by the current assistant.\r\n\r\n"+
   "4. This is a private evaluation build, not a final public release. You can stop setup at any time or uninstall the application in Windows Settings. The display driver remains installed during application uninstall.";
  string termsRo="CONDITII DOXA SETUP - VERSIUNE DE EVALUARE - 29 OCTOMBRIE 2026\r\n\r\n"+
   "Editor: DMR ERGONOMICS S.R.L. (Standivarius).\r\n\r\n"+
   "1. Aplicatia ajuta la configurarea Doxa Pro 3. Driverul necesita aprobare Windows separata, iar driverul functional este pastrat.\r\n\r\n"+
   "2. Cu acord separat, verificarile locale examineaza Windows, dispozitivele USB, ecranele si driverele. Nicio verificare nu ruleaza fara permisiune.\r\n\r\n"+
   "3. Asistenta AI este optionala, dezactivata implicit si necesita un dispozitiv autorizat. Poate trimite intrebari si date limitate de diagnostic prin HTTPS, fara capturi sau parole.\r\n\r\n"+
   "4. Este o versiune privata de test. Poti opri sau dezinstala aplicatia din Windows, fara a elimina driverul de afisare.";
  Action render=()=>{
    ro=lang.SelectedIndex==1;
    form.Text=ro?"Standivarius | Configurare Doxa Triple Monitor":"Standivarius | Doxa Triple Monitor Setup";
    langLabel.Text=ro?"Limbă":"Language";
    title.Text=ro?"Configurare Doxa Triple Monitor":"Doxa Triple Monitor Setup";
    subtitle.Text=ro?"Conecteaza Doxa Pro 3 si configureaza ecranele Windows.\r\nPoti continua si fara Doxa conectat.":"Connect Doxa Pro 3 and configure your Windows displays.\r\nYou can also prepare this computer without Doxa connected.";
    step.Text=accepted?(ro?"Pasul 2 - Verificare dispozitive":"Step 2 - Check this computer"):(ro?"Pasul 1 - Conditii si permisiuni":"Step 1 - Terms and permissions");
    terms.Text=ro?"Accept conditiile pentru versiunea de evaluare Doxa Setup.":"I agree to the Doxa Setup preview terms.";
    termsDetails.Text=ro?"Citeste conditiile complete":"Read the full terms";
    local.Text=ro?"Permit verificarea locala, fara modificari, a Windows, USB, ecranelor si driverelor.":"I allow local read-only checks of Windows, USB, displays and installed drivers.";
    cloud.Text=ro?"Optional: doresc asistenta Doxa AI online daca este disponibila pe acest PC.":"Optional: enable Doxa AI online help if this computer is enrolled.";
    terms.Visible=termsDetails.Visible=local.Visible=cloud.Visible=!accepted;
    next.Visible=!accepted;next.Enabled=terms.Checked&&local.Checked;next.Text=ro?"Accept si continua":"Agree and continue";
    status.Visible=usb.Visible=driver.Visible=app.Visible=back.Visible=refresh.Visible=install.Visible=open.Visible=accepted;
    back.Text=ro?"Inapoi":"Back";refresh.Text=ro?"Verifica din nou":"Refresh checks";
    install.Text=ro?"Instaleaza Doxa Setup":"Install Doxa Setup";open.Text=ro?"Deschide ghidul Doxa":"Open Doxa guided setup";
    if(accepted&&snapshot!=null){
      status.Text=ro?"Verificarile locale sunt permise.":"Local checks permitted.";
      usb.Text=snapshot.Contains("USBDetected")?(ro?"Doxa: conexiune USB detectata":"Doxa: USB connection detected"):(ro?"Doxa: niciun dispozitiv conectat detectat":"Doxa: no connected device detected");
      driver.Text=snapshot.Contains("DriverUntrusted")?(ro?"Driver: necunoscut, instalarea blocata":"Driver: unrecognized; driver installation blocked"):snapshot.Contains("DriverValid")?(ro?"Driver: semnat si compatibil":"Driver: compatible signed driver detected"):(ro?"Driver: nu am detectat un driver compatibil":"Driver: no compatible signed driver detected");
      app.Text=snapshot.Contains("AppInstalled")?(ro?"Aplicatia Doxa este instalata.":"Doxa application is installed."):(ro?"Aplicatia Doxa poate fi instalata acum.":"Doxa application can now be installed.");
    }
    refresh.Enabled=!running;install.Enabled=!running&&snapshot!=null&&!snapshot.Contains("DriverUntrusted");open.Enabled=!running&&snapshot!=null&&snapshot.Contains("AppInstalled");
  };
  termsDetails.Click+=(s,e)=>{
    var dialog=new Form{Text=ro?"Conditii Doxa":"Doxa Setup terms",ClientSize=new Size(660,460),StartPosition=FormStartPosition.CenterParent};
    dialog.Controls.Add(new TextBox{Dock=DockStyle.Fill,Multiline=true,ScrollBars=ScrollBars.Vertical,WordWrap=true,ReadOnly=true,Text=ro?termsRo:termsEn});
    dialog.ShowDialog(form);dialog.Dispose();
  };
  Action scan=()=>{
    if(!accepted||running)return;
    running=true;snapshot=null;status.Text=ro?"Verificare...":"Checking...";
    usb.Text=driver.Text=ro?"Verificare in curs...":"Checking...";app.Text="";render();
    var w=new BackgroundWorker();w.DoWork+=(s,e)=>e.Result=State();
    w.RunWorkerCompleted+=(s,e)=>{
      running=false;if(form.IsDisposed){w.Dispose();return;}
      if(e.Error!=null){usb.Text=driver.Text=ro?"Indisponibil":"Unavailable";app.Text=e.Error.GetBaseException().Message;}
      else snapshot=Convert.ToString(e.Result);
      render();w.Dispose();
    };
    w.RunWorkerAsync();
  };
  next.Click+=(s,e)=>{if(!terms.Checked||!local.Checked)return;accepted=true;render();scan();};
  back.Click+=(s,e)=>{if(running)return;accepted=false;render();};
  refresh.Click+=(s,e)=>scan();
  install.Click+=(s,e)=>{
    if(!accepted||running||snapshot==null||snapshot.Contains("DriverUntrusted"))return;
    running=true;render();app.Text=ro?"Pregatim aplicatia. Aproba permisiunea Windows daca apare.":"Preparing application. Approve Windows permission if requested.";
    var w=new BackgroundWorker();w.DoWork+=(s2,e2)=>{
      int code=0;
      if(!Elevated)using(var p=Process.Start(new ProcessStartInfo(SourceExe,"/prepare"){UseShellExecute=true,Verb="runas"})){
        Require(p!=null,"Cannot start Windows setup");Require(p.WaitForExit(720000),"Windows installation timed out");code=p.ExitCode;
      }else Apply(true);
      e2.Result=code;
    };
    w.RunWorkerCompleted+=(s2,e2)=>{
      running=false;if(form.IsDisposed){w.Dispose();return;}
      if(e2.Error!=null)MessageBox.Show(e2.Error.GetBaseException().Message,"Doxa Setup");
      else if(Convert.ToInt32(e2.Result)!=0)MessageBox.Show("Doxa application installation did not complete.","Doxa Setup");
      else try{Open(true,cloud.Checked);}catch(Exception ex){MessageBox.Show(ex.Message,"Doxa Setup");}
      render();scan();w.Dispose();
    };w.RunWorkerAsync();
  };
  open.Click+=(s,e)=>{if(!accepted||running)return;try{Open(true,cloud.Checked);}catch(Exception ex){MessageBox.Show(ex.Message,"Doxa Setup");}};
  lang.SelectedIndexChanged+=(s,e)=>render();terms.CheckedChanged+=(s,e)=>render();local.CheckedChanged+=(s,e)=>render();
  form.AcceptButton=next;render();Application.Run(form);if(photo.Image!=null)photo.Image.Dispose();
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
   try{if(!PreserveWorkingDirectoryOnMsiTimeout && Directory.Exists(WorkingDirectory))Directory.Delete(WorkingDirectory,true);}catch{}
  }
 }
}
