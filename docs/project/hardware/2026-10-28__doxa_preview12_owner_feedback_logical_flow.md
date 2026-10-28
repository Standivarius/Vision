# Doxa Setup Preview.12 â€” owner feedback / logical task-flow correction

28 October 2026. Engineering candidate. Read-only hardware UI; no vendor driver change, Windows display-topology write or tenant deployment.

## Why the UX changed
Preview.11 repeated primary navigation as bottom buttons and a second Connect Doxa subtab, showed Windows display settings too early, replaced Doxa Help with static guidance on some pages and occupied the chatbot column with wide primary tabs. Owner feedback required an installation flow based on actual dependencies, not repeated sections.

## Main tasks and their order
1. Detect Doxa: FIRST show two rear-centre-panel USB-C sockets: upper POWER, lower DATA/SIGNAL. Then provide the single **Check connection** action and individual Windows-PnP identity indicators for Screens 2, 3 and 4. Green checks mean the specific named Doxa monitor is enumerated in Windows with matching SMI770 device evidence; they DO NOT prove independently extended displays.
2. Set up screens: AFTER connection/detection, show the physical 2-3-4 row with laptop Screen 1 below central Screen 3, instructions for Windows Identify and Extend, and the **one** Open Windows Display settings action. No cable instructions here.
3. Install signed driver: a conditional troubleshooting reference only if detection suggests a missing/unverified driver. In the unsigned preview it is read-only and cannot elevate, uninstall or reinstall a driver.

## Layout hierarchy
- Standivarius brand logo; noticeably larger Doxa product title and small Setup descriptor.
- Three primary task tabs restricted to the LEFT workspace; burgundy active-state attached to the left-column frame.
- NO bottom navigation duplicate and NO secondary connection/arrangement tabs.
- Doxa Help is a persistent chatbot on the RIGHT on all three task screens, with offline/online consent and reachable privacy notice.
- USB-C drawing uses rounded-rectangle receptacles with metallic outline and inner tongue rather than circular holes; top = POWER, bottom = DATA.
- English/Romanian strings in new primary UI; narrow screens stack the independent help panel beneath the workspace with vertical scrolling.

## Verification requirements
- Source parser for main, guide and task UI; BrandTest checks tabs within left bounds, persistent chatbot, no duplicated nav, Setup-only Settings action, individual screen identities including missing and test-only suppression, bilingual switching, consent reversal and no active driver installer.
- Wizard SeamlessTest in both languages traverses actual Preview.12 tabs with unchanged HWND.
- Extracted personal ZIP integrity and journey acceptance; managed app-only package lifecycle tests with no driver payload and no real endpoint assignment.
- Owner's visual review on physical Dell hardware at 100/125/150% DPI and keyboard navigation is still needed. PnP check marks are not evidence of display topology.

## Security/operational limits
This remains an unsigned app-only preview. It has NO OEM MSI, complete elevated vendor-driver installation, rollback/recovery mechanism or production release signature. The earlier Preview.11 enterprise app-only wrapper versioned install/detect/upgrade contract remains the underlying deployment mechanism. No real Intune/ManageEngine deployment in this correction.
## Verified final candidate artifacts (28 October 2026)
- Personal app-only Preview.12: extracted package PASS, 20 hashed source files and 23 total archive entries; English/Romanian genuine same-window navigation PASS; no vendor driver or credentials. SHA-256 `C88DFEF2700D18C6E82F6144474E2DDDDBF41DC8306F2F8599C0FAE7F79E60A7`.
- ManageEngine-ready app-only package: LOCAL_PASS, 18 isolated managed lifecycle checks, 20 source files and 23 application entries, 2 distribution files; no device/tenant deployment. SHA-256 `1B9868B0A87EA4DEAFCAC1D64A090CD4C2514B3B66B069EF49A35646E1825DA9`.
- A rendered image of the actual Preview.12 Forms controls was inspected locally. No user hardware driver removal/reinstallation or display changes occurred.