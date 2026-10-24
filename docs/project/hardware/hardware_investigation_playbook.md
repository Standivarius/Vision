# Doxa hardware investigation playbook

## Purpose

When a Doxa unit is physically connected to the development PC, use this playbook to build an evidence-based hardware/software model before changing drivers, firmware or configuration.

The first pass should be read-only wherever possible.

## Phase 1 — baseline before connection

Capture:

- Windows edition/build;
- laptop model;
- CPU/GPU(s);
- current display topology;
- current display adapters and drivers;
- current USB controllers/hubs;
- existing Silicon Motion or other USB-display software/packages;
- current audio/network devices relevant to docking;
- Windows Update state where relevant.

This baseline lets us distinguish pre-existing software from what Doxa introduces.

## Phase 2 — physical connection inventory

Record the actual connection path:

- Doxa hardware revision/serial labels;
- which Doxa port connects to laptop;
- USB-C cable used;
- power supply/charger used and rated wattage;
- HDMI connections;
- external peripherals attached;
- laptop port used;
- whether laptop power delivery occurs through Doxa.

Photographs of labels/ports/PCB controller markings can materially reduce ambiguity if available.

## Phase 3 — Windows PnP/USB enumeration

Collect the device tree and compare before/after connection.

Useful built-in or Microsoft-supported sources include:

- PowerShell `Get-PnpDevice` / `Get-PnpDeviceProperty`;
- `pnputil /enum-devices /connected`;
- `pnputil /enum-drivers`;
- Device Manager metadata;
- display adapter/monitor PnP IDs;
- USB composite/interface IDs;
- service/driver bindings;
- `Win32_PnPEntity` / CIM where useful.

Capture:

- instance IDs;
- hardware IDs;
- compatible IDs;
- manufacturer/provider;
- device class;
- driver INF name;
- driver version/date;
- service name;
- status/problem code;
- parent/child relationships where available.

These identifiers are normally enough to establish the actual controller vendor/family without guessing from marketing language.

## Phase 4 — driver package inspection

For every Doxa-related driver package:

- identify the published INF (`oemXX.inf`);
- export/copy the package for offline inspection using supported Windows tooling where appropriate;
- inspect INF metadata, supported hardware IDs and services;
- inspect catalog/signature/provider/version;
- identify installed binaries/services/processes;
- identify MSI/product package if present;
- record install/uninstall/repair behavior.

Do not edit or re-sign vendor packages during the evidence pass.

Windows stores installable driver packages in the Driver Store; only properly staged packages are installed onto devices. SetupAPI device-install logs are available in `%SystemRoot%\inf\SetupAPI.dev.log` and are a primary source for diagnosing driver-selection/install failures.

Microsoft references:

- https://learn.microsoft.com/en-us/windows-hardware/drivers/install/driver-store
- https://learn.microsoft.com/en-us/windows-hardware/drivers/install/setupapi-text-logs

## Phase 5 — display-path inventory

Capture:

- all active Windows displays;
- virtual-desktop rectangles;
- primary status;
- resolution;
- refresh rate;
- orientation;
- DPI/scaling;
- display adapter/path association;
- EDID/monitor identifiers where available;
- whether displays disappear/reappear as a group;
- behavior when one external display is disconnected;
- behavior on sleep/wake and dock/undock.

Later compare this topology to Visual/WGC behavior.

## Phase 6 — USB bandwidth and topology

Determine whether the Doxa functions sit behind:

- one composite device;
- an internal USB hub;
- several controllers;
- USB 2.x versus SuperSpeed links;
- a native GPU Alt Mode path plus USB graphics path;
- multiple independent USB graphics devices.

Use Windows USB topology information and, if needed, Microsoft/Windows SDK USB inspection tools.

This matters for explaining bandwidth, disconnects and performance under four-screen load.

## Phase 7 — power-delivery behavior

Observe safely:

- whether laptop charges through Doxa;
- negotiated power where software/firmware exposes it;
- behavior with/without external power;
- behavior under different approved cables/chargers;
- whether displays or peripherals disappear under insufficient power.

Do not infer electrical safety limits from software observations; rely on OEM specifications for supported PD profiles and power budgets.

## Phase 8 — audio/network/other endpoints

Inventory any new:

- playback endpoints;
- microphone/recording endpoints;
- Ethernet adapters;
- cameras;
- card readers;
- HID/control interfaces.

Record whether Windows changes default audio/network behavior when Doxa connects.

## Phase 9 — firmware/software updater behavior

If vendor software is installed, determine:

- whether it checks for host-software updates;
- whether it checks device firmware;
- firmware version exposed before/after update;
- whether update can be deferred/controlled;
- logs/status codes;
- recovery behavior after failure.

Do not perform firmware updates until the exact device/controller is identified and a recovery path is known.

## Phase 10 — controlled failure/recovery tests

After the baseline is understood, test deliberately:

- disconnect/reconnect laptop cable;
- disconnect/reconnect one display;
- power cycle Doxa;
- sleep/wake laptop;
- reboot with Doxa connected/disconnected;
- change Windows primary monitor;
- change orientation/scaling;
- restart approved vendor service/software;
- driver repair/reinstall only after package/recovery evidence exists.

Every change should have before/after evidence.

## What we can learn without manufacturer cooperation

Once the device is connected, we can usually establish a great deal from Windows and installed packages:

- USB vendor/product IDs;
- device classes/interfaces;
- controller vendor/provider clues;
- actual driver INF/provider/version;
- package signatures;
- installed services/processes;
- display topology/adapter mapping;
- firmware version strings if exposed;
- updater behavior/logs;
- device problem codes;
- install history from SetupAPI logs;
- failure/recovery behavior;
- CPU/GPU/capture implications for Visual.

We can also inspect publicly distributed driver packages and vendor documentation.

## What may remain impossible or inappropriate to infer

Without vendor documentation we may not reliably know:

- internal board BOM/revisions;
- private firmware protocol;
- firmware source/implementation;
- proprietary compression implementation;
- factory programming/calibration values;
- hidden engineering diagnostics;
- electrical/power limits not exposed by software;
- redistribution/licensing rights.

Do not reverse-engineer proprietary firmware/source merely because the device is physically available. Prefer vendor specifications, public interfaces and observable behavior.

## Output of the first connected-device investigation

Create a dated artifact containing:

- physical setup;
- full PnP/USB/display inventory;
- driver/software packages;
- likely controller family with evidence;
- firmware/updater evidence;
- power/audio/network observations;
- unresolved manufacturer questions;
- installer/support implications;
- Visual capture/render implications.

That artifact becomes the evidence basis for updating this hardware baseline and the production installer plan.
