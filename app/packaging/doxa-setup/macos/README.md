# Standivarius Doxa Setup for macOS

Independent macOS setup companion for Doxa hardware using Silicon Motion's SM770 / InstantView USB-display solution. Not the Windows Vision magnifier, not a Silicon Motion driver, and not a substitute for InstantView.

## Customer workflow

1. Connect Doxa power and USB-C data.
2. Download and install **InstantView** from [Silicon Motion's official SM77x page](https://www.siliconmotion.com/downloads/SM770-drivers.html). **We do not redistribute InstantView.**
3. Grant **InstantView** Screen & System Audio Recording permission, a user-controlled macOS Privacy & Security setting, then start InstantView.
4. Open Displays in macOS Settings, arrange the three Doxa screens and choose Extend mode where supported. Read-only diagnostics report visible screens, InstantView installation/running state and possible USB markers.

No automatic installation, TCC permission changes, privileged shell commands or security bypass. The diagnostics run only after explicit permission.

**Online AI is not enabled in the macOS prototype.** The current Doxa AI service has Windows-specific diagnostics and curated answers. Enabling it on Mac without porting the secure key and updating the knowledge could produce wrong advice. Offline support is included; the Mac-specific online AI integration is an explicit follow-up.

## Build

The `doxa-macos-installer.yml` workflow uses a real GitHub Actions macOS host to compile a **universal Intel + Apple Silicon SwiftUI app**, then creates a `.pkg` installer and `.dmg` disk image. Static, package-structure and architecture checks are included.

`StandivariusDoxaSetup.swift`: native AppKit/SwiftUI, macOS 13+.

`build-macos.sh`: compile, package and produce SHA-256 build manifest.

`test-macos.sh`: source and platform package-contract tests.

## Production signing and notarisation (credential-gated)

The existing build script now supports two explicit modes. Default mode creates **ad-hoc signed, unsigned-for-distribution review artifacts** (not customer releases). Production mode signs the universal `.app` with an Apple **Developer ID Application** identity and hardened runtime/timestamp, signs the `.pkg` with a separate **Developer ID Installer** identity, submits **both** `.pkg` and `.dmg` to Apple's notary service, staples and validates tickets, and then produces checksums. A failed sign/notarise/staple step stops the build. InstantView is never redistributed.

Prerequisites on a trusted Mac signing runner:

1. Apple Developer Program organisation membership, and both Developer ID certificates with their private keys installed in its signing keychain.
2. A `notarytool` credentials profile created using Apple's official `xcrun notarytool store-credentials PROFILE ...` flow. Keep passwords and private keys outside the repository.
3. Set `DOXA_MACOS_RELEASE=1`, `DOXA_MAC_DEVELOPER_ID_APP="Developer ID Application: ..."`, `DOXA_MAC_DEVELOPER_ID_INSTALLER="Developer ID Installer: ..."`, and `DOXA_MAC_NOTARY_PROFILE=PROFILE` in that runner's environment. Run `bash app/packaging/doxa-setup/macos/build-macos.sh /a/new/empty/output/directory` on the **reviewed, committed release source**.
4. Inspect `codesign --verify --deep --strict` for the app, `pkgutil --check-signature` for the PKG, `xcrun stapler validate` for **both** containers, `shasum -a 256 -c SHA256SUMS.txt` and the `SOURCE-COMMIT.txt` identity. Preserve the notarisation submission identifiers/logs as release evidence.
5. Test actual installation, screen permissions and InstantView functionality on **both an Intel and an Apple Silicon Mac**, with the real Doxa connected, before release promotion.

**Do not publish a product build simply because CI's unsigned preview passed.** The 9 November macOS v0.1.0 GitHub draft is intentionally not notarised, and the GitHub Actions preview workflow has no production signing identity configured.

## Release limits

- **Unsigned preview remains current** until the guarded production mode is executed with real Developer ID certificates, successful Apple notarisation and physical acceptance.
- No physical Mac, InstantView, permissions, Doxa displays or Mac enterprise MDM is verified by building on a CI host.
- USB detection is heuristic, not proof of Doxa hardware. AppKit's active screen count may include unrelated monitors.
- We never request private macOS screen-capture permission on behalf of InstantView.
- Current vendor download page lists InstantView V4.7 R02 (22 June 2026) for macOS 13, 14, 15, 26 and 27. The live official vendor page, not a repackaged binary, is the source for current versions.
- A commercial release requires manufacturer redistribution review if their application is ever bundled, Apple signing/notarisation, real Mac physical testing and Mac-specific legal/privacy approval.

Windows installer, driver and Vision application remain untouched.
