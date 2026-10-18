# Vision Dell unattended console recovery â€” owner-approved 2026-10-18

Status: Vision bridge watcher installed and independently verified; physical-console recovery installer corrected but privileged task not yet installed; its registration still requires one-time admin UAC
because an ordinary user context cannot transfer a disconnected Remote Desktop
session back to the physical display console (tscon Access denied, code 5).

## What this solves

Microsoft RDP presents a virtual display and may disconnect the four-screen
Doxa physical console. After RDP disconnect, Vision sees a virtual WinDisc
screen and a disconnected Windows session rather than actual Left/Centre/Right.

The recovery task runs once each minute as SYSTEM **only to**:

1. restart the existing Vision OpenAI tunnel keepalive if its task stopped,
   without disturbing the separate ProjectDevDell tunnel;
2. identify one disconnected Windows session owned by local account DELL;
3. if no interactive RDP or another active console session exists, use built-in
   tscon.exe to hand that session back to the physical console.

The recovery script has no parameters accepting external commands, and lives in
ProgramData with a protected ACL: SYSTEM/Administrators full control; Users
read-only. The privileged task never executes the mutable Git repository file.

**Security trade-off:** Transferring an already signed-in session may leave
the physical Dell desktop accessible, and is permitted here by the owner.
The task does not record a password, implement autologon, disable Windows
authentication or modify UAC, Defender, sleep, screensaver or lock policies.
If Windows is genuinely locked by the user or has rebooted to sign-in, it
cannot unlock it or create a new authenticated session. Such a case remains
blocked rather than bypassed.

## One-time command â€” only if the recovery task is not yet installed

From a regular PowerShell on Dell (a remote RDP session is fine), paste one line:

    Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File "C:\dev\Vision\scripts\vision-unattended\Install-VisionUnattendedConsole.ps1"'

Approve the one UAC prompt. The installer creates the task, installs the
hardened script, checks the protected ACL, and if currently in active RDP
transfers you back to the physical console. Remote Desktop may disconnect.
After this single installation, *future* disconnected RDP sessions are
recovered automatically within about a minute. No future manual tscon.

Installer is idempotent. No reboot. No driver or Windows policy changes.
There is no need to install Gemini or use a second coding agent.

## Verify / troubleshoot (assistant can perform)

- Vision bridge health: project_start("vision"), vision_health().
- Read-only task: Get-ScheduledTask -TaskName VisionConsoleRecovery.
- Read-only log: C:\ProgramData\StandivariusVisionConsoleRecovery\console-recovery.log
- Read-only session preflight: scripts\vision-unattended\Recover-VisionConsole.ps1 -Probe
- Pure policy checks: scripts\vision-unattended\Test-VisionConsoleRecovery.ps1.
- Doxa monitor source: app\build\Release\visual_diagnostics.exe.
- Assessment preflight: lab\pocs\doxa\assessment\win_observer.py --preflight.
- POC A live real-use scenario is still qualified separately. A four-monitor
  count and an unlocked desktop alone do not make a behavioural PASS.

Recovery will **not** operate while someone is actively using RDP, and will not
choose among multiple disconnected owner sessions or take over another user's
active physical session. Those cases log/return without a transfer.

## Rollback if wanted

Run the same installer elevated with -Uninstall:
Unregisters only VisionConsoleRecovery, preserving logs for inspection.
Other existing tasks and the user's RDP access are unchanged.

## Test evidence

2026-10-18: 4/4 physical monitors returned after manual tscon from elevated
RDP; physical console active/unlocked; independent live auto-focus run logged
LEFT start and RIGHT auto-follow request+dispatch, then timed out before full
LEFT return/recovery. Do NOT claim full POC A pass. Isolated scorer 22/22 unit
checks had passed. Pure recovery mock policy: 6/6 checks pass, including
no interruption of active RDP and no ambiguous-session takeover. SYSTEM task
registration and genuine future disconnect/recovery are unverified until
the one-time elevated install and subsequent end-to-end reattach test.


## Actual installation status — 2026-10-18

Installed locally without elevation: Task Scheduler task VisionBridgeRecoveryUser, user DELL, limited runlevel, once-per-minute indefinite repetition. Script: scripts/vision-unattended/Keep-VisionBridgeOnline.ps1. Verified a completed scheduled run returned LastTaskResult 0, and the existing VisionOpenAITunnelKeepalive is Running. It never touches the separate ProjectDevDell tunnel. The existing four-screen console is available.

Not yet installed: VisionConsoleRecovery SYSTEM task. An earlier elevated installer execution created the ACL-protected ProgramData directory and script but did not register the SYSTEM task. The installer has since been made idempotent, adds step-level error logging to ProgramData/install-report.log, validates its probe exit code and Task Scheduler principal, uses indefinite repetition, and includes schtasks.exe registration fallback. No non-elevated API was found that may legitimately register a SYSTEM task; current Windows UAC requires user consent (ConsentPromptBehaviorAdmin=5). Do not claim automatic RDP console transfer is functioning until the task is registered and its actual transfer tested.

Physical Doxa startup test: 4 monitors, physical console, unlocked, and the existing POC controller SmokeTest PASS. The attended automatic-focus test still has a UI Automation locator issue. The older earlier run logged RIGHT switch, but not the full return-and-shutdown pass. The experimental alternative test runner was not promoted.