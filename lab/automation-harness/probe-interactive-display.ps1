$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
$s=[System.Windows.Forms.Screen]::AllScreens
$out=@("session=$([System.Diagnostics.Process]::GetCurrentProcess().SessionId)","count=$($s.Count)")
foreach($x in $s){$out += ("device={0};primary={1};x={2};y={3};w={4};h={5}" -f $x.DeviceName,$x.Primary,$x.Bounds.X,$x.Bounds.Y,$x.Bounds.Width,$x.Bounds.Height)}
$out|Set-Content -Encoding ascii 'C:\dev\Visual\artifacts\interactive_display_probe.txt'
