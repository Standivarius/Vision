# Doxa Setup — Terms live-window test and signing hold
**Date:** 9 November 2026
**Scope:** Private owner-test installer, v0.4.0-preview.13, worktree `fix/doxa-terms-layout-review-20261109`

## Defects found and corrected by actual WinForms execution
The first live dialog test reported `close_within_footer=false`: Close was positioned outside the footer because its initial X was calculated against an unlaid-out Panel. Changed to a right-docked button with panel padding. Retest returned `close_within_footer=true`.

A screen rendering inspection also showed body text receiving the heading colour/bold face. RichTextBox selection positions differ from regex character offsets when Windows line endings are normalised. The dialog now finds each heading in the actual RichTextBox via `Find(..., NoHighlight)`, then formats only that span.

## Instrumented, read-only GUI verification
The new `app/packaging/doxa-setup/full-release/Test-DoxaTermsWindowGeometry.ps1` extracts the real Terms click-handler, opens it and automatically closes it. It never installs drivers, changes Windows scaling, or requests Online AI. It verifies Close geometry, text/footer separation, headline formatting, body styling, preservation of section 8 and visibility of the final character after ScrollToCaret.

| Test case | Actual monitor DPI | Close | Last character | Heading/body styles | Footer overlap |
|---|---:|---|---|---|---|
| 800×580, original 100% text | 96 | PASS | PASS | PASS | NONE |
| 540×390 minimum, original 100% text | 96 | PASS | PASS | PASS | NONE |
| 800×580, 150% font stress | 96 | PASS | PASS | PASS | NONE |
| 540×390, 200% font stress | 96 | PASS | PASS | PASS | NONE |

The **150% and 200% cases enlarge the Terms body font in the test only**. They are deliberately *not* called real Windows DPI tests. Do not claim Windows scaling at 150% or 200% is signed off from this evidence.

The screenshot captured from the user's active desktop was obscured by an unrelated ZoomText Magnification Adapter dialog. That dialog was not closed or altered. Accordingly this is control-level GUI acceptance, not independent screenshot-based optical signoff at three actual Windows DPI scales.

## Signing and release decision
Sonnet 5.5's previous post-remediation verdict was **CONDITIONAL GO** for signing a *supervised private owner-test build*, with actual UI verification and deterministic source/package gates. All original four P0 code items were addressed; additional live button and formatted-heading defects were then caught and corrected. **No signature has yet been applied to these newer bytes.**

A previously signed 31 October manufacturer pilot had valid DMR ERGONOMICS S.R.L. Authenticode and Microsoft timestamp. It does **not** sign any new version. A usable local signing certificate/private key was not found on Dell, and the local Azure CLI/signing tools were not available when checked. Establish the approved Microsoft Artifact Signing service identity or other supported publisher-signing route, identify the precise signer/profile, then invoke the release finaliser with timestamp and verified certificate identity. Never reuse the old executable or alter signed bytes.

### Still open
1. Real 100%/150%/200% Windows DPI visual acceptance with unobstructed terms window and Close/Tab/Esc/Enter (or explicit recorded waiver for *private owner test only*).
2. Publisher Authenticode and timestamp on **both** personal and managed executables; post-sign manifest/Intune/ManageEngine recalc and trust verification.
3. OEM Silicon Motion MSI redistribution rights, real personal and enterprise pilot, legal/GDPR/Cloudflare review and managed deployment gates before any external commercial release.

All existing Dell drivers and project work were preserved.
