# Vision geometry and magnification contract v0.1

Status: Batch 1 Gate 0B contract. This document defines rendering geometry only; it does not change runtime behaviour yet.

## Coordinate basis

Vision rendering geometry is defined in physical source pixels and physical destination pixels.

DPI/logical coordinates are converted explicitly at API boundaries. DPI scaling does not alter the meaning of magnification once physical source and destination rectangles are known.

## Magnification semantics

For destination size `Dw x Dh` and magnification `z`, the requested live source viewport is:

`(Dw / z) x (Dh / z)`

The source viewport preserves the destination aspect ratio and X/Y scale remains uniform.

At `1x`, one source pixel maps to one destination pixel where the source contains enough pixels to fill the destination.

If the requested viewport does not fit within the source, Vision reduces the viewport uniformly to fit the source and letterboxes/pillarboxes the unused destination area. It must not silently apply non-uniform stretching.

## Overview is separate

“Show the whole source” / overview is not another definition of 1x.

Overview fits the full source into the destination using a uniform scale and may letterbox/pillarbox.

## Clamping

The viewport is clamped within source physical bounds while preserving its size and aspect ratio.

A point of interest near a source edge therefore changes viewport position, not scale.

## Temporary normal / return

Under an unchanged compatible topology, returning from temporary 1x to the prior magnification restores the prior magnified crop exactly.

If topology/source geometry changed while in temporary normal mode, exact restoration may be impossible; the saved crop must be re-resolved and clamped deterministically.

## Topology changes

Source resize, rotation, monitor replacement or destination resize create a new geometry resolution problem. Old geometry must not be treated as valid merely because a view ID survived.

## Current compatibility rule

During the architecture extraction, the currently qualified matched-screen two-monitor behaviour remains the compatibility baseline. This contract is introduced behind pure tests before it is wired into runtime behaviour.

## Required test cases

- 1920x1080 -> 1920x1080 at 1x/2x/4x
- 1920x1080 -> 1280x720
- 1280x720 -> 1920x1080
- landscape source -> portrait destination
- partial destination
- negative virtual-desktop origins
- identical physical geometry under different DPI scaling
- point of interest near every edge
- source resize/re-clamp
- overview distinct from 1x
