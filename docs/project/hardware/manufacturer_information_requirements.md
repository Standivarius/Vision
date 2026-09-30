# Doxa manufacturer information requirements

## Purpose

Before Doxa defines a production installer or support process, obtain authoritative information from the hardware manufacturer/OEM. The objective is to remove guesswork about controller families, firmware, driver ownership, factory programming and field recovery.

## 1. Complete hardware identity

Request the exact production BOM for every hardware revision relevant to Doxa, including:

- main controller/SoC part number;
- USB display controller/GPU part number;
- USB hub controller;
- USB-C Power Delivery controller;
- HDMI bridge/switch/redriver parts where present;
- audio codec/controller;
- Ethernet/controller if any;
- USB audio/network/hub class devices if integrated;
- EEPROM/flash devices used for firmware/configuration;
- board/PCB revision identifiers;
- panel/controller revision dependencies;
- cable/connector requirements.

Do not accept only a marketing block diagram if support behavior depends on specific components.

## 2. USB and Windows identity

Request the production USB descriptors and Windows-visible identities:

- USB VID/PID for each exposed function;
- interface/subclass/protocol values;
- composite-device layout;
- serial-number behavior;
- Windows hardware IDs and compatible IDs;
- expected device classes;
- expected display adapters/monitors/audio endpoints in Device Manager;
- whether identifiers differ by firmware revision;
- whether identical Doxa units can be distinguished persistently.

This information is required for reliable installer detection, diagnostics and monitor identity.

## 3. Display architecture

Request:

- exact display-controller family and revision;
- number of displays driven per controller;
- maximum resolution/refresh combinations;
- transport used between laptop and display controller;
- bandwidth limits and fallback behavior;
- whether compression is used;
- whether display output is a Windows indirect/USB graphics path, DisplayPort Alt Mode, native GPU path, or a mixture;
- HDR/color-depth/color-space limits;
- rotation support;
- HDCP/protected-content constraints;
- sleep/wake and hot-plug behavior;
- known limitations when several external displays are active.

If Silicon Motion is used, request the exact SMI part number rather than only "Silicon Motion".

## 4. Firmware package

Request for every programmable device:

- current production firmware image;
- firmware version scheme;
- release notes/history;
- firmware update utility/API;
- unattended update method if available;
- rollback/recovery method;
- behavior after interrupted update;
- minimum power requirements while flashing;
- whether firmware is signed/authenticated;
- whether Doxa is allowed to redistribute firmware/updater;
- factory programming procedure;
- golden/recovery image;
- manufacturing configuration values unique to Doxa.

We should know exactly which firmware revision leaves the factory and how to recognize it from Windows.

## 5. Windows software/driver package

Request the complete supported Windows package, not just an end-user download link:

- exact product/family supported;
- current version;
- all INF/CAT/SYS/DLL/EXE/MSI files;
- digital-signing/WHQL status;
- publisher identity;
- silent install/uninstall switches;
- repair mode;
- rollback behavior;
- required reboot conditions;
- service/process names;
- registry/configuration locations;
- log locations;
- command-line diagnostics;
- crash dump/log collection instructions;
- release notes and known issues;
- Windows 10/11 build compatibility matrix;
- Windows Update distribution status;
- whether automatic update is performed by the vendor software;
- whether firmware update is included in the host software;
- license and Doxa redistribution rights.

If there are different packages (for example traditional Windows driver/MSI versus an InstantView-style application), request the intended deployment model for Doxa and the trade-offs.

## 6. Factory-installed content

Clarify what the factory can actually control.

The factory can normally control the Doxa hardware itself, for example:

- controller firmware;
- EEPROM/configuration;
- USB descriptors/identity;
- device serial numbers;
- onboard storage content if the design contains user-visible storage;
- EDID/configuration data;
- test/calibration data.

The hardware factory generally cannot "preinstall" software into an arbitrary future customer's Windows laptop. Host software normally reaches the PC through Windows Update, an installer downloaded/provided by Doxa, OEM deployment, or a vendor mechanism such as an onboard application workflow.

Request explicit confirmation if the hardware can expose/install/update host software automatically and how that mechanism is secured and updated.

## 7. Power/USB-C requirements

Request:

- USB-C port roles;
- USB PD source/sink role for each port;
- supported PD profiles/voltages/current;
- minimum recommended charger wattage;
- laptop charging pass-through limits;
- power budget available to displays/peripherals;
- behavior under insufficient power;
- cable requirements (USB generation, e-marking, current, video capability);
- whether data and charging paths differ by port;
- safe connection/disconnection sequence if any.

Power problems often present to users as intermittent USB/display failures, so this must be diagnosable rather than treated as generic "driver trouble".

## 8. Audio and other functions

If audio is present, request:

- controller/codec identity;
- whether it uses standard USB Audio Class or a vendor driver;
- expected playback/recording endpoints;
- jack-detection behavior;
- sample rates/channels;
- Windows default-device side effects;
- known interactions with sleep/reconnect.

Do the equivalent for Ethernet, cameras, card readers or other functions if present.

## 9. Manufacturing test and field diagnostics

Request the factory's own validation procedure and diagnostic tools:

- USB enumeration test;
- display-output test;
- firmware integrity/version check;
- PD/power test;
- audio test;
- per-port test;
- serial-number traceability;
- failure codes;
- RMA criteria;
- engineering logs unavailable to normal end users.

Ideally Doxa should be able to run a reduced version of the manufacturer's test logic in field support.

## 10. Support escalation package

Request named technical contacts and an escalation agreement covering:

- driver defects;
- firmware defects;
- Windows release compatibility;
- field failures;
- new firmware qualification;
- security advisories;
- source of authoritative release notes/downloads.

## 11. Distribution and ownership questions

Doxa must know who owns each update channel:

- hardware OEM;
- controller vendor (for example Silicon Motion);
- Doxa;
- Microsoft Windows Update.

Clarify:

- who signs the package;
- who publishes updates;
- who decides when firmware auto-updates;
- whether Doxa may pin/approve a version;
- whether Doxa can disable vendor auto-update for qualification;
- how urgent security/compatibility fixes are delivered.

## Minimum package before production installer work

At minimum, Doxa should have:

1. BOM/controller identities;
2. VID/PID/hardware-ID list;
3. shipping firmware version + update/recovery process;
4. supported signed Windows package + silent install/uninstall documentation;
5. redistribution/license permission;
6. Windows compatibility matrix;
7. power/cable specification;
8. known-issues/release-note history;
9. factory test procedure;
10. technical escalation contact.

Without these, the installer can be made to work on a test machine, but field support will remain unnecessarily fragile.
