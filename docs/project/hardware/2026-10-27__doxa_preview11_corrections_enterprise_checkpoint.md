# Doxa Setup Preview.11 — correction and enterprise compatibility checkpoint

27 October 2026 — Engineering-only unsigned app preview. No live tenant or driver changes.

## Corrected from Preview.10 independent review
- Real welcome -> consent -> branded main tab flow tested with the same native HWND, in English and Romanian.
- Tab content and right contextual pane share a single framed workspace; selected state, keyboard focus roles and narrow vertical reflow improved.
- Bilingual tab, port, and help guidance. Rear central Doxa screen UPPER USB-C = power; LOWER USB-C = data/signal.
- Old fallback connection guide corrected to match the same hardware orientation and four-screen layout.
- Detect status distinguishes PnP panel identity from independently verified physical display topology.
- Offline AI selection clears queued work, resets approval for future online use, and warns that already transmitted requests cannot be recalled. Timer checks user consent and IT policy.
- Readable privacy notice is available from Doxa help.
- Driver tab is informational in Preview.11, without a customer-accessible unsigned elevated installer.

## Enterprise contract and version-specific app-only operations
- Approved Preview.11 has 20 hashed source files (including an explicit logo path), two generated launcher/readme files and a manifest, for 23 total archive entries.
- Legacy 16-source-file managed pilot without preview_version is recognised as legacy-16 only after successful complete integrity validation.
- Managed version-specific Detect supports -ExpectedVersion 0.4.0-preview.11; an older installed version must not be accepted as the new one.
- Ordinary Install refuses a different valid installed version (exit 32). Explicit IT-approved -Action Upgrade preflights source, stages, validates, replaces and restores the prior app on swap failure.
- -Action Uninstall continues refusing modified/unrecognised directories (exit 33).
- Update Intune detection script configuration to include -ExpectedVersion; package built with the same source and shared DoxaPilot.ps1 as ManageEngine.
- Full first-time Silicon Motion driver installation, recovery, redistributable licensing and commercial application signing are NOT completed by this app-only integration.

## Evidence
- Preview.11 real branded bilingual journey EN and RO: PASS.
- BrandTest: layout, consent reversion, localised tabs and driver-action hidden: PASS.
- Personal extracted ZIP integrity and safe installer tests: PASS on initial source snapshot; rebuild and rerun against final source before publication.
- Enterprise Test-DoxaPilot.py: 18 temporary-directory lifecycle cases PASS.
- Isolated source-verified upgrade tests Preview.10 -> Preview.11: PASS.
- Isolated historical frozen ManageEngine 16-file payload -> Preview.11: PASS.
- Managed app-only ZIP: LOCAL_PASS (20 source, 23 archive, two distribution files), with no OEM driver or credentials.
- No real new Intune or ManageEngine assignment and no physical driver mutation was performed.

## Open before customer release
- Owner visual acceptance on Dell including high DPI, keyboard and screen-reader walk-through.
- Independent re-review of changes, especially remote AI in-flight cancellation limitations and topology claims.
- Validated signed installer with observable elevated result and recoverable physical vendor-driver lifecycle.
- Actual IT-controlled app-only Preview.11 managed-agent qualification in both endpoint managers before claiming enterprise rollout.
- Public publisher signing, final legal/cloud privacy documentation and OEM driver redistribution permission.