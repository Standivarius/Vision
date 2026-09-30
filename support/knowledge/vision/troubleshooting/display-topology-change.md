# Troubleshooting: Vision stopped after a monitor/display change

## Symptom

Vision closes after an HDMI/USB-C display is disconnected, reconnected, enabled/disabled, or Windows otherwise changes active display topology.

## Current alpha behavior

This can be intentional. The current alpha treats a display-topology invalidation as a reason to stop safely rather than continue rendering against stale monitor/capture assumptions.

## Safe recovery

1. Confirm Windows has restored the intended active displays.
2. Wait until the desktop has finished rearranging.
3. Relaunch Vision.
4. If Vision starts and the Detail display renders normally, no repair action is required.

## If relaunch fails

Create a Vision diagnostics report and check:

- active monitor count;
- monitor bounds and resolution;
- Windows build;
- GPU adapter presence;
- Vision version.

Escalate if Windows sees the intended displays but Vision repeatedly cannot launch or immediately exits.

## Do not

- reinstall graphics/display drivers solely because Vision exited on a topology change;
- modify firmware;
- disable Windows display/security services;
- assume an HDMI/USB-C hardware fault without Windows-level evidence.
