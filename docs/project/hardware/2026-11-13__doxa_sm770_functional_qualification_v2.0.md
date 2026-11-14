# DOXA SM770 — Final assistive-technology functional qualification

**Version:** 2.0 | **Decision date:** 13 November 2026 | **Host:** MARIUS-DELL | **Verdict: PASS — agreed functional acceptance programme closed**

## Executive result

The Doxa triple-screen unit and its signed Silicon Motion SM770 driver **passed the agreed functional programme** with Windows Magnifier, NVDA 2026.2 and ZoomText 2027. The laptop plus three Doxa panels operate as four independent 1920 × 1080 Windows desktops. A real application window spanning all three Doxa panels, genuine Word/Edge/Excel input and readback, independent magnification, NVDA directional panning and the agreed ZoomText modes have passed.

The 10 November historical report was overtaken by corrected physical retests on 11–12 November and the owner's explicit acceptance decision. Its outdated inconclusive verdicts are no longer the final acceptance results. This replacement report preserves the original raw evidence; it does not retroactively invent additional observations.

**PASS means the agreed laboratory acceptance criteria were met.** The supporting catalogue distinguishes verified observation from explicit owner acceptance. It is not a blanket certification of every undocumented vendor feature, alternative hardware setup or day-long user session.

## Rig and verification method

- Dell Latitude 5410, Intel i5-10310U, Windows 11 Pro Insider build 26340, signed SMI770 driver 4.7.6.8001.
- Native laptop screen plus three connected Doxa 1920 × 1080 displays, independently addressable by Windows.
- Actual Word/Edge/Excel keyboard input and data readback; named vendor controls; external camera photographs of physical display light.
- Per-monitor DPI-aware physical coordinates: historical 1280 × 720 reporting was logical-coordinate virtualisation, not a Doxa resolution downgrade.
- Disposable source files; no driver replacement, firmware change, customer data or installed-product modification.

## Original 15-group matrix — final accepted outcomes

| Group | Environment | Agreed target | Final verdict |
|---|---|---|---|
| M1 | Windows Magnifier | Four-screen ordinary interaction | **PASS** |
| M2 | Windows Magnifier | Independent Doxa magnification | **PASS** |
| M3 | Windows Magnifier | Physical four-screen presentation | **PASS** |
| M4 | Windows Magnifier | Word at 4× | **PASS** |
| M5 | Windows Magnifier | Colour/viewport controls under agreed acceptance | **PASS** |
| N1 | NVDA | Navigation and genuine application input | **PASS** |
| N2 | NVDA | Native per-monitor magnification | **NOT APPLICABLE — feature not offered** |
| N3 | NVDA | Native fixed-centre magnifier routing | **NOT APPLICABLE — feature not offered** |
| N4 | NVDA | Doxa window-spanning interaction | **PASS** |
| N5 | NVDA | Directional panning/overview under agreed acceptance | **PASS** |
| Z1 | ZoomText 2027 | Four-screen magnified operation | **PASS** |
| Z2 | ZoomText 2027 | Left/right source to fixed centre | **PASS** |
| Z3 | ZoomText 2027 | Laptop at 2× while Doxa panels remain 1× | **PASS** |
| Z4 | ZoomText 2027 | Word, Edge and Excel real input/readback | **PASS** |
| Z5 | ZoomText 2027 | Colour, restore and view controls under agreed acceptance | **PASS** |

NVDA N2/N3 are **not applicable**, not Doxa failures and not tests awaiting another run.

## Additional accepted functional scenarios

| Scenario | Final verdict | Decisive proof |
|---|---|---|
| Single Windows window stretched across all three Doxa panels | **PASS** | Four-environment WinForms readbacks and photos |
| Three genuine simultaneous applications | **PASS** | Word text, Edge accessible input and Excel value readbacks with all three AT products |
| Windows Magnifier independent screen zoom | **PASS** | 11 November specialist optical closure |
| NVDA right/left directional panning | **PASS** | Correct extended arrow-key input; internal viewport X = 480 → 1056 → 480; camera |
| ZoomText MultiView Local / Global | **PASS** | Centre active-view identification and routed source changes |
| ZoomText explicit LEFT and RIGHT source to physical CENTRE | **PASS** | Camera captures before/after deliberate Route View to Mouse commands |
| ZoomText laptop-only enlargement | **PASS** | Laptop 2×/5×, Doxa panels visually unzoomed |
| ZoomText Span | **PASS** | Readable routed source spanning physical outputs |
| ZoomText Clone | **PASS** | Routed source shown on all four outputs |
| ZoomText Overview | **PASS** | Corrected genuine mouse movement, locator and restored zoom |
| ZoomText Freeze | **PASS — owner accepted** | Creation, toggling and persistence of a frozen overlay; explicit owner acceptance dated 12 November |

The Freeze result is a project acceptance decision. The source photographs and notes continue to show exactly which selections and outputs were physically recorded.

## Lessons affecting the verdict

Initial negative outcomes were caused or confounded by test-input mistakes: wrong Chromium foreground process, an NVDA simulated arrow key without the extended-key flag, obsolete ZoomText Freeze shortcut, virtual versus physical screen coordinates, unanchored ZoomText source routing, and cursor teleports that did not trigger the vendor's normal View Locator. After correcting those inputs, the decisive retests passed.

A running vendor process or a clicked vendor button is not by itself physical proof. The accepted tests used independent application readbacks or real camera evidence in conjunction with the vendor state.

## Final decision and provenance

**Functional compatibility is accepted; no further mandatory physical AT-function tests remain in the agreed scope.** There is no justification for buying a more powerful laptop solely to enable Span, Clone, Overview, MultiView or the ordinary four-screen workflows. Sustained ZoomText CPU cost is a separate performance question covered in the companion report.

No independent human low-vision assessor has yet completed an all-day comfort/fatigue study. Such product usability research is separate from this completed engineering test programme.

This v2 report supersedes functional verdicts in the historical 10 November comprehensive report and interim 11–12 November records wherever they conflict. All raw files remain unchanged. Key source folders:

- artifacts/2026-11-10__sm770_closure/ — spanning application and three-app readbacks/photos.
- artifacts/2026-11-11__sm770_functional_completion/ — NVDA, Windows Magnifier and ZoomText specialist retests, photos, owner acceptance.
- artifacts/2026-11-04__doxa_at_suite/results/ — earlier 15-group evidence.
- lab/doxa-at-qualification/cases.json — machine-validated, SHA256-traceable final acceptance ledger.

**Final programme status: FUNCTIONAL PASS; CLOSED.**

