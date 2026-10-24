# Silicon Motion / Doxa OEM — written redistribution and deployment terms request
**Draft only — NOT SENT | 24 Oct 2026 | Gate DXI-10**

**Suggested recipient:** Silicon Motion Product Support / Sales, https://www.siliconmotion.com/support/contact and vendor commercial/licensing contact. Address to the relevant original Doxa OEM or reseller in parallel if required.

Subject: Request for written commercial distribution rights — SM77x/SMI770 Windows signed driver MSI for Standivarius Doxa hardware

Hello,

We are preparing Standivarius Doxa, a Windows multi-display hardware product built around an observed Silicon Motion SMI770 USB display controller. The current test configuration reports hardware ID prefix USB\VID_090C&PID_770A and a Microsoft WHCP-signed Silicon Motion driver. We are designing a Windows setup application and a managed IT deployment option.

We would appreciate **written clarification and permission**, as appropriate, on these points:

1. May the original, unmodified and vendor-signed SM77x/SMI770 Windows driver MSI be incorporated in a **commercially distributed** Doxa-branded setup installer, alongside our separately signed application? Are there brand notice, attribution, bundling, EULA or packaging restrictions?
2. May that original MSI be repackaged as a separate encrypted deployment payload for Microsoft Intune, Microsoft Configuration Manager, ManageEngine Endpoint Central and corporate offline software repositories? Can customer IT departments mirror or redistribute it to their own managed endpoints?
3. If redistribution is not permitted, is a **separate customer-owned download from your official website**, followed by our read-only verification and a direct vendor MSI invocation, allowed for commercial Doxa products? Is there a partner/OEM redistribution agreement?
4. Which driver files and license conditions apply to hardware ID prefix USB\VID_090C&PID_770A and the versions currently posted: Windows driver **V4.7 R06-8001 (24 Sep 2026)** versus Windows MSI **V4.7 R06 (22 Jun 2026)**? Is a matching MSI release available or planned? Are older MSIs safe on machines with the newer 4.7.6.8001 driver (we currently avoid downgrade/reinstall)?
5. Please confirm silent unattended installation under SYSTEM/administrator context (msiexec /qn /norestart), detection signatures, expected exit codes/reboots, supported Windows 10/11 and Windows security (HVCI, App Control/WDAC), staging without hardware attached, upgrade/repair/rollback effects, and how device removal/re-enumeration custom actions should be handled in a multi-monitor system.
6. Do you require certification/branding approval, a commercial licensing fee, signed OEM release notes, a separate customer EULA, or a change-notification process for future driver versions? Who is the authorised party to grant this permission?

Our installer is explicitly designed to leave a functioning, correctly signed driver installed. We will not alter your INF/CAT/SYS files or bypass Windows driver signature/security policy. We are not redistributing your MSI while licensing remains unresolved.

Please direct us to the appropriate technical, legal or OEM partnership contact and provide the relevant agreement or written authorization.

Kind regards,
[Authorized Standivarius/Doxa legal entity — confirm]
[Authorized contact name, role]
[Company website and business email]

---
**Handling:** User/legal owner to approve recipient and legal publisher. Do not include private hardware serials, certificates, credentials or existing Dell recovery materials. Attach public model/driver version metadata only if requested.
