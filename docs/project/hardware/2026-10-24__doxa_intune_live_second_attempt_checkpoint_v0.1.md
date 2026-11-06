# Doxa Intune publisher — second Graph application-creation rejection and validation corrections

Date: 24 October 2026
Branch: `doxa/installer-clean-pr-20261024`, draft PR #78.

## Live observed, after authorised delegated Microsoft sign-in

- Administrator authenticated to existing DMR Ergonomics tenant.
- The publisher confirmed `MARIUS-DELL` uniquely exists as an Intune **managed, compliant** device and its designated security group from the first attempt was reused, not duplicated.
- **POST** `/v1.0/deviceAppManagement/mobileApps` again returned **HTTP 400 BadRequest**. No app was created, uploaded or assigned; there was no Intune software installation or Doxa driver mutation. Graph supplied no useful diagnostic text in the old filtered output; the precise reason is **unconfirmed**.

## Source checks and fixes, prepared for a further authorised attempt

Compared the generated `.intunewin` Detection.xml with Microsoft's official `win32LobApp` REST v1.0 documentation and official `mggraph-intune-samples` implementation.

- App creation now explicitly includes `fileName="IntunePackage.intunewin"` from the encrypted package metadata; previous versions omitted the LOB file identity.
- Return-code entry now includes `@odata.type="microsoft.graph.win32LobAppReturnCode"`; previous version omitted the nested type.
- Content-version create includes `@odata.type="#microsoft.graph.mobileAppContent"`, matching official v1.0 POST example.
- HTTP 400 diagnostics now redact URL/email/Bearer/JWT/SAS tokens and include a bounded message, rather than suppressing the whole validation message if Microsoft includes a URL. No access token or SAS URI is stored or printed.
- App still includes the explicit source-package identity, `Windows11_23H2` minimum release, system install with restart suppressed, the hashed detection PowerShell rule, and a one-device-only group membership check.
- **8/8 local publisher tests PASS**, including the exact v1 creation payload and a fake Graph error with a secret-bearing URL that must be redacted.
- No Graph writes ran during these local tests. Microsoft has **not yet confirmed** the corrected payload: do not claim creation or deployment as PASS.

## Still required

One fresh interactive delegated Microsoft login for the next real app-create attempt because tokens are ephemeral. Existing pilot security group should be reused. All further upload, content-version commit, Dell-only assignment, actual Intune Management Extension installation and device status remain untested live.

Sources:
- https://learn.microsoft.com/en-us/graph/api/intune-apps-win32lobapp-create?view=graph-rest-1.0
- https://github.com/microsoft/mggraph-intune-samples/blob/main/LOB_Application/Win32_Application_Update.ps1
- https://learn.microsoft.com/en-us/graph/api/intune-apps-mobileappcontent-create?view=graph-rest-1.0
- https://learn.microsoft.com/en-us/graph/api/intune-apps-mobileappcontentfile-commit?view=graph-rest-1.0

No Silicon Motion vendor MSI, original Vision workspace, company-wide Intune policy or Microsoft account-country setting was changed.
