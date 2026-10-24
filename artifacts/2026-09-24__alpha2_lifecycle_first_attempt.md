# Visual alpha.2 lifecycle verification — first attempt

Date: 2026-09-24
Canonical workspace: `C:\dev\Visual`
Candidate: `0.1.0-alpha.2`

## Command

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\dev\Visual\app\packaging\verify-alpha2-install.ps1 -Version 0.1.0-alpha.2`

## Result

**FAIL before packaging or installation.**

The driver recorded the existing installed version as `0.1.0-alpha.1` at:

`%LOCALAPPDATA%\Standivarius.Visual\current\visual_app.exe`

Pinned Velopack 1.2.0 native SDK acquisition/configuration succeeded and CMake generated the Visual Release build for `0.1.0-alpha.2`.

`velopack_entry.cpp` compiled successfully against the pinned 1.2.0 SDK. This is direct compile evidence that the current native API use (`VelopackApp`, `GithubSource`, `UpdateManager`, update check/download/apply methods) is accepted by the pinned headers.

The build then failed at link with:

`LNK2019 unresolved external symbol ... VisualProductMain ... referenced in function wWinMain`

and `LNK1120: 1 unresolved externals`.

The linker diagnostic requested the C++-mangled `?VisualProductMain@@...` symbol while also hinting that an undecorated `VisualProductMain` symbol was defined.

## Root cause

`main.cpp` is compiled with the source-specific preprocessor definition:

`wWinMain=VisualProductMain`

That definition also renames the CRT/header declaration of `wWinMain`. The renamed implementation therefore carries the original entry-point declaration's C linkage and is emitted as undecorated `VisualProductMain`.

`velopack_entry.cpp` initially declared `VisualProductMain` with normal C++ linkage, so its call requested a mangled C++ symbol that could not match the defined C-linkage symbol.

## Correction applied

The wrapper declaration is now:

`extern "C" int WINAPI VisualProductMain(HINSTANCE instance, HINSTANCE previousInstance, PWSTR commandLine, int showCommand);`

No other lifecycle/update architecture change was required.

## Evidence preserved

- `artifacts/velopack_0.1.0-alpha.2_lifecycle_verification.log`
- `app/packaging/alpha2-candidate-verification.log`
- generated failed-build objects and MSVC/CMake logs under ignored `app/build/`

No Setup/install phase ran, so the installed alpha.1 was not replaced by this failed attempt.
