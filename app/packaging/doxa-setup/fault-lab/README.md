# Standivarius Doxa Fault Lab

A basic local Windows utility for intentionally causing Doxa setup faults and checking the Doxa AI Help recovery guidance. It is NOT bundled in the customer installer and does not give the cloud AI permission to execute Windows commands.

## Launch the little app

Open Windows PowerShell under the signed-in Windows user (no administrator elevation needed for the display-config experiment):

~~~powershell
$lab = 'C:\wt\doxa-review-package-20261028\app\packaging\doxa-setup\fault-lab\Invoke-DoxaFaultLab.ps1'
& $lab -Gui
~~~

The window lists external displays, lets you **Check only**, and lets you **Temporarily disable selected screen** after two physical checks and a Yes/No confirmation. It starts a separate watchdog process to revert the exact saved display topology after 15–90 seconds (45 by default). The laptop screen is excluded.

During the test, open Doxa Setup, run **Detect Doxa**, and ask the online Doxa assistant why a screen is missing and how to recover it. Depending on Windows behavior, its PnP identity may still exist although the screen is no longer an active extended desktop.

## Powershell commands

~~~powershell
$lab = 'C:\wt\doxa-review-package-20261028\app\packaging\doxa-setup\fault-lab\Invoke-DoxaFaultLab.ps1'

& $lab -Catalog    # Eight intentional failure scenarios and their recovery steps
& $lab -List       # Current Windows display names; read only
& $lab -SelfTest   # Primary protection, three external dry runs, five simulations

# Read-only dry run (replace display with a name from -List):
& $lab -Scenario one-screen-temporary -Display '\\.\DISPLAY31'

# REAL intervention, for an operator at the Dell keyboard.
# First physically confirm the laptop screen is independently usable.
$target = '\\.\DISPLAY31'
& $lab -Scenario one-screen-temporary -Display $target -Seconds 45 -Execute -OwnerAtKeyboard -LaptopScreenUsable -ConfirmDisplay $target

# The successful trial prints a RESTORE_BACKUP path and manual restore command.
# Automatic restore runs in a SEPARATE watchdog process.
~~~

Use the exact display name returned by -List. Do NOT assume DISPLAY31 is always the left Doxa screen after reconnection.

The native display helper queries Windows with QueryDisplayConfig, validates the path removal with SetDisplayConfig SDC_VALIDATE, and applies a **temporary**, unsaved display topology. It does NOT call Disable-PnpDevice, remove a display adapter or driver, persist the changed arrangement, or reboot. The selected external screen is intentionally removed from the active Windows desktop. Windows may move open windows or flicker. The primary/integrated laptop panel is protected.

The watchdog saves the full original active display path and mode arrays in LOCALAPPDATA\Standivarius\DoxaFaultLab\runs. On expiry, it replays that snapshot; if this fails, it requests the last saved Windows display topology. Manual recovery: use the printed Restore command, Windows+P > Extend, or Settings > System > Display. Watchdog restoration is best-effort: OS/driver crashes or killing the watchdog may prevent it, so stay at the laptop and keep its internal screen available.

## Simulated failures, without Windows changes

~~~powershell
& $lab -Scenario screen-missing-simulation
& $lab -Scenario driver-missing-simulation
& $lab -Scenario blocked-policy-simulation
& $lab -Scenario package-mismatch-simulation
& $lab -Scenario assistant-unavailable-simulation
~~~

These reuse the existing Doxa diagnostic fixture API, clearly label test data, and never affect the actual driver or monitors. In the customer Doxa Help pane, the pre-existing code-unlocked Recovery lab allows an explicitly simulated missing-screen chat with optional online AI consent.

Other manual catalog entries: unplug **only Doxa USB-C data**, leave power connected, then reconnect; and turn off the online AI radio button to test offline fallback. Neither modifies the signed Silicon Motion driver.

## Safety and evidence

- Run real tests at the local console only; not over RDP, as SYSTEM, or unattended.
- Test just one external screen per trial. Do not change the driver or remove the USB display adapter.
- Require independent, physically usable built-in laptop display; terminate unsaved work.
- The native helper automatically rejects the primary screen, known integrated output technologies, cloned/ambiguous source paths, unsupported topologies and unknown display names.
- The initial build exercised only read-only screen enumeration, Windows SDC_VALIDATE for all three external paths, primary rejection, snapshot serialize/deserialize, and five simulated faults. **No physical monitor was disabled as part of implementation or tests.**
- The AI only diagnoses/advises. The test harness performs the reversible fault and the watchdog performs restoration; no general shell access is exposed to the AI.

Reference: https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setdisplayconfig and https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-querydisplayconfig .
