# Visual Spike 1 — WGC → D3D11 Detail

Experimental code only. See `CHARTER.md` for the hypothesis/scope and `TEST_HARNESS.md` for automated testing.

## Build

```powershell
$cmake = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
& $cmake -S . -B build -G 'Visual Studio 17 2022' -A x64
& $cmake --build build --config Release
```

Or:

```powershell
.\build.ps1
```

## Manual run

```text
visual_spike1_wgc_detail.exe [--source N] [--dest N] [--zoom 2|4] [--log path.csv] [--single-monitor]
```

With 2+ displays, defaults are primary source and first non-primary destination.

With one display, the executable automatically uses a windowed single-monitor development mode and attempts to exclude the Detail window from WGC capture to avoid recursive feedback.

Press `2` or `4` to change zoom. Press `Esc` to exit.

## Automated run

Fast smoke run:

```powershell
.\run-automated.ps1 -DurationSeconds 20 -ForceSingleMonitor
```

Recorded diagnostic run:

```powershell
.\run-automated.ps1 -DurationSeconds 60 -ForceSingleMonitor -Record
```

Later, with two monitors attached:

```powershell
.\run-automated.ps1 -DurationSeconds 180 -Record
```

The harness creates a timestamped run bundle containing environment metadata, scenario events, Visual telemetry, a manifest, automated analysis, and optionally an MP4 recording.

Raw run bundles are stored under `lab/benchmarks/spike1_wgc_d3d11_detail/runs/` and are Git-ignored.
