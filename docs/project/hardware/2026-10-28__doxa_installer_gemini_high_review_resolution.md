# Doxa Windows installation — independent Gemini Flash High review and resolution

28 October 2026. Vision repository on MARIUS-DELL; isolated development branch `doxa/review-package-20261028`. The working master checkout was preserved.

## Purpose and interfaces

Standivarius Doxa is a triple-screen Windows accessory. The release candidate consists of a normal one-file WinForms installer `DoxaSetup.exe` for end users and the silent `DoxaDeploy.exe` for endpoint management, with an Intune Win32 package and a ManageEngine deployment ZIP derived from the exact same native executable logic. The signed vendor display driver MSI and bilingual guided application are embedded. End users expect straightforward connection, Windows consent, setup, repair and removal. IT deployment is designed for SYSTEM-mode unattended operation without automatic reboot.

## Independent model review

A **completely new** Antigravity Gemini 3.8 Flash High session was started. It received neutral product objectives, current implementation and evidence, known external qualification limits, and the native C# host source. It did **not** receive the prior medium-review findings or a list of things to investigate. Review was read-only with no computer modifications. The model produced a substantive technical report and a release verdict of **not ready for public distribution**.

The report is preserved at `docs/project/hardware/2026-10-28__doxa_installer_gemini_high_raw_review.md`; the original Antigravity output is retained separately in the read-only review snapshot under `C:\mcp\vision-dev\state\reviews\doxa-full-installer-independent-high-20261028`.

## Engineering decisions

| Model finding | Disposition | Implemented or reason |
| --- | --- | --- |
| Disconnected enterprise deployment skips vendor display driver | **Accepted** | SYSTEM and ordinary installations run the pinned MSI even if Doxa is not plugged in. The disconnected state now records an MSI success result without pretending that hardware binding was physically observed. Existing healthy signed driver remains a no-op. |
| PnP installation and binding may complete asynchronously | **Accepted** | When Doxa is connected, wait and recheck trusted WHQL-signed driver binding for a bounded interval rather than testing only immediately after the MSI exits. No automatic reboot. |
| Different normalized legitimate vendor names | **Accepted with strict trust** | Normalize whitespace/punctuation in provider name while continuing to require an exact trusted Microsoft hardware-compatibility signer. Unknown providers or unsigned bindings still block replacement. |
| Corporate PowerShell restrictions | **Partially addressed, external qualification** | Native host reports early script-start failure in a visible customer dialog (no dialog in SYSTEM session). Full WDAC/AppLocker and signed scripted UI qualification remains; PowerShell policy bypass cannot override those controls. |
| Start-menu /open errors hidden in a GUI app | **Accepted** | User-session startup exceptions now show a Windows warning dialog. |
| No explicit Registry64 handling | **Accepted for predictability** | All registration read/write/delete and cleanup checks use the 64-bit registry view even if a management invocation originates from a 32-bit process. |
| No repair action despite user expectations | **Accepted** | Added explicit /repair route with the same protected recovery behaviour as install, Windows elevation for end users, and Windows application maintenance registration. Modified application folders are retained, not destroyed. |
| Language and initial UI status | **Accepted** | Romanian/English language choice now updates accessible button descriptions. The initial hardware status is retrieved after the window appears, asynchronously to avoid freezing the UI. |
| Exact manifest counts and strict file integrity | **Retained deliberately** | The installed application is intended to be immutable. Unknown or changed files fail integrity and are retained for administrator inspection on repair/uninstall. Logs are written outside the application folder. Loosening this would permit unexpected code execution in the privileged setup path. |
| Missing helper script suggested by model | **Evidence scope limitation** | The standalone package builder verifies the embedded guided application's manifest and checksums; direct manual inspection of every helper was not part of the model's review. |
| Hardware and external signing/management rollout | **Not yet fulfilled here** | Genuine driver-first deployment on recoverable driver-free hardware, exact-binary ManageEngine agent deployment, publisher signing and restrictive-corporate-policy acceptance remain separate qualifications. |

## Tests and observations

After integrating review feedback, the current native customer and managed Windows binaries were recompiled. Tests exercised their embedded payload, repeat installation, modified folder retention, repair/reinstall fixture, hardware detection, unknown command rejection, and Windows application state checks. Independently decrypted Intune package content was compared with the ManageEngine executable and matched byte-for-byte. The personal setup executable's own `/selftest` completed without touching the working signed Dell driver.

The same previously installed signed driver stayed on Dell. No Windows display topology changes, physical driver removal or forced reboot were attempted.

The exact revised package was separately published as a **Dell-only Microsoft Intune** test application. Endpoint-agent installation and removal results must be recorded from actual Windows agent logs and installed state, not inferred from publishing or assignment. Final evidence is stored alongside the release candidate.

## Release boundary

**Private engineering candidate, not a public signed installer.** Keep the GitHub pull request in draft until publisher signing and relevant environment qualifications have been completed. Do not attribute unperformed physical hardware or ManagedEngine agent tests to the independently reviewed source.

## Exact post-review build on Dell

The exact native binaries in `artifacts/releases/gemini-high-fix-build-20261028` passed the standalone executable fixture and personal EXE `/selftest`. The Intune encrypted package was independently decrypted and verified to match the ManageEngine EXE byte-for-byte. This very build then passed real Dell-only Intune SYSTEM installation and app detection; Windows registered the app and native hardware verification returned success while the pre-existing signed display driver remained unchanged.

A one-device Intune Uninstall assignment has been issued to close the qualification. Its result must be confirmed from agent logs and Windows app/registry state rather than assumed from the assignment. Earlier build variants passed uninstall, but their evidence is not automatically transferable. The unsigned user EXE remains an engineering candidate pending publisher signing and the physical driver-free/ManageEngine/enterprise policy tests noted above.
