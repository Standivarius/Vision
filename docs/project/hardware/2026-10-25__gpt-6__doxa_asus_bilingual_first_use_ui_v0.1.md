# Doxa Setup first-use UI — ASUS implementation evidence (2026-10-25)

Source base: Standivarius/Vision PR #78, commit 0a3b2cf67ec3e4e327b76d900854266e19b025c4. Changes developed only in the isolated ASUS worktree C:\wt\doxa-installer-ui. The canonical Dell repo and its dirty local work are untouched.

## Scope
- Bilingual EN/RO **consent-first wizard**, with selection before computer diagnostics and preserved through the main Doxa equipment/help interface.
- Language switching affects page labels, choices, consent text and continuation without altering checkbox states.
- Explicit Tab ordering, accessible names and Enter-to-continue for core welcome controls; accessible descriptions for diagnostic/driver-install actions.
- Driver gates, user-approved UAC, cloud AI opt-in and hidden developer-only tests preserved. The only displayed driver installation path is a verified original signed vendor package; missing hardware yields safe connection guidance.
- Extended extracted-bundle tests exercise both languages, unchanged first-use consent, offline help and safe no-op hardware path.

## Actual ASUS evidence
- Baseline private Release-Control build 40185553875 / v0.4.0-preview.1 ZIP downloaded and SHA256 matched 714f9b651b3e6d045307fd98978bf9d80d368aba600704341e39c904ef13f242.
- Source unit checks Test-DoxaSetupExperience, Test-DoxaCompatibility and Test-DoxaCloudAIPolicy PASS on ASUS, with simulated real-vs-remote topology checks and zero driver/display changes.
- English and Romanian wizard JourneyTest PASS for connected and without-Doxa choices; dynamic language switch did not grant consent or request cloud AI. AI opt-in test merely checks consent state without requesting the service.
- Both main window language JourneyTest paths PASS on the non-Doxa ASUS system: out-of-scope questions are refused, simulated problems stay local, and installer directs user to connect hardware instead of running MSI.
- ASUS local new portable ZIP created and its extracted bundle suite PASS: 16 source hashes, 19 total files, no driver or secret, bilingual journey verified, no installer apply or reboot. Local ZIP 20261025-160958 SHA256 3913368ec563b42714f3576f683e78e66a6d639de4b9fcd7158a3e23ff4abcfa.
- Doxa live Cloudflare AI signing is deliberately Dell-enrolled only; a live gateway test is not possible on ASUS and was not counted as a failure of the offline help feature.

## Remaining qualification
- No human visual/UX walkthrough has been performed yet; UI scripts and extracted-bundle journeys were exercised programmatically.
- ASUS has no connected Doxa hardware, so actual screens/panel detection and physical driver lifecycle were NOT verified.
- No signed public installer, vendor/OEM driver redistribution rights or production release. No driver touched.
- The zipped personal preview remains unsigned. GitHub hosted Windows rebuild from the new exact commit is needed before claiming this as the latest verified GitHub preview.
