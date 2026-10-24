# Doxa setup surrogate

This directory is deliberately small. It is not a second installer framework.

Until production Doxa hardware is available, the current two-monitor Visual build is the surrogate Doxa software platform:

- Velopack owns packaging/update layout and can produce a per-machine enterprise MSI;
- `visual_diagnostics.exe` supplies structured machine/display evidence;
- `visual_app.exe --health-check` exercises the real WGC/D3D capture-and-present path in the interactive user session;
- `run-surrogate.ps1` combines diagnostics, health, deterministic setup decisions and optional Muse exception planning;
- `support-bundle.ps1` is used automatically when an ambiguous failure occurs while cloud planning is unavailable;
- Muse can select only the read-only diagnostic/escalation actions in `approved-actions.json`.

Run the live two-monitor surrogate:

```powershell
.\app\packaging\doxa-setup\run-surrogate.ps1 -Configuration Release
```

The runner honors a real Windows pending-reboot state. For synthetic walkthroughs, a small JSON `-StateOverride` may override individual state fields without changing the diagnostic executable.

Run the repeatable smoke suite:

```powershell
.\app\packaging\doxa-setup\smoke.ps1 -Configuration Release
```

Include the cloud exception-planner path:

```powershell
.\app\packaging\doxa-setup\smoke.ps1 -Configuration Release -UseMuse
```

The smoke suite validates the live two-monitor health path, a future missing-display state, offline support-bundle fallback and, when requested, an allowlisted Muse decision followed by the real local diagnostic action.

`simulate.ps1` remains the scenario-level decision test. Existing scenario JSON files cover managed deployment, restricted users, App Control, missing display, driver remediation, ambiguous failure, cloud blockage and pending reboot. `expected_display_count` is optional and defaults to two; future Doxa profiles can set the real count without changing the decision logic.

The direct Meta call exists only for repository simulation. A production Doxa client must call a Doxa-owned HTTPS service, which can in turn call Dify/Muse. No model-provider key belongs in the client package.

## Real Doxa / SMI770 connected-device work, 16 October 2026

A real connected Doxa device has been observed on MARIUS-DELL: `SMI770 USB Display`, hardware ID prefix `USB\VID_090C&PID_770A`, installed WHCP-signed SiliconMotion driver **4.7.6.0** (`oem101.inf`), and three physical Doxa monitor devices named L/T/R. Windows currently has display **3|4 duplicated** (two monitors sharing a source); four independent extended desktop sources are not yet qualified.

New **read-only** driver/hardware diagnostic:

```powershell
& .\app\packaging\doxa-setup\Get-DoxaDriverState.ps1
& .\app\packaging\doxa-setup\Deploy-DoxaDriverPackage.ps1
& .\app\packaging\doxa-setup\tests\Test-DoxaDriverReadOnly.ps1
```

The deployment script is **audit-only by default** and is **not** the existing surrogate runner. Privileged vendor MSI installation is gated behind an explicit `-Apply`, local vendor MSI, **approved** pin of the MSI SHA256 and signing-certificate thumbprint and target driver, expected Doxa hardware profile, IT administrator/SYSTEM rights and an existing IT-controlled log directory. The accompanying manifest is intentionally `NOT_APPROVED`. No new kernel driver is authored and no vendor package is copied into the repository.

Before enabling a real deployment, inspect the supplier's published signed **SM77x Windows driver MSI**, confirm OEM redistribution/licensing, full version/build/HVCI support, signing, silent install, rollback, Intune/ConfigMgr detection and four independent monitor target paths. Do not disable endpoint policies or force a restart. See `docs/project/hardware/2026-10-16__doxa_real_smi770_enterprise_driver_baseline_v0.1.md`.

The existing `run-surrogate.ps1` and simulator remain unchanged; the present real-device detector **must not be interpreted as proof the production hardware installer is complete**.

## Current four-desktop qualification, 16 October 2026

A **later read-only Windows desktop-source check** supersedes the earlier duplicated 3|4 observation above: four independent Windows sources are active (`DISPLAY1/10/11/12`), with three Doxa PnP panels and the laptop monitor. `Get-DoxaDriverState.ps1` now separately reports active Windows sources and physical monitors; fixture mode never claims live desktop verification. Six read-only tests pass. This is **G1 observed hardware/desktop readiness only**. The vendor driver MSI deployment manifest is still deliberately `NOT_APPROVED`; no reinstall, update or production/enterprise deployment test was performed. See `docs/project/hardware/2026-10-16__doxa_four_independent_windows_desktops_qualification_v0.1.md`.
