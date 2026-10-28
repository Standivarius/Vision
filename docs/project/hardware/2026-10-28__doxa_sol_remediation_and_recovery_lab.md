# Doxa installer — Sol corrective implementation and recovery-lab design

**Date:** 28 October 2026
**Repo:** Standivarius/Vision
**Branch:** `doxa/review-package-20261028` in isolated worktree; untouched canonical dirty checkout `C:\dev\Vision`.

## Corrective changes

The native Windows host now presents an explicit local diagnostic-consent checkbox before calling WMI, USB or driver detection. No automatic device census runs when the original customer window opens. Its installation action is disabled until the operator chooses to allow local read-only checks. The separate guided-setup consent is preserved.

Native installation runs through a background worker so the initial window can remain responsive during UAC/MSI work. MSI has a bounded 10-minute wait. If it remains running beyond the bound, the original extracted staging is preserved (the installer does **not** forcibly terminate MSI) and the user is told to consult the installer log before retrying. Successful MSI with delayed driver binding can return an explicit *pending* state after 60 seconds; the application can still register but hardware `/verify` does not assert success.

Windows architecture/build policy is now evaluated before driver installation or a healthy-driver early return, using `Win32_OperatingSystem.BuildNumber`. The previously malformed Windows repair registration is corrected and tested with an exact quoting assertion.

The existing `/detect` command stays software-only and stable across USB hotplug. The existing `/verify` remains the app + USB + original trusted-driver check. A distinct `/verify-panels` command now checks three Windows PnP identities, `Generic Monitor (L)`, `Generic Monitor (T)`, and `Generic Monitor (R)`. This does **not** prove independent Windows Extend mode or actual physical layout; user-session physical acceptance remains separate.

Signed finalization now keeps the source commit, native source/build-script hashes and embedded application/vendor MSI hashes from the reviewed candidate. Its file inventory uses the same `path` field as the independent package checker. A no-signing source-contract test checks those fields. Actual signed publisher and endpoint deployment tests remain pending.

The guided application improves Romanian labels and accessible descriptions for its driver and display-settings actions.

## Recovery lab — what it does

A dedicated, default-off **Recovery lab** entry is in the Doxa Help pane. It is visible only when the launching user or test harness provides the `DOXA_RECOVERY_LAB_SHA256` environment variable containing a 64-character SHA-256 digest of a local test passphrase. No passphrase or fixed secret is embedded in the commercial installer. The UI asks the operator for the passphrase in a masked input and compares its hash locally; the passphrase is never transmitted or logged.

Unlocking injects the existing **clearly labeled in-memory `display_missing` diagnostic fixture**. It does not call display-configuration APIs, Device Manager, PnP disable, registry manipulation or driver removal. A second click or a regular Detect Doxa action returns to the actual state. A fixture-backed recovery exercise is not proof of a physical display malfunction.

When online AI has been separately permitted in the current session and is not prohibited by IT policy, the unlocked lab can send a question that explicitly identifies the scenario as **simulated** and requests safe recovery steps. The original AI client remains read-only: it can advise but cannot execute commands or change the display. The local unlock code stays in the user's PC/session and is not included in the AI question. With online AI declined, local curated assistance remains available.

A self-test proves default-off, correct/wrong local code handling, and no device mutation. The embedded customer ZIP test now verifies that the lab helper is included and passes its tests.

### Operator setup for the simulated recovery test

For a local, attended developer test, in PowerShell:

```powershell
$secret = Read-Host 'Choose recovery lab code (minimum 10 characters)' -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
try {
  $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $env:DOXA_RECOVERY_LAB_SHA256 = ([BitConverter]::ToString(
      $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($plain))
    )).Replace('-', '')
  } finally { $sha.Dispose() }
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  Remove-Variable plain -ErrorAction SilentlyContinue
}
# Launch the Doxa guided setup in this SAME PowerShell session.
& 'C:\wt\doxa-review-package-20261028\app\packaging\doxa-setup\personal-ui\Start-DoxaGuidedSetup.ps1'
Remove-Item Env:DOXA_RECOVERY_LAB_SHA256 -ErrorAction SilentlyContinue
```

After accepting the guided local-diagnostics consent, choose the **Recovery lab** link in Doxa Help, enter the code, and ask the AI how it would recover a missing panel. Always end the lab when done. No live monitor is disabled by these steps.

### Real monitor-disable experiment (not enabled in this iteration)

An attended physical test needs a **separate operator-owned rollback watchdog**, independent of the installer and cloud AI. Before allowing a single display to be temporarily removed from the active topology, establish the exact Windows display path and panel identity, confirm an accessible internal laptop display, snapshot the current topology and monitor arrangement, verify the rollback/watchdog can restore it on its own, impose a short expiration and prevent persistent changes, monitor the physical console session, and test recovery from unexpected process termination. A password alone is **not** enough. Never expose a general-purpose Windows shell, Device Manager, driver-uninstall or display-configuration tool to the cloud model. Keep this gated test separate from the retail and unattended enterprise packages.

## Test and release boundaries

No device/driver, monitor layout, Intune/ManageEngine assignment, restart, or publisher-signing activity was performed by these code changes. Do not publish unsigned review executables or claim driver-free physical first install, unattended disconnected MSI behavior, four independently extended Doxa screens, or real signed packaging acceptance without separate evidence. The isolated worktree and PR remain draft.
