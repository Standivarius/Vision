# A03 — ordinary Office application switching at 4x

Date: 2026-10-18. Bounded experiment, not a usability or optical acceptance.

Hypothesis: Vision's right-source / centre-detail 4x viewport follows an
actively selected caret/cell when a person alternates between Word and Excel
windows on the same source display, without becoming stuck on the prior app.

Environment: unattended, unlocked physical console; 3 or 4 Windows monitors,
with dedicated centre Detail and right source. The test generates exactly one
unsaved Word document and one unsaved Excel workbook; aborts if either program
or Vision is already running. It must restore pointer and initial foreground.

Stimulus: six 4.5-second phases alternating:
Word paragraph A; Excel selected cell A; Word paragraph B; Excel selected
cell B; Word paragraph C; Excel selected cell C.
The active test target is highlighted in one of two complementary colours;
hidden background app may retain its own marker, so independent source frames
and fresh foreground PID/UIA/Win32 evidence are mandatory for each phase.

Evidence: continuous timestamped 2fps GDI captures from RIGHT source and
CENTRE destination, original SHA-256 manifest, and QPC-stamped Windows
foreground / UI Automation cell or Win32 Word caret geometry. Source screen
and destination must display the expected *fresh* colour with <=2 second
software-frame lag; any missing evidence is INCONCLUSIVE, not PASS.

Failure/falsification: stuck prior app, delayed marker >2s, missing source
ownership, stale frame, forced Vision shutdown, failure to restore focus,
or app remains running -> FAIL or INCONCLUSIVE with evidence.

This test does not verify arbitrary typing behaviour or photonic latency.
No existing documents, drivers, display settings or other repository changes
may be touched. Record run under artifacts/vision-poc-a-graphics-20261017.
