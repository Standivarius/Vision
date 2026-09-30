$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class DisplayConfigProbe {
  public const uint QDC_ONLY_ACTIVE_PATHS=2, DISPLAYCONFIG_DEVICE_INFO_GET_SOURCE_NAME=1, DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_NAME=2;
  [StructLayout(LayoutKind.Sequential)] public struct LUID { public uint LowPart; public int HighPart; }
  [StructLayout(LayoutKind.Sequential)] public struct PATH_SOURCE { public LUID adapterId; public uint id; public uint modeInfoIdx; public uint statusFlags; }
  [StructLayout(LayoutKind.Sequential)] public struct PATH_TARGET { public LUID adapterId; public uint id; public uint modeInfoIdx; public uint outputTechnology; public uint rotation; public uint scaling; public uint refreshN; public uint refreshD; public uint scanLineOrdering; [MarshalAs(UnmanagedType.Bool)] public bool targetAvailable; public uint statusFlags; }
  [StructLayout(LayoutKind.Sequential)] public struct PATH { public PATH_SOURCE sourceInfo; public PATH_TARGET targetInfo; public uint flags; }
  [StructLayout(LayoutKind.Sequential)] public struct MODE { public uint infoType; public uint id; public LUID adapterId; [MarshalAs(UnmanagedType.ByValArray, SizeConst=64)] public byte[] data; }
  [StructLayout(LayoutKind.Sequential)] public struct HEADER { public uint type; public uint size; public LUID adapterId; public uint id; }
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] public struct SOURCE { public HEADER header; [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string viewGdiDeviceName; }
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] public struct TARGET { public HEADER header; public uint flags; public uint outputTechnology; public ushort edidManufactureId; public ushort edidProductCodeId; public uint connectorInstance; [MarshalAs(UnmanagedType.ByValTStr, SizeConst=64)] public string monitorFriendlyDeviceName; [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)] public string monitorDevicePath; }
  [DllImport("user32.dll")] public static extern int GetDisplayConfigBufferSizes(uint flags,out uint paths,out uint modes);
  [DllImport("user32.dll")] public static extern int QueryDisplayConfig(uint flags,ref uint paths,[Out] PATH[] pathArray,ref uint modes,[Out] MODE[] modeArray,IntPtr topology);
  [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int DisplayConfigGetDeviceInfo(ref SOURCE packet);
  [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int DisplayConfigGetDeviceInfo(ref TARGET packet);
}
"@
$pc=0; $mc=0
[void][DisplayConfigProbe]::GetDisplayConfigBufferSizes(2,[ref]$pc,[ref]$mc)
$paths=New-Object 'DisplayConfigProbe+PATH[]' $pc
$modes=New-Object 'DisplayConfigProbe+MODE[]' $mc
$r=[DisplayConfigProbe]::QueryDisplayConfig(2,[ref]$pc,$paths,[ref]$mc,$modes,[IntPtr]::Zero)
if($r -ne 0){throw "QueryDisplayConfig=$r"}
$result=@()
for($i=0;$i -lt $pc;$i++){
 $p=$paths[$i]
 $src=New-Object 'DisplayConfigProbe+SOURCE'
 $src.header.type=1; $src.header.size=[Runtime.InteropServices.Marshal]::SizeOf($src); $src.header.adapterId=$p.sourceInfo.adapterId; $src.header.id=$p.sourceInfo.id
 [void][DisplayConfigProbe]::DisplayConfigGetDeviceInfo([ref]$src)
 $tgt=New-Object 'DisplayConfigProbe+TARGET'
 $tgt.header.type=2; $tgt.header.size=[Runtime.InteropServices.Marshal]::SizeOf($tgt); $tgt.header.adapterId=$p.targetInfo.adapterId; $tgt.header.id=$p.targetInfo.id
 [void][DisplayConfigProbe]::DisplayConfigGetDeviceInfo([ref]$tgt)
 $result += [pscustomobject]@{source=$src.viewGdiDeviceName;source_id=$p.sourceInfo.id;target_id=$p.targetInfo.id;adapter_low=$p.targetInfo.adapterId.LowPart;adapter_high=$p.targetInfo.adapterId.HighPart;output_technology=$p.targetInfo.outputTechnology;connector_instance=$tgt.connectorInstance;friendly_name=$tgt.monitorFriendlyDeviceName;device_path=$tgt.monitorDevicePath;edid_manufacturer=$tgt.edidManufactureId;edid_product=$tgt.edidProductCodeId}
}
$result | ConvertTo-Json -Depth 4
