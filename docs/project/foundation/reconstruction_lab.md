# Vision Reconstruction Lab

Status: Established for targeted Windows mechanism research after the 2026-10-10 Vision calibration.

## Purpose

Use binary/runtime evidence to answer a specific Vision engineering question about an installed application without first decomposing the entire product.

The lab is intended for:
- Vision self-calibration;
- targeted ZoomText/SuperNova mechanism research;
- validation of assumptions about Windows magnification/accessibility implementations.

It is not a parity or cloning programme.

## Default workflow

1. State one engineering question.
2. Freeze the exact binary/artifact hashes and environment.
3. Start with cheap evidence:
   - PE imports/headers;
   - strings and RTTI;
   - process/module inventory;
   - window styles;
   - controlled black-box behavior.
4. Use REA/Ghidra only after a concrete seed exists:
   - trace a string/API/behavioral clue;
   - identify xrefs/containing functions;
   - decompile only those functions.
5. Add ProcMon or ETW only if the question requires runtime timing, file/registry/service, or cross-process evidence.
6. Add debugger/TTD/Frida only if the decision logic remains unresolved.
7. Write conclusions as:
   - directly observed;
   - strongly inferred;
   - weakly inferred;
   - unknown.
8. Record implications for Vision separately from competitor implementation details.

## Local tools

Current Dell calibration stack:
- REA 6.3.0
- Ghidra 12.1.4
- Temurin JDK 21
- Sysinternals Suite

REA environment runner:
lab/automation-harness/run-rea-local.ps1

The runner reads JAVA_HOME and GHIDRA_INSTALL_DIR from current-user environment variables and resolves the globally installed REA package dynamically.

## Performance expectation

On the calibration Vision PE:
- fast static/runtime inventory: seconds;
- REA/Ghidra full deep query: roughly 3-5 minutes.

Therefore do not use REA full analysis as the first search engine for every question.

## Physical-display boundary

Virtual or one-screen environments are adequate for:
- static architecture;
- process/module topology;
- accessibility mechanisms;
- most targeted function tracing;
- settings/state mechanisms.

Real displays remain authoritative for:
- EDID/display identity;
- HDMI/DP hotplug;
- monitor sleep/wake;
- per-monitor hardware/DPI behavior;
- source-monitor crossing and ownership;
- final multi-monitor usability.

## Evidence safety

- preserve original binaries unchanged;
- keep raw binary/runtime captures out of normal git history;
- do not redistribute proprietary binaries or recovered proprietary code;
- prefer behavioral principles and Windows mechanisms over copying implementation;
- respect applicable license/legal constraints for third-party software.

## Calibration baseline

Detailed evidence:
artifacts/2026-10-10__gpt-5.6-sol__rea_vision_reconstruction_calibration_v0.1.md

The first calibration produced seven strong/exact answers, one partial answer, two explicit unknowns and no material high-confidence false claim.