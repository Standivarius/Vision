# Doxa Setup preview.8 ? owner UX corrections

Date 2026-10-27. Technical tracking: GitHub #98 (UX), #99 (full physical installation); overall installer definition #75.

## Implemented in private preview.8

- Customer-facing button is exactly **Detect Doxa** (Romanian: Detecteaza Doxa). Connection result and offline FAQ have consistent terminology.
- After the preview.9 continuation, permissions, connection choice and main setup share one WinForms window/handle. This is a same-window navigation enhancement, not a driver installation.
- Main window adapts to height as well as width, including actual Dell 1280x720 logical screen; resizable with scrolling as fallback. Critical buttons/footer fit on real laptop work area.
- Welcome offers **What does this local check read?**, separate from optional cloud AI privacy. The packaged notice describes specific Windows/USB/display/driver data, storage and transfer limits.
- **Set up screens...** opens a resizable, two-tab illustrated offline guide with explicit power/USB-C data, Windows Extend / Identify / Apply, Windows Display Settings link (ms-settings:display), recommended four-screen diagram (laptop 1, Doxa 2/3/4 left to right) and recommended/custom choices.
- Screen labels in illustration are Doxa labels; they do not claim to alter Windows-assigned monitor numbers.
- Repeated detection with unchanged state does not flood Doxa Help with duplicate diagnostic text. Status shows last refresh time.
- New guide and notice are packaged and integrity-checked in the private ZIP, with EN/RO coverage and driver/cloud isolation.

## Owner acceptance procedure

Launch shortcut **Doxa Setup - TEST preview.8**. On the first page, read the new local data disclosure; keep cloud AI unchecked. Continue to the connected-device page. The main window should fit and be resizable. Select **Detect Doxa** twice and see no duplicated Help messages. Open **Set up screens...**: read the cable steps, inspect the 1-2-3-4 layout and choose each radio option; optionally click Open Windows Display settings to verify the direct link. Do NOT change display topology or reinstall the driver during this usability test.

## Explicit limits

This is a private **UNSIGNED app-only preview**, not a fully qualified fresh-driver or four-screen automatic-configuration installer. There is no Silicon Motion driver binary embedded because OEM redistribution permission is unresolved. The existing pinned official MSI installation engine is limited to qualified connected hardware and requires user/admin approval. Fresh driver-free Windows installation, trustworthy version-matched recovery and any automated layout apply/rollback remain **open in #99**. The Dell 4.7.6.8001 working driver was not uninstalled/reinstalled or updated by these UX changes. Full customer acceptance remains open.

## One-window continuation

As a correction after owner review, the Welcome permissions, connection choice and equipment detection now run in one WinForms window. The navigation preserves the HWND and existing consent state; embedded setup has no second independent window or PowerShell process. The tests exercise a local read-only Detect Doxa action inside the reused form in English and Romanian. This does not imply a signed driver has been installed or displays reconfigured.
