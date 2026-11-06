# Doxa full installer — Gemini 3.8 Flash (Antigravity) review and owner-side triage

**Independent reviewer:** Gemini 3.8 Flash High through authenticated Google Antigravity CLI on MARIUS-DELL. Review snapshot under `C:\mcp\vision-dev\state\reviews\doxa-gemini-flash-20261028`. The first headless run failed on a command permission; the second was constrained to built-in read-only file operations, produced a substantive review report, but hit its seven-minute execution limit. Preserve the output as **partial independent review**, not a complete acceptance sign-off. No reviewer made repository writes.

**Reviewer report:** `C:\mcp\vision-dev\state\reviews\doxa-gemini-flash-20261028\gemini-3.8-flash-review-2.md`.

## Findings and dispositions

| Reviewer finding | Decision | Action and evidence |
| --- | --- | --- |
| F-01 — first-time generic Microsoft USB driver classified as hostile | **Accept** | `ClassifyDriver` now distinguishes Microsoft/unbound USB from a foreign third-party binding. A healthy signed Silicon Motion driver remains protected. Local tests cover generic/unbound, signed trusted and foreign/unsigned cases. Physical new-driver installation still needs separate hardware evidence. |
| F-02 — modified installation bricks uninstall and reinstall | **Accept with safety correction** | Never delete an unknown or modified tree recursively. `RemoveAppFrom` now *atomically moves* modified app folder into a same-volume protected `DoxaRetained-...` folder, removes the live app install path, finishes Windows uninstall registration cleanup, and permits fresh installation. Non-app files remain preserved for administrator inspection. Test covers tamper, retention and reinstall. Reject Gemini's unconditional recursive-delete suggestion. |
| F-03 — Intune app detection flaps with USB hotplug | **Accept** | `/detect` now requires only intact installed application + Windows registration; `/verify` continues to verify USB/driver health. This prevents automated repeated MSI deployment triggered by monitor connection changes. |
| F-04 — small helper binary remains after interactive Programs & Features uninstall | **Defer safely** | Reject suggested detached `cmd.exe ping ... & rmdir /s /q` because it can delete non-owned files and introduces races. The running helper is retained for interactive uninstall; SYSTEM uninstall removes it directly. Crucially **no new delete-on-reboot is scheduled**, and maintenance exe path is versioned away from the old queued deletion. |
| F-05 — guided PowerShell setup may be blocked by corporate policy | **Partially accept** | Native host now checks quick subprocess failure and returns an actionable warning rather than silent no-op. Full WDAC/ConstrainedLanguage and enterprise PowerShell policy qualification remains a separate machine-policy acceptance gate. |
| F-06 — native EXEs unsigned | **External release step** | Publish-signer identity not available on Dell. Keep candidate private; provided post-signing package rebuild and PE-code-preservation checks. |
| F-07 — native bootstrap lacks Romanian toggle, keyboard metadata | **Accept** | Added English/Romanian toggle and explicit Tab order/accessibility names. Full physical high-DPI screen-reader acceptance not claimed. |
| F-08 — potentially slow WMI scan | **No speculative change** | Performance not measured and driver identity accuracy is security-critical; defer until a reproducible latency measurement warrants filtered query. |
| F-09 — Windows 10 excluded by Intune minimum release | **Keep current target** | Current managed qualification is Windows 11. Do not expand support to Windows 10 without an explicit support/test matrix. |
| F-10 — unused delayed-delete Win32 import | **Accept** | Removed stale `MoveFileEx` declaration from native host. |

## Testing policy

Use current `Test-DoxaNativeRelease.ps1`, `Test-DoxaReleaseConsistency.py` and the actual compiled `DoxaDeploy.exe /selftest`. These validate signed driver classification, stable software detection, tampered-file recovery and reinstall, no untrusted adjacent-payload override, immutable Intune-to-ManageEngine executable parity. Real Dell Intune test must be recorded separately for the **Gemini-corrected** exact package; do not transfer evidence from the older package to this one.

**Unresolved environment qualifications:** no clean physical driver-free Doxa test target, no active ManageEngine agent for the current package, and no publisher code-signing identity. This record does not certify those gates.

## Safety

No deletion/reinstall of Dell's working display driver, no display topology change, no reboot, no branch merge. Existing dirty master checkout and other worktrees preserved. Gemini review snapshot read-only; primary engineer retains implementation decisions.

## Updated real-agent evidence on corrected binaries

Following the Gemini fixes, a new standalone Windows binary and independent Intune/ManageEngine packages were rebuilt. The native fixture and encrypted package parity tests passed.

The corrected Doxa deployment executable was **published to a Dell-only Intune test application**. Dell's genuine Intune Management Extension downloaded and executed it under the system installation workflow. Logs report successful enforcement and detection, and read-only Windows inspection confirmed the protected maintenance executable, app directory and Apps & Features registration. The pre-existing signed display driver was unchanged. This is **real Intune install and detection PASS for the Gemini-corrected binary**.

After testing, a late-arriving assignment had installed the application while cleanup was in progress. A one-device **Uninstall** policy was therefore safely re-assigned to remove this exact application. At the last observation, the application remained installed and the agent had not yet executed that uninstall. **Do not claim corrected-binary Intune uninstall PASS until its agent log and post-removal Windows checks confirm it.** The earlier native build had a complete real install/uninstall PASS, but that evidence is not interchangeable.

Managed ManageEngine deployment of this corrected exact binary, a clean driver-free physical installation, and publisher signing remain unperformed. The source fixes and package are reviewable without overstating those acceptance gates.

## Final corrected-binary Intune lifecycle — verified complete

The Dell-only Intune Management Extension subsequently **completed the corrected-binary uninstall with success** and then reported the app **NotInstalled**. Independent Windows checks found no Doxa application directory, no v2 maintenance executable, and no Apps & Features Doxa uninstall entry. The existing SMI770 driver remained Microsoft hardware-signed and unchanged at version 4.7.6.8001. The corrected application's Dell-only Uninstall assignment was removed after that result was confirmed, leaving **no active test assignment**. This upgrades the precise corrected-binary Intune lifecycle to **real install, detection, uninstall and post-uninstall detection PASS**.

The ManageEngine exact-binary cloud agent qualification, clean first-time driver installation on a recoverable device, and publisher signing remain separate open acceptance gates. No claim of production release is made.
