# Doxa Setup preview.9 ? one continuous customer window

Date: 2026-10-27. Technical GitHub Issues [#98](https://github.com/Standivarius/Vision/issues/98) and [#99](https://github.com/Standivarius/Vision/issues/99). Builds upon private preview.8.

## Owner direction

The owner observed that after first two Welcome/Connection pages, the installer closed the form and opened a separate Doxa Setup application window, appearing to be two disconnected processes. This is not a coherent customer journey.

## Implemented

- Both permission and connection choices remain in their **original Form and HWND**.
- On Continue to Doxa checks, main detection and setup replace the content of the **same Form** without closing/launching another.
- A persistent PowerShell module owns the embedded main UI event handlers after navigation; this was required to avoid dead Detect Doxa callbacks.
- First pages are now Steps 1 and 2 **of 4**, followed by existing main detection Steps 3 and 4 of 4.
- Consent (including separate AI opt-in) precedes hardware scanning; the main screen receives the choices without asking again.
- The existing height-responsive, resizable form, exact Detect Doxa label, data-information link, offline illustrated connection/layout guide and duplicate-help suppression remain.
- Same HWND and functional post-transition Detect Doxa are explicitly verified in both languages, including from an extracted ZIP.
- This is a private preview only, with no driver changes, no Windows display layout write, no UAC, and no new AI access.

## Dell owner review

Launch the separate **Doxa Setup - TEST preview.9** shortcut. Observe Step 1 consent, Step 2 connect, then Continue to Doxa checks. The application should **not disappear**, open a second window or open a terminal. In the same window, use Detect Doxa, Set up screens and resize. Report any flash, lost focus, inaccessible control or missing answer.

## Not yet a full first-install certification

Full signed vendor-driver provisioning from driver-free Windows, unattended install with approved OEM terms, real automated display-geometry apply/revert, trusted recovery and Microsoft signing remain tracked under #99. This update does not remove or reinstall Dell's working 4.7.6.8001 driver.
