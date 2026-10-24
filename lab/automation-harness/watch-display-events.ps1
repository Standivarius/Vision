param(
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [Parameter(Mandatory=$true)][string]$StopFile
)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms

Add-Type -ReferencedAssemblies System.Windows.Forms -TypeDefinition @"
using System;
using System.IO;
using System.Diagnostics;
using System.Text;
using System.Windows.Forms;

public sealed class VisionDisplayEventWatcherForm : Form {
    private readonly string outputPath;
    private readonly string stopFile;
    private readonly Timer timer;

    public VisionDisplayEventWatcherForm(string outputPath, string stopFile) {
        this.outputPath = outputPath;
        this.stopFile = stopFile;
        ShowInTaskbar = false;
        FormBorderStyle = FormBorderStyle.FixedToolWindow;
        StartPosition = FormStartPosition.Manual;
        Left = -32000;
        Top = -32000;
        Width = 1;
        Height = 1;
        Opacity = 0.0;

        timer = new Timer();
        timer.Interval = 100;
        timer.Tick += (s,e) => {
            if (File.Exists(this.stopFile)) {
                Log("stop_file", 0, 0, 0);
                timer.Stop();
                Close();
            }
        };
        timer.Start();
    }

    protected override void OnHandleCreated(EventArgs e) {
        base.OnHandleCreated(e);
        Log("watcher_started", 0, 0, 0);
    }

    protected override void WndProc(ref Message m) {
        switch (m.Msg) {
            case 0x007E: Log("WM_DISPLAYCHANGE", m.Msg, m.WParam.ToInt64(), m.LParam.ToInt64()); break;
            case 0x0219: Log("WM_DEVICECHANGE", m.Msg, m.WParam.ToInt64(), m.LParam.ToInt64()); break;
            case 0x001A: Log("WM_SETTINGCHANGE", m.Msg, m.WParam.ToInt64(), m.LParam.ToInt64()); break;
            case 0x0218: Log("WM_POWERBROADCAST", m.Msg, m.WParam.ToInt64(), m.LParam.ToInt64()); break;
            case 0x02E0: Log("WM_DPICHANGED", m.Msg, m.WParam.ToInt64(), m.LParam.ToInt64()); break;
        }
        base.WndProc(ref m);
    }

    private void Log(string name, int msg, long wParam, long lParam) {
        var now = DateTimeOffset.Now;
        var line = string.Format(
            "{{\"time\":\"{0:o}\",\"ticks\":{1},\"event\":\"{2}\",\"msg\":{3},\"wparam\":{4},\"lparam\":{5}}}",
            now, Stopwatch.GetTimestamp(), name, msg, wParam, lParam);
        File.AppendAllText(outputPath, line + Environment.NewLine, Encoding.UTF8);
    }
}
"@

$form=[VisionDisplayEventWatcherForm]::new($OutputPath,$StopFile)
[System.Windows.Forms.Application]::Run($form)
