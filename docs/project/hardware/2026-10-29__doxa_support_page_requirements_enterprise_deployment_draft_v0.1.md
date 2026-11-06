# Doxa Pro 3 support page and enterprise deployment — publication draft

**Date:** 29 October 2026
**Status:** proposed public support copy; NOT YET PUBLISHED ON THE STANDIVARIUS WEBSITE
**Scope:** Doxa Pro 3 portable triple monitor using Silicon Motion SM770, not the separate Vision low-vision software product.

## Doxa Pro 3 — system requirements

Doxa Pro 3 connects by USB data and requires sufficient power for its three external screens. Your computer does **not** need a USB-C video output: the Doxa manual documents a **USB-C-to-USB-A adapter** connection with external USB-C power. USB data is not HDMI/DisplayPort Alt Mode. A powered, reliable data link matters more than port shape.

| | Windows laptops | Mac computers |
|---|---|---|
| OS baseline | Windows 10 or 11. For our **current Windows installer** the tested minimum build policy is 19041 (Windows 10 2004) or newer, but this is an engineering policy, not full compatibility certification. | macOS 13 Ventura, 14 Sonoma, 15 Sequoia, 26 Tahoe and 27 Golden Gate appear on Silicon Motion's current SM77x software support list. Confirm specific macOS version and device compatibility before promising operation. |
| USB data | Working USB data port, USB-A with suitable adapter or USB-C; prefer USB 3.x for better bandwidth. | Compatible USB data port with suitable adapter, preferably USB 3.x. |
| Power | 30 W or greater external USB-C power supply when laptop/port cannot provide adequate power; follow bundled product power/cable instructions. | Same Doxa power requirement; separate power needed for USB-A data connection. |
| Software | Compatible signed Silicon Motion SM770 USB display driver. Windows installation may need administrator permission. | Compatible Silicon Motion InstantView application; requires macOS Screen Recording permission for display operation. |
| Actual screens | Three external screens can only be confirmed with Doxa physically connected. | Same: connected test required, and macOS display permissions may affect availability. |

**Not verified by a pre-purchase scan:** port type, cable quality, negotiated USB data speed, available power, the enterprise security policy that may prevent this program from launching, whether macOS permissions will be granted, and actual three-panel display extension. Corporate policies are managed by the buyer's IT team.

**For customers with company-managed computers:** Your organisation may restrict installation of USB display software, device drivers or macOS screen permissions. A local compatibility checker may itself be blocked by company policy. Before buying, ask IT to review the Doxa requirements and the enterprise deployment guide below. We cannot guarantee that a pre-purchase checker can determine your company's policy.

**Check my PC (Windows, optional):** A read-only tool can inspect Windows build and USB host-controller presence **only if Windows allows it to run**. It never installs the Doxa driver, demands administrative rights, verifies cables/power or promises that all three screens will work. Results: Basic requirements appear satisfied; Needs attention; Cannot assess due to restrictions / insufficient information.

## Downloads and setup

### Personal Windows setup

Download the signed `DoxaSetup.exe` from this product's official download page. Verify **Publisher: DMR ERGONOMICS S.R.L.** and published SHA-256. Launch, review setup information, grant local-check permission separately, connect Doxa power then USB data, complete screen arrangement in Windows settings. Optional online assistant requires device enrolment and is not a basic requirement for operation.

**Preview status:** Current 29 October 2026 signed Windows installer is a private evaluation release; it is *not yet a qualified mass-market or IT mass-deployment package*. Do not post its personal evaluation link as a final commercial download.

### Mac setup

Windows `DoxaSetup.exe` **cannot run on macOS**. Use Silicon Motion's current **macOS InstantView** from the official [SM77x driver page](https://www.siliconmotion.com/downloads/SM770-drivers.html). macOS Screen Recording permission is needed to generate the image for the USB-connected screens. Follow the official macOS instructions for connected displays and screen arrangement.

## IT administrators — Windows enterprise deployment

### What files IT expects

A public **Doxa for IT Administrators** support section (or IT pack reachable from the main Doxa product page) should offer a versioned package and trustworthy, vendor-controlled release details, without asking the customer to visit the internal private GitHub repository:

- **Microsoft Intune:** `DoxaDeploy.intunewin` (Win32 app package).
- **ManageEngine Endpoint Central:** publisher-signed `DoxaDeploy.exe`, with configured silent command.
- **Microsoft Configuration Manager / SCCM:** same signed `DoxaDeploy.exe` deployed as an application.
- **PDQ Deploy / Connect and compatible RMM tools:** same signed EXE with documented silent command. Other solutions with custom Win32 installer support (e.g. NinjaOne, Ivanti, Omnissa Workspace ONE) should generally be able to use the signed EXE once compatibility is verified. **Do not claim native recipes tested for each product**.

