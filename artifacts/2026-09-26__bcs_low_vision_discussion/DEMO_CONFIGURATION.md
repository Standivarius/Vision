# BCS demo configuration — Doxa + Visual

## Purpose

The purpose of the BCS demo is not to present a finished magnifier or compete feature-for-feature with ZoomText or SuperNova.

The purpose is to demonstrate one credible behaviour that already works, then introduce the multi-display low-vision hypothesis and learn whether BCS recognises a real workplace need for it.

## What is real today

Visual currently supports:

- 1x, 2x and 4x magnification;
- pointer tracking;
- text-caret tracking;
- keyboard-focus tracking;
- arbitration between pointer, caret and focus;
- comfort-margin viewport movement rather than constant recentering;
- temporary normal view and exact return to the previous magnified view;
- tracking on/off;
- a high-contrast locator on the magnified Detail output;
- global keyboard shortcuts;
- a primary source monitor and one full-screen Detail destination monitor.

The current monitor-selection mechanism is engineering-oriented. Persistent Doxa monitor roles and a user settings interface are not implemented yet.

## Recommended live demonstration

Use two displays for the actual working prototype, even if Doxa hardware is physically present.

### Screen A — source / context

The user works normally on this screen.

Use an application that makes the tracking behaviour obvious, for example Word, Outlook, a browser form, or a simple text editor.

### Screen B — Detail

Visual shows the magnified region at 2x initially.

Demonstrate this sequence:

1. Move the mouse deliberately across the source screen. Detail follows the pointer.
2. Stop moving the mouse. The view remains stable rather than continuously recentring.
3. Click into text and type. Detail returns to the live text caret.
4. Move the mouse elsewhere again. Pointer intent takes control.
5. Use temporary normal view and return to the previous magnified position.
6. Switch between 2x and 4x if useful to illustrate the loss-of-context problem as magnification rises.

The important explanation is not the technical implementation. It is:

> Visual tries to follow what the user is attending to, rather than forcing the user to manually manage the magnifier every time they move between mouse navigation and typing.

## The next concept to show as a mock-up, not as implemented functionality

### Context + Detail View indicator

The intended next behaviour is:

- Screen A stays at 1x and provides context.
- Screen B provides magnified Detail.
- Screen A shows a clearly visible rectangle representing the exact region currently enlarged on Screen B.

The indicator should use a strong outline and optional translucent fill rather than relying on a subtle grey region.

This should be described as a design concept under evaluation, not as a completed feature.

## Three-screen Doxa concept to discuss

Do not present a fixed final layout. Present three candidate roles:

- **Context** — whole workspace at 1x, with the Detail View indicator.
- **Detail** — high-magnification working view following pointer/caret/focus.
- **Reference** — stable information that should not disappear when attention moves elsewhere.

Examples of Reference content could include:

- a document while entering information into another application;
- a spreadsheet section while editing elsewhere;
- Teams or email while working on another task;
- a form, instructions, or comparison document.

The laptop screen can remain the user's ordinary work surface or later become a control/private/reference surface. That decision should be informed by user testing rather than fixed now.

## Features deliberately not presented as finished

Do not imply that Visual currently has:

- persistent Context/Detail/Reference monitor roles;
- a polished settings screen;
- 1.5x or 3x zoom;
- colour/contrast profiles;
- persistent user profiles;
- freeze/reference regions;
- assessor presets;
- screen-reader/speech capability.

These belong in the discussion about what is worth building for the first user pilot.

## The demo question

After showing the working pointer-to-caret transition, ask:

> Does this correspond to a problem you see in real low-vision work, and where would the user still struggle?

Then introduce Context + Detail and ask them to relate it to real tasks rather than rating the feature in isolation.
