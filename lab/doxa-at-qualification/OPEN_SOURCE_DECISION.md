# Open-source test-management review and selection

**Decision:** Keep the existing **Vision Test Farm** as execution infrastructure, and use installed **pytest + JUnit XML** for pure pipeline validation and portable result exchange. Implement a small **Python standard-library evidence ledger** and PowerShell hardware adapter. **Do not install a new server, database or external SaaS product.**

## Alternatives assessed

| Candidate | Strength | Cost or mismatch | Decision |
|---|---|---|---|
| Vision Test Farm (existing local, open project code) | Already has scenario schema, capability resolver, guarded execution, timeouts, immutable bundles, assertion oracles, aggregator | Focused on the Vision application rather than historic assistive-technology evidence | **Reuse as general execution layer; add AT domain adapter** |
| pytest + JUnit XML | Installed on Dell; lightweight, open-source, cross-platform CI-friendly; standard export accepted by GitHub actions/CI | No physical-device test orchestration by itself | **Adopt for pure pipeline validation; keep separate Windows physical runner** |
| Robot Framework | Mature keyword-driven orchestration, log.html, report.html and xUnit support | Requires wrapping extensive existing PowerShell/Python scripts and changing test vocabulary; no physical optical truth by itself | Defer; no incremental advantage for a closed programme |
| Google OpenHTF | Purpose-built hardware test phases, measurements, limits, test-record metadata | Better for factory/end-of-line device testing than interactive Windows magnifier, Office, physical camera and licensed ZoomText trial | Defer unless Doxa moves to production manufacturing test stations |
| Allure Report / ReportPortal | Rich dashboards, historical run analytics, attachments and trend views | Additional command-line dependencies or maintained server and administration; does not supply missing physical truth | Defer; HTML/JSON/JUnit from the local ledger covers current needs |

## Decision rationale

The problem was not an absence of a visual dashboard. It was an inconsistent **chain from scenario → physical preflight → correctly executed action → independent evidence → acceptance decision → current report**. The selected system fixes that chain with ~one catalogue, one validator/exporter and one physically gated adapter, while the mature existing Vision test farm remains available for underlying execution.

The new read-only doxa_at_evidence_audit scenario also runs successfully through the existing Vision Test Farm (13 November: 1 PASS). The ledger stores evidence paths, byte sizes and SHA256 hashes, plus owner-versus-observed basis. JUnit XML enables automated quality checks without forcing a new database. Existing raw ETLs/photos are large and sensitive; they stay on Dell. Nothing automatically publishes evidence to the internet.

## Sources checked 13 November 2026

- pytest, standard JUnit XML reporting: https://docs.pytest.org/en/stable/how-to/output.html
- Robot Framework results/logs/xUnit: https://robotframework.org/robotframework/latest/RobotFrameworkUserGuide.html
- Google OpenHTF repository: https://github.com/google/openhtf
- Allure Report documentation: https://allurereport.org/docs/
- Existing repository source: lab/automation-harness/README.md and its tf_cli.py, tf_runner.py, tf_environment.py, tf_aggregator.py.

**Revisit this decision** if qualification becomes frequent multi-site manufacturing/lab work requiring calibrated instruments, searchable historical runs, operator assignment, dashboard permissions or serial-number traceability across multiple physical units. Current project size does not justify those new operational costs.

