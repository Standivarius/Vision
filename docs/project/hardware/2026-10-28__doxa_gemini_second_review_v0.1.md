# Doxa full Windows installer â€” fresh Gemini re-review

Date: 28 October 2026. Vision project. Source branch: doxa/review-package-20261028.
Second reviewer: **new Google Antigravity CLI session, Gemini 3.8 Flash Medium**. New session, no continuation of earlier review. A short connection test succeeded. This substantive response was produced directly from the exact native source correction diff, without file tools or delegation. The much larger full-source High run timed out with no review. The successful focused second review was checked against the source.

## Primary integrator verification

**Confirmed fixed in committed C# source**:
- F01: Generic Microsoft or unconfigured driver treated as first-use state, not a hostile display driver (ClassifyDriver).
- F02: Modified app folder atomically retained rather than recursively deleted; install path freed (RemoveAppFrom). File locks could still prevent renaming; handle this in later work.
- F03: Managed app detection now requires the application files and Windows registration; driver/USB health is separate (DetectDecision).

**Confirmed still incomplete or absent in committed C# source**:
- F04: delayed delete on reboot no longer issued, but Windows Settings interactive uninstall leaves its executing maintenance EXE behind.
- F05: Open() still starts hidden PowerShell with ExecutionPolicy Bypass, does not wait for early errors or report the exit result. Enterprise policy can block startup.
- F07: native UI() bootstrap remains English-only and has no explicit accessibility/tab labels. Guided PowerShell setup is a separate bilingual interface, not a substitute for the entry window.
- F10: unused MoveFileEx P/Invoke is still declared.
- Upgrade: IsRegistered() requires the *new* maintenance executable and exact UninstallString. Existing older full-installer registrations can fail the new /detect until migrated. Prior test endpoint installs were removed; that does not certify an upgrade path.
- Potential recovery gap: Directory.Move(root,retained) can fail on file locks; no fallback path is in the corrected source.

**Decision:** second review does NOT accept the full Windows installer as complete. Fix the confirmed code gaps and test upgrades and the interactive uninstall before any release claim. Keep unknown files safe; do not adopt a blanket recursive-delete or detached forced directory deletion. Existing external acceptance gates remain separate: public publisher signing, recoverable clean-driver machine, and genuine ManageEngine agent test of this binary.

This review made **no code changes**, no display driver changes, and did not authorize PR merge or public release.

## Gemini's independent response (trailing whitespace normalized)

### Item Verdicts (F01â€“F10)

* **F01 (Microsoft/unconfigured USB driver rejected): FIXED.**
  `ClassifyDriver` explicitly treats empty, `"Microsoft"`, and `"Microsoft Windows"` provider strings as state `0` (clean/unbound display state) rather than untrusted third-party drivers (state `2`), enabling first-install staging.
* **F02 (Altered app bricks uninstall/reinstall): FIXED.**
  `RemoveAppFrom` no longer throws `InvalidOperationException` on modified directories. It verifies the folder is not a reparse point and atomically moves modified content aside to `DoxaRetained-{Guid}` on the same volume, freeing `AppRoot` for clean reinstallation.
* **F03 (/detect flaps with Doxa hotplug): FIXED.**
  `DetectDecision` signature and implementation were decoupled from `PresentUsb()` and `DriverState()`, checking only `IsValidApp` and `IsRegistered`. Hardware hotplug no longer flaps endpoint management compliance.
* **F04 (Delete-on-reboot race & orphan maintenance helper): PARTIAL.**
  Removing `MoveFileEx(..., 4)` resolves reboot-deletion collisions with fresh installs. However, during interactive uninstall via Windows Settings/ARP (`SourceExe == MaintenanceExe`), `File.Delete(MaintenanceExe)` is bypassed. Because running executables cannot delete themselves and no out-of-process self-destruct was added, `DoxaMaintenance-v2.exe` and its directory remain orphaned indefinitely.
* **F05 (PowerShell corporate-policy failures hidden): NOT FIXED.**
  Zero changes to PowerShell execution policies (`-ExecutionPolicy Bypass`), process execution wrappers, or script failure logging exist in the diff.
* **F07 (English-only native form): NOT FIXED.**
  No UI resource bundles, localization strings, or culture-aware UI handling were introduced.
* **F10 (Unused delayed deletion P/Invoke): NOT FIXED / PARTIAL.**
  The call site `MoveFileEx(MaintenanceExe, null, 4)` was deleted, but the underlying native P/Invoke declaration was retained in the source file as dead code.

---

### Remaining P0 / P1 Software Defects

1. **[P1] Upgrade Detection Broken by Hardcoded Path Drift:**
   `MaintenanceExe` was renamed to `DoxaMaintenance-v2.exe`. Line 104 strictly requires `UninstallString == "\"" + MaintenanceExe + "\" /uninstall"`. Any pre-existing machine installed with `DoxaMaintenance.exe` will fail `IsRegistered()`, immediately causing `/detect` to return `false` on previously healthy endpoints.
2. **[P1] Unhandled `IOException` on File Locks During Quarantine:**
   `Directory.Move(root, retained)` in `RemoveAppFrom` is not wrapped in exception handling. If any file in `AppRoot` is locked (running process, security scanner, or open log file), `Directory.Move` throws `IOException`, aborting the uninstall transaction before registry keys and shortcuts are removed.
3. **[P1] Interactive Uninstall Leaks Orphaned Program Files:**
   When uninstalled via `Apps & Features`, `SourceExe.Equals(MaintenanceExe)` prevents self-deletion. No detached transient process (`cmd.exe /c timeout ... & rmdir`) cleans `MaintenanceRoot`, permanently leaving stale binaries and logs on disk.

---

### Unsafe Advice Rejected

* **Unconditional Recursive Deletion of Altered Folders:**
  Rejecting any recommendation to revert to `Directory.Delete(root, true)` on unrecognized directories. Arbitrarily deleting modified files inside `Program Files` risks destroying third-party data or following symlinks/junctions introduced by local non-admin tampering. Renaming/retaining outside the operational path is the safer deployment approach.

---

### Second-Review Verdict

**REJECT FOR PRODUCTION (DO NOT RELEASE).**
While core driver classification, detection flapping, and modified-directory blocking are addressed, the hardcoded `UninstallString` change breaks detection compatibility for existing installations, interactive uninstalls leave permanent filesystem residue, and mandatory release gates (code-signing certificates, driver-free hardware validation, live ManageEngine deployment) remain unmet.
