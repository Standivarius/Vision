# Doxa / Vision test scaffolding audit and migration register

**Reviewed on MARIUS-DELL:** 13 November 2026. Scope: Doxa SM770 / assistive-technology qualification scaffolding in the Vision repository. The unrelated application-product test programmes remain under their existing owners.

## Repository inventory at closure

| Area | Direct files | Executable Python/PowerShell files | Role after closure |
|---|---:|---:|---|
| lab/pocs/doxa/assessment | 175 | 169, including 14 Python unit-test files | Historic Vision/Doxa physical-geometry and assessment primitives; **preserve** |
| lab/automation-harness | 38 | 37 | **Canonical generic Vision Test Farm**; retain the resolver, runner, evidence and aggregator |
| lab/incumbent-research | 16 | 11 | Historic ZoomText/SuperNova research; no automatic Doxa acceptance invocation |
| artifacts/2026-11-10__sm770_closure | 45 | 7 | 10 Nov optical/readback evidence plus two selected script families used by the new guarded adapter |
| artifacts/2026-11-11__sm770_functional_completion | 436 | 37 | 11–12 Nov NVDA, Magnifier, ZoomText specialist photographs, corrections and chronological records |
| artifacts/2026-11-13__zoomtext_performance_closure | 25 at inspection | 2 PowerShell | Final eight CPU intervals, reversible settings trial and restoration (read-only historical evidence) |
| lab/doxa-at-qualification | New | Ledger Python and approved-run wrapper | **Canonical SM770 qualification catalogue, audit, reports and live-run gate** |

A broad source-pattern scan found process-control, topology or recovery command text in 13 assessment scripts, three generic test-farm scripts, five incumbent-research scripts, 13 historical specialist completion scripts and five original closure scripts. This is a **candidate-risk inventory**, not an assertion that each script is unsafe; the fact that many scripts manipulate processes, inputs or recovery is the reason not to execute a whole directory indiscriminately. Do not install, remove, disable or reset drivers or display paths as part of a generic test run.

## What becomes canonical

**Qualification catalogue and evidence:** cases.json lists all 15 original M/N/Z groups, the additional wide-window and three-app qualification checks, specialist ZoomText modes and three performance findings. Every acceptance has an explicit basis and evidence reference. Evidence paths are checked for existence, workspace containment and SHA256 integrity.

**Physical scenario invocation:** Only the 10 November wide-window and three-real-app script families have been permitted through the new guarded physical adapter; these retain their actual readback and camera tests. The adapter copies the selected script, redirects the fixed historical output folder to a **unique new run folder**, and protects the original evidence. No licence manipulation, reboot, USB disconnection or driver replacement is included.

**Generic farm integration:** the safe read-only scenario doxa_at_evidence_audit is registered in lab/automation-harness/scenarios/. Its first local Test Farm execution passed and produced ordinary farm result and aggregate bundles. Other farm scenarios remain unchanged.

**Automated software contracts:** pytest validates the catalogue, hashes, security, final v2 report verdict consistency, measured CPU summaries when Dell evidence is available, deterministic JSON/HTML/JUnit XML exports and overwrite refusal. Hosted CI runs **only pure tests**; local physical evidence remains private on Dell.

## What remains historical (not deleted, not reclassified)

- Earlier experiments: all A02–A05 variants, exploratory pointer/colour/freeze attempts, optical preflight scripts, RDP/console recovery experiments and the original 15-group result files.
- Earlier stage and settings scripts from ZoomText CPU root-cause studies, WPR traces, device-topology experiments and unqualified one-output attempts.
- Original dated qualification reports. The two **13 November v2** documents are authoritative for current verdicts; earlier wording is research provenance.
- The existing Vision Test Farm's scenarios, tests and UI contracts. There is no reason to restructure the generic Vision architecture while closing the SM770 research.

A test-harness failure is not a device failure. A vendor menu click is not a physical outcome. An owner's agreed acceptance can be PASS without changing the underlying observation. All three rules are now encoded in the procedure.

## Operator sequence for the next genuine physical qualification

1. Establish a new, explicitly named objective and **new** test-run folder. Do not repeat already accepted tests without a new purpose.
2. Run the Python qualification audit and physical-console preflight. Check four active screens, actual device mapping, Windows build, signed SMI driver, camera view, Wi-Fi and the vendor trial window before any timed activity.
3. Choose one guarded scenario and obtain explicit physical-run authorisation. Test a dedicated labelled source; keep any reboot or driver operation outside this suite.
4. Save independent source values, vendor state, physical camera photographs, timestamps, raw exit logs, hashes, final topology and configuration restoration.
5. Score exact acceptance under the agreed scenario. Retain failures and aborted states as evidence; repair **the test harness** before attributing a fault to Doxa.
6. Export JUnit/JSON/HTML, then revise a dated current report if the new evidence changes a decision. Do not rewrite earlier proof or silently upgrade unrelated vendor capabilities.
7. Close the test-owned applications and verify Wi-Fi, four monitor paths, driver state, signed binaries and repository cleanliness. Never touch unrelated dirty files.

**Stop rule:** accepted scope completed; only a new reproducible regression, changed hardware/software, target customer requirement or owner-approved question can justify another live AT experiment.

