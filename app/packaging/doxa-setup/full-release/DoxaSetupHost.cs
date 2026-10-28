// Doxa Windows release host. Built on .NET Framework (Windows built-in), no cloud or added runtime.
// All actions are local, version-locked and non-destructive to existing drivers.
using System;using System.IO;using System.Linq;using System.Security.Cryptography;using System.Security.Principal;
using System.Diagnostics;using System.Management;using System.Runtime.InteropServices;using System.Collections.Generic;using System.IO.Compression;
using System.Web.Script.Serialization;using System.Windows.Forms;using System.Drawing;using System.Text;
class DoxaHost {
 const string DriverFile="SMIUSBDisplaySW770.msi";
 const string DriverHash="3379B46DA029423748E2D2E64DB2015B50136E310A492E31857CC726719192D4";
 const string Version="0.4.0-preview.12",UsbPrefix=@"USB\VID_090C&PID_770A";
 static string Home=AppDomain.CurrentDomain.BaseDirectory;
 static string AppRoot=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),"Standivarius","DoxaSetup");
 static string Logs=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),"Standivarius","DoxaSetup","Logs");
  static readonly string EmbeddedDir=Path.Combine(
   Admin()?Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),"Standivarius","InstallerCache"):Path.GetTempPath(),
   "Doxa-"+Guid.NewGuid().ToString("N"));
 static DoxaHost(){AppDomain.CurrentDomain.ProcessExit+=(s,e)=>{try{if(Directory.Exists(EmbeddedDir))Directory.Delete(EmbeddedDir,true);}catch{}};}
 static string At(string name){
  string resource=name==DriverFile?"Doxa.Driver":name=="DoxaSetupPayload.zip"?"Doxa.App":"";
  if(resource!=""){
   using(var stream=System.Reflection.Assembly.GetExecutingAssembly().GetManifestResourceStream(resource)){
    if(stream!=null){
     Directory.CreateDirectory(EmbeddedDir);
     string extracted=Path.Combine(EmbeddedDir,name);
     if(!File.Exists(extracted))using(var file=File.Create(extracted)){stream.CopyTo(file);}
     return extracted;
    }
   }
  }
  // Source-only developer builds without embedded resources; the release
  // executables always use their own embedded contents, never sidecars.
  return Path.Combine(Home,name);
 } static void Need(bool ok,string msg){if(!ok)throw new InvalidOperationException(msg);}
 static string Hash(string path){using(var s=File.OpenRead(path))using(var h=SHA256.Create())return BitConverter.ToString(h.ComputeHash(s)).Replace("-","");}
 static bool Admin(){return new WindowsPrincipal(WindowsIdentity.GetCurrent()).IsInRole(WindowsBuiltInRole.Administrator);}
 static void Audit(string text){try{Directory.CreateDirectory(Logs);File.AppendAllText(Path.Combine(Logs,"Doxa-Installer.log"),DateTime.UtcNow.ToString("o")+" "+text+Environment.NewLine);}catch{}}
 static string Safe(string root,string relative) {
   Need(!Path.IsPathRooted(relative) && !relative.Contains("..") && !relative.Contains(":") && !relative.Contains("\\\\"),"Invalid package path");
   var path=Path.GetFullPath(Path.Combine(root,relative.Replace('/',Path.DirectorySeparatorChar)));
   Need(path.StartsWith(Path.GetFullPath(root).TrimEnd('\\')+"\\",StringComparison.OrdinalIgnoreCase),"Path traversal blocked");
   return path;
 }
 static Dictionary<string,object> ReadJson(string path){return new JavaScriptSerializer(){MaxJsonLength=1000000}.Deserialize<Dictionary<string,object>>(File.ReadAllText(path,Encoding.UTF8));}
 static bool ValidApp(string root) {
   try {
     var m=ReadJson(Path.Combine(root,"manifest.json"));
     if((string)m["product"]!="Standivarius Doxa Setup" || (string)m["preview_version"]!=Version)return false;
     int sources=0;var all=new HashSet<string>(StringComparer.OrdinalIgnoreCase){"manifest.json"};
     foreach(var field in new[]{"files","generated_files"})foreach(var o in (System.Collections.IEnumerable)m[field]){
       var entry=(Dictionary<string,object>)o;string rel=(string)entry["file"];
       if(!all.Add(rel) || !File.Exists(Safe(root,rel)) || !Hash(Safe(root,rel)).Equals((string)entry["sha256"],StringComparison.OrdinalIgnoreCase))return false;
       if(field=="files")sources++;
     }
     if(sources!=20 || all.Count!=23)return false;
     var paths=Directory.GetFiles(root,"*",SearchOption.AllDirectories);
     return paths.Length==all.Count && paths.All(p=>all.Contains(p.Substring(root.TrimEnd('\\').Length+1).Replace('\\','/')));
   }catch{return false;}
 }
 static void Extract(string zip,string dest) {
   using(var z=ZipFile.OpenRead(zip)){
     foreach(var e in z.Entries) {
       if(String.IsNullOrEmpty(e.Name))continue;
       var path=Safe(dest,e.FullName);Directory.CreateDirectory(Path.GetDirectoryName(path));
       Need(!File.Exists(path),"Duplicate archive entry blocked");e.ExtractToFile(path);
     }
   }
   Need(ValidApp(dest),"Application integrity failed");
 }
 static bool ValidDriver(){var path=At(DriverFile);return File.Exists(path)&&Hash(path).Equals(DriverHash,StringComparison.OrdinalIgnoreCase);}
 [DllImport("cfgmgr32.dll",EntryPoint="CM_Locate_DevNodeW",CharSet=CharSet.Unicode)]
 static extern int LocateLiveDevice(out uint instance,string deviceId,uint flags);
 static bool UsbPresent(){
   try{using(var q=new ManagementObjectSearcher("SELECT PNPDeviceID FROM Win32_PnPEntity"))
      foreach(ManagementObject o in q.Get())       {string id=Convert.ToString(o["PNPDeviceID"])??"";
        if(id.StartsWith(UsbPrefix,StringComparison.OrdinalIgnoreCase)){
          uint node;
          if(LocateLiveDevice(out node,id,0)==0)return true;
        }}
   }catch{}return false;
 }
 // 0 missing, 1 healthy signed, 2 present but identity unverified
 static int DriverState(){
   try{using(var q=new ManagementObjectSearcher("SELECT DeviceID,IsSigned,DriverProviderName,Signer FROM Win32_PnPSignedDriver"))
     foreach(ManagementObject o in q.Get()){
       if(!(Convert.ToString(o["DeviceID"])??"").StartsWith(UsbPrefix,StringComparison.OrdinalIgnoreCase))continue;
              string provider=Convert.ToString(o["DriverProviderName"])??"";
       string signer=Convert.ToString(o["Signer"])??"";
       return Convert.ToBoolean(o["IsSigned"]) &&
         provider.Equals("SiliconMotion",StringComparison.OrdinalIgnoreCase) &&
         signer.Equals("Microsoft Windows Hardware Compatibility Publisher",StringComparison.OrdinalIgnoreCase)?1:2;
     }}catch{}return 0;
 }
 static string InstallApp(){
   Directory.CreateDirectory(Path.GetDirectoryName(AppRoot));
   if(Directory.Exists(AppRoot)){Need(ValidApp(AppRoot),"Existing application changed; refusing overwrite");WriteShortcut();return "Application already installed";}
   var stage=Path.Combine(Path.GetDirectoryName(AppRoot),"doxa-stage-"+Guid.NewGuid().ToString("N"));
   try{Extract(At("DoxaSetupPayload.zip"),stage);Directory.Move(stage,AppRoot);WriteShortcut();return "Application installed";}
   finally{if(Directory.Exists(stage))Directory.Delete(stage,true);}
 }
 static string InstallDriver(){
   Need(ValidDriver(),"Packaged driver SHA-256 mismatch");
   int current=DriverState();
   if(current==1)return "Signed driver already present";
   Need(current!=2,"Unexpected existing driver; refuse overwrite");
   Need(UsbPresent(),"Connect Doxa data USB cable before driver installation");
   Directory.CreateDirectory(Logs);
   var logfile=Path.Combine(Logs,"Driver-"+DateTime.UtcNow.ToString("yyyyMMdd-HHmmss")+".log");
   var p=new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),"System32","msiexec.exe"),
      "/i \""+At(DriverFile)+"\" /qn /norestart /L*v \""+logfile+"\""){UseShellExecute=false,CreateNoWindow=true};
   int exit;using(var x=Process.Start(p)){x.WaitForExit();exit=x.ExitCode;}
   Audit("Windows Installer return "+exit);
   Need(exit==0 || exit==3010,"Windows Installer failed with code "+exit+"; see local log");
   if(exit==3010)return "Windows restart required (not started)";
   Need(DriverState()==1,"Installer completed but driver verification is pending; see log");
   return "Signed driver installed";
 }
 static string Apply(){
   Need(Admin(),"Windows administrator approval required");
   Need(ValidDriver(),"Driver package verification failed");
   Need(File.Exists(At("DoxaSetupPayload.zip")),"Missing Doxa application");
   // Validate and install app before doing any driver work; never remove an existing driver.
   string app=InstallApp(),driver=InstallDriver(),result=app+"; "+driver;
   Audit(result);return result;
 }
 static string Uninstall(){
   Need(Admin(),"Administrator approval required");
   if(!Directory.Exists(AppRoot))return "Already removed";
   Need(ValidApp(AppRoot),"Application files modified: refusing to remove unknown files");
   Directory.Delete(AppRoot,true);try{string link=ShortcutPath();if(File.Exists(link))File.Delete(link);}catch{}Audit("Application removed; display driver retained");
   return "Doxa application removed; display driver retained";
 }
 static string Status(){
   return (ValidApp(AppRoot)?"AppInstalled":"AppMissing")+" "+
      (DriverState()==1?"DriverValid":DriverState()==2?"DriverUntrusted":"DriverMissing")+" "+
      (UsbPresent()?"USBDetected":"USBAbsent");
 }
 static string SetupScript(){return Path.Combine(AppRoot,"app","packaging","doxa-setup","personal-ui","Start-DoxaGuidedSetup.ps1");}
 static string ShortcutPath(){return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonStartMenu),"Programs","Standivarius Doxa Setup.lnk");}
 static void WriteShortcut(){
   try{
     string directory=Path.GetDirectoryName(ShortcutPath());Directory.CreateDirectory(directory);
     dynamic shell=Activator.CreateInstance(Type.GetTypeFromProgID("WScript.Shell"));
     dynamic link=shell.CreateShortcut(ShortcutPath());
     link.TargetPath=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),"System32","WindowsPowerShell","v1.0","powershell.exe");
     link.Arguments="-NoProfile -ExecutionPolicy Bypass -File \""+SetupScript()+"\"";
     link.WorkingDirectory=AppRoot;link.Description="Standivarius Doxa Setup";link.Save();
   }catch(Exception ex){Audit("Start menu shortcut unavailable: "+ex.GetType().Name);}
 }
 static void OpenApp(){
   Need(ValidApp(AppRoot),"Install the verified Doxa application first");
   string script=SetupScript();Need(File.Exists(script),"Doxa guided setup missing");
   var ps=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),"System32","WindowsPowerShell","v1.0","powershell.exe");
   Process.Start(new ProcessStartInfo(ps,"-NoProfile -ExecutionPolicy Bypass -File \""+script+"\""){UseShellExecute=false,CreateNoWindow=true,WorkingDirectory=AppRoot});
 } static string SelfTest(){
   Need(ValidDriver(),"Pinned driver file changed");
   var tmp=Path.Combine(Path.GetTempPath(),"DoxaCheck-"+Guid.NewGuid().ToString("N"));
   try{Extract(At("DoxaSetupPayload.zip"),tmp);return "PASS: driver fingerprint and clean application extraction; zero Windows changes";}
   finally{if(Directory.Exists(tmp))Directory.Delete(tmp,true);}
 }
 [STAThread] static int Main(string[] args){
   try{
     string a=args.Length>0?args[0].ToLowerInvariant():"";
     if(a=="/selftest"){Console.WriteLine(SelfTest());return 0;}
     if(a=="/detect"){var s=Status();Console.WriteLine(s);return s.StartsWith("AppInstalled")?0:1;}
     if(a=="/verify"){var s=Status();Console.WriteLine(s);return s.Contains("AppInstalled")&&s.Contains("DriverValid")?0:1;}
     if(a=="/install"){var s=Apply();Console.WriteLine(s);return s.Contains("restart required")?3010:0;}
     if(a=="/uninstall"){Console.WriteLine(Uninstall());return 0;}
     if(a=="/open"){OpenApp();return 0;}
     Application.EnableVisualStyles();
     var f=new Form{Text="Standivarius | Doxa Setup",ClientSize=new Size(645,360),MinimumSize=new Size(540,340),StartPosition=FormStartPosition.CenterScreen,BackColor=Color.White,Font=new Font("Segoe UI",11)};
     var title=new Label{Text="Doxa Setup",Font=new Font("Segoe UI",24,FontStyle.Bold),Location=new Point(26,18),Size=new Size(580,62)};
     var help=new Label{Text="Connect Doxa power and USB data to your computer.\nInstall the Windows display components, then arrange your screens.",Location=new Point(26,90),Size=new Size(590,65)};
     var status=new Label{Text=Status(),Location=new Point(26,165),Size=new Size(585,43)};
     var install=new Button{Text="Install / check Doxa",Location=new Point(26,240),Size=new Size(190,45)};
     var open=new Button{Text="Open Doxa setup",Location=new Point(230,240),Size=new Size(180,45)};
     var refresh=new Button{Text="Refresh",Location=new Point(424,240),Size=new Size(128,45)};
     install.Click+=(s,e)=>{try{
       if(!Admin()){
         using(var x=Process.Start(new ProcessStartInfo(System.Reflection.Assembly.GetExecutingAssembly().Location,"/install"){UseShellExecute=true,Verb="runas"})){x.WaitForExit();if(x.ExitCode!=0&&x.ExitCode!=3010)MessageBox.Show("Windows installation did not complete; check Doxa installer log.");}
       }else Apply();
       status.Text=Status();
       if(status.Text.Contains("AppInstalled"))OpenApp();
     }catch(Exception ex){MessageBox.Show(ex.Message,"Doxa Setup");}};
     open.Click+=(s,e)=>{try{OpenApp();}catch(Exception ex){MessageBox.Show(ex.Message,"Doxa Setup");}};
     refresh.Click+=(s,e)=>status.Text=Status();
     f.Controls.AddRange(new Control[]{title,help,status,install,open,refresh});
     Application.Run(f);return 0;
   }catch(Exception ex){Audit("Error "+ex.Message);Console.Error.WriteLine(ex.Message);if(Environment.UserInteractive && args.Length>0 && args[0]=="/install")MessageBox.Show(ex.Message,"Doxa Setup");return 30;}
 }
}