Installer is universal; only Intune needs a specialised `.intunewin` wrapper. Never invent an installer `.msi` for Doxa if our deliverable is an EXE containing a vendor-signed MSI.

### IT deployment sequence

1. **Get the versioned signed package:** Download from official Doxa support; check signature, timestamp, checksum, minimum OS, OEM redistribution/licensing status and release notes.
2. **IT approval:** Security team permits the publisher/signed executable, driver and any policies required. IT decides device groups, assignment and restart window.
3. **Pilot one endpoint:** Run unattended in **SYSTEM / machine** context; no user-facing consent dialogs or UAC inside that silent deployment. Confirm command and exit status.
4. **Doxa connected?** If not, managed `/install` installs only the application and **defers** the vendor driver. If present and a compatible signed driver is missing, the driver step is permitted. Never downgrade a healthy driver.
5. **Detect separately from hardware:** `/detect` reports installed application. `/verify` reports connected device and trusted driver. `/verify-panels` reports three Doxa PnP monitor identities. Successful software deployment alone does not prove correct physical screens or Windows Extend mapping.
6. **Roll out and support:** IT reviews log location, reboot code 3010, repair/uninstall instructions and any incident reports. No forced reboot.

### Documented Windows commands

| Operation | Command |
|---|---|
| Install | `DoxaDeploy.exe /install` |
| Detect installed application | `DoxaDeploy.exe /detect` |
| Verify USB and driver binding | `DoxaDeploy.exe /verify` |
| Verify three Doxa monitor identities | `DoxaDeploy.exe /verify-panels` |
| Repair | `DoxaDeploy.exe /repair` |
| Uninstall **application only**, preserving signed display driver | `DoxaDeploy.exe /uninstall` |

Return **0** for success, **3010** when a reboot is requested (IT controls restart), and other nonzero results as actionable failure. Keep publication release SHA-256 values and accurate log paths in version-specific runbooks.

**Important release gate:** Our 29 October signed enterprise executable is real and verified, but actual mass-deployment through Intune/ManageEngine and OEM redistribution approval are not complete. These files must not be advertised as mass-deployment qualified until those checks pass.

### Where documentation and binaries should live

- **Standivarius Doxa support website:** discoverable public page, OS requirements, ordinary installation guides, IT deployment landing page, latest *qualified* downloads, release notes, SHA-256 signatures and contact.
- **Standivarius-controlled download storage:** immutable versioned signed files over HTTPS. Never silently replace bytes at the same URL; maintain a latest-version link pointing to an immutable version.
- **Private GitHub Release-Control and Vision repositories:** source code, signed-build pipeline, test evidence and engineer-specific instructions. Customers do not need GitHub accounts.
- **Optional public GitHub release:** only if desired as a distribution mirror; it is not a substitute for the vendor's support page or trustworthy download/version records.

## Official sources / provenance

- Standivarius Doxa Pro 3 technical page: https://www.standivarius.com/product/doxa-pro-3-portable-triple-monitor/
- Standivarius Doxa Pro 3 user instructions (USB-A adapter and 30 W instructions): https://media.standivarius.com/repository/standivarius-doxa-pro-3-user-instructions.pdf
- Silicon Motion SM770 USB display SoC, CAT hardware acceleration, host support: https://www.siliconmotion.com/products/USB-Display-Docking-SoC/detail
- Silicon Motion current SM77x Windows/macOS drivers: https://www.siliconmotion.com/downloads/SM770-drivers.html
- Silicon Motion macOS InstantView instructions: https://www.siliconmotion.com/downloads/video/SMI%20macOS%20InstantView%20User%20Manual.pdf
- Microsoft Intune Win32 guide: https://learn.microsoft.com/en-us/intune/app-management/deployment/win32
- Microsoft Configuration Manager application guide: https://learn.microsoft.com/en-us/intune/configmgr/apps/deploy-use/create-applications
- ManageEngine Endpoint Central supported EXE deployment: https://www.manageengine.com/products/desktop-central/help/software-deployment/create-software-packages-windows.html
- PDQ custom package formats and silent parameters: https://docs.pdq.com/current-version/Deploy/supported-install-files.htm

## Publication checks

Before site publication, reconcile this draft with the actual Doxa OEM wiring, supplied adapters, power accessories, supported OS versions and signed release. Confirm current 2026 driver versions and Mac model-specific limitations. Obtain the exact corporate download and support URLs from the live website owner. Do not claim that Mac support uses our Windows EXE, or that the Win32 signed pilot is already enterprise mass-deployment approved.
