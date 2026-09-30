# Incumbent magnifier research rig

This folder contains product-neutral tooling for black-box evaluation of Vision, ZoomText and SuperNova on the same Windows machine.

Principles:
- Observe normal documented product behaviour; do not decompile, patch, or bypass licensing.
- Use identical fixtures and input trajectories across products where possible.
- Keep source-side ground truth separate from magnifier-output observations.
- Record the whole virtual desktop so multi-monitor behaviour can be reviewed after a run.
- Store raw run evidence under lab/benchmarks/incumbent_research/runs/ and interpretation under artifacts/.
- Run only one magnifier product at a time.

Evidence captured by the rig:
- virtual desktop and display geometry;
- full-desktop video with native cursor;
- cursor position and foreground-window samples;
- Win32 caret rectangle when the foreground UI exposes one;
- product process working set, private bytes and CPU time;
- timestamped scenario events;
- environment/product metadata.

Controlled scenarios:
1. pointer_sweep - slow and fast pointer travel within the source display.
2. caret_navigation - deterministic text caret movement in a local editor fixture.
3. focus_navigation - deterministic Tab and Shift-Tab navigation across controls.
4. cross_monitor - pointer movement across the physical display boundary and back.
5. manual_feature - recorder only, for product-specific features such as Freeze View, Hooked Areas, zoom-window modes, reading modes and multi-monitor configuration.

Before an incumbent run, configure the product into the intended mode and record the setting in the run notes. Product-specific hotkey automation should only be added after the documented behaviour is verified manually.

Entry points:
- capture-research-baseline.ps1
- run-controlled-scenario.ps1
- run-observation.ps1

The Dell is the first physical bench. The harness is N-monitor aware; current physical validation is two displays. Three- and four-display runs will reuse the same evidence format when hardware is available.
