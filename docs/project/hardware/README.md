# Doxa hardware / installation baseline

This folder separates Doxa hardware, driver, firmware and deployment concerns from the Visual magnifier architecture.

## Current status

The exact Doxa bill of materials is **not yet verified in the repository**.

User-provided leads indicate that Doxa may expose:

- USB-C power;
- USB-C data;
- HDMI;
- audio I/O;
- a USB graphics/display solution believed to involve Silicon Motion.

Treat these as investigation leads until confirmed by:

- physical-device inspection;
- Windows PnP/USB/device metadata;
- installed driver packages;
- manufacturer BOM/specification;
- controller markings/firmware information;
- vendor documentation.

## Why this is separate from Visual

Visual should remain usable on normal Windows multi-monitor systems. Doxa hardware support adds:

- certified device identification;
- driver/software installation;
- firmware/version management;
- device health diagnostics;
- support/recovery workflows.

Those functions belong behind a hardware/diagnostic boundary, not inside capture/tracking/rendering logic.

## Files

- `manufacturer_information_requirements.md` — information and deliverables Doxa should obtain from the hardware manufacturer/OEM.
- `hardware_investigation_playbook.md` — what we can inspect ourselves once a Doxa unit is connected to the development PC.
- `installation_and_support_architecture.md` — proposed deterministic installer + diagnostics + optional cloud-LLM support design.

## Current external lead: Silicon Motion

Silicon Motion currently markets USB Display Interface SoCs including SM76x-family parts and SM770. Its public material states that SM770 supports up to three concurrent 4K60 displays and that InstantView software can manage USB display connectivity/firmware. Silicon Motion also publishes separate Windows driver/MSI packages for SM76x and SM77x families.

Relevant public sources:

- https://www.siliconmotion.com/products/USB-Display-Docking-SoC/detail
- https://www.siliconmotion.com/downloads/
- https://www.siliconmotion.com/downloads/SM770-drivers.html
- https://www.siliconmotion.com/events/instantview/

This does **not** establish that Doxa uses SM768, SM770 or any other specific Silicon Motion controller. Exact identification comes first.
