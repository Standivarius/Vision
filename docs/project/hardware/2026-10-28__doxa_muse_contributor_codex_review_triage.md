# Doxa installer — independent Muse Spark 1.3 Contributor review and triage

**Date:** 28 October 2026
**Project / branch:** Vision, `doxa/review-package-20261028`
**Reviewer:** Meta `muse-spark-1.3-contributor`, invoked inside **Codex CLI 0.155.0** using an independent fresh session and a clean, restricted Meta-provider configuration. Actual run identifies `model: muse-spark-1.3-contributor`, `provider: meta`, `sandbox: read-only`. No other models were used for this delegation. Codex's unrelated expired OpenAI login produced warnings, but the Meta model request completed successfully and saved its answer.

**Independent reviewer source:** `docs/project/hardware/2026-10-28__doxa_muse_contributor_codex_raw_review.md`. Exact reviewed source files (20), input hash, and model logs live in the read-only external review snapshot at `C:\mcp\vision-dev\state\reviews\doxa-muse-1_3-contributor-codex-20261028`. The neutral packet comprised approximately 196,000 characters. Muse was **not** given previous Gemini findings or implementation recommendations.

## Product reviewed

Standivarius Doxa needs a one-file, nontechnical **customer Windows installer** and a **silent enterprise installer** for Intune/ManageEngine. Both share a C# Windows host that packages a pinned signed vendor driver MSI and a bilingual guided Windows interface. Install/repair/uninstall must preserve a healthy display driver and avoid unsolicited reboot or display layout modification. The reviewer saw source and local test results, not a live desktop or first-time driver-free hardware.

## Muse verdict

**NOT READY for public retail distribution or broad managed rollout.** Muse recognized embedded driver verification, healthy-driver preservation, stable software detection, and a consolidated distribution model as useful foundations. It challenged missing signing and first-use / uninstall qualification and surfaced additional source/UI concerns.

## Findings: engineering assessment

| Item | Assessment | Rationale / next action |
| --- | --- | --- |
| Customer and managed EXEs unsigned | **Confirmed release blocker** | The reviewed release manifest reports `NotSigned`. Commercial signing and validation of the *signed, rebuilt packages* remain open. |
| Driver-first installation on clean PC without signed Doxa driver | **Confirmed untested acceptance gate** | Disconnected MSI preparation was implemented after Gemini High, but there is no physical clean-host evidence that Silicon Motion's installer stages the required driver or that Windows later binds it reliably. Requires recoverable driver-free device test, not risk to Dell's working display setup. |
| Final Intune uninstall / managed agent completion | **Confirmed incomplete at review time** | The post-Gemini exact build passed a real Dell-only Intune SYSTEM install and detection, verified separately from the packet; the matching Dell-only uninstall assignment was sent but endpoint execution was unconfirmed and the application was still installed at last check. Prior-build uninstall evidence is not a substitute. |
| Retail guided UI asks user to select an MSI file | **Confirmed product-level problem** | `Start-DoxaSetup.ps1` still creates an `OpenFileDialog` for the vendor MSI and invokes a separate elevation path. Since the native retail EXE already embeds the signed MSI, remove or properly isolate this redundant customer-facing path; one-file install should not require selecting an external MSI. |
| `TEST preview.12` shown to customers | **Confirmed product-level problem** | Several guided UI files still assign these titles. Replace with stable customer labels before a release. |
| Build may drift between source and tested artifact | **Partly valid hardening** | The builder recompiles current `DoxaSetupHost.cs` and does not separately pin its SHA before build. The final executable and distribution file hashes are recorded, so a claim that absolutely no checksums exist would be false. Improve source/commit provenance binding before signing. |
| Diagnostic reliance on `oem102.inf` | **Confirmed test portability issue** | Native test reads that particular Dell INF path; it is not a portable driver-store identity. Replace with safe PnP/driver-store enumeration. |
| Cryptic `AppMissing DriverValid USBDetected` status | **Confirmed user-facing usability issue** | This is internal status text, appropriate for automation but not an understandable retail explanation. Translate to localized action guidance. |
| Incomplete helper source files | **Evidence limitation, not verified absence** | Source referenced in the UI exists in the wider repo but some helper scripts were intentionally not included in this bounded review packet. Must verify their existence in the finished embedded manifest and real retail journey; cannot infer they are missing from the product. |
| Successful `/detect` always writes logs | **Not confirmed; overly broad claim** | `Trace()` creates the log directory when called, but the success path for `/detect` does not unconditionally call `Trace`. Error paths can log; that is a narrower side-effect issue. |
| Complete intermediate zip exposes vendor MSI | **Build artifact vs customer package** | Builder stages an intermediate package containing original MSI and source. The separate retail builder embeds those and emits standalone EXEs. Prevent accidental distribution of intermediate build artifacts; do not mislabel them as the final customer package. |
| ManageEngine live agent, restrictive WDAC/AppLocker, user-session UI | **Open acceptance gates** | Crypto-equivalent managed payloads have been tested locally, but not current live ManageEngine installation. Locked-down Windows customer usability requires direct acceptance testing. |

## What was deliberately not done

No production signing, no driver removal or first-install experiment on Dell, no code modifications, no repository merge, no unrestricted Codex tools, and no change to system Intune assignments for this review. Only read-only inspection and the authorized Meta Contributor model call were used.

## Prioritized next sequence

1. Correct the retail file-picker / duplicate install pathways and remove visible TEST labels. Make every status and next action understandable in English and Romanian.
2. Make build-source-to-final-hash provenance explicit and remove Dell-specific fixed INF expectations from portable tests; rerun native and encrypted package tests.
3. Complete the *current-build* Intune uninstall, verifying the management-agent result, Windows registration removal, preserved signed driver and no temporary assignment.
4. Qualify driver-first setup on a recoverable clean Windows device, complete actual ManageEngine deployment, and test ordinary first-use + repair/uninstall with constrained corporate policy.
5. Apply commercial publisher signing and re-run final test matrix on the exact signed bits before any public release.

**Decision:** Independent review accepted as evidence, not as automated authorization to change code. GitHub PR #106 remains draft. No source changes were made in this Muse review turn.
