# DOXA SM770 — Final assistive-technology performance report

**Version:** 2.0 | **Decision date:** 13 November 2026 | **Host:** MARIUS-DELL | **Programme verdict: PERFORMANCE CHARACTERISATION COMPLETE**

## Executive result

The sustained benchmark, technical root-cause investigation and reversible ZoomText settings comparison are complete. **ZoomText 2027 creates substantial additional CPU load with the three SM770-powered Doxa screens on this Dell.** Functional compatibility passes, but this particular Dell/ZoomText combination is **not cleared for an unconditional sustained-performance claim**.

Extra CPU activity concentrates in the Silicon Motion indirect-display host and Windows compositor. Windows GPU-event tracing identifies excessive allocation and paging operations when ZoomText magnifies animated content. The expensive subsystem is identified; proprietary vendor blame is not.

The vendor's **Best Performance** preference demonstrably lowers the combined measured CPU of four tracked processes but shifts more work into ZoomText. It may affect fine-text rendering. We therefore close the investigation with a documented performance warning, not an unproven fix.

## Rig and measurement contract

Dell Latitude 5410, Intel Core i5-10310U (four cores/eight logical processors), Intel UHD graphics, approximately 16 GB RAM; Windows 11 Pro Insider build 26340; ZoomText 2027.2610.327.400; signed SMI770 4.7.6.8001; native laptop plus three independent Doxa 1920 × 1080 screens.

The CPU values below are percentages of the **entire eight-logical-processor system capacity**. Four-process sums are **not whole-machine CPU**. Static and animated diagnostic fixtures were synthetic and no claim of all-day real-workload equivalence is made.

## Comparative sustained four-screen results

Earlier extended runs completed 20 phases each and retained 55 valid steady-state epochs:

| Environment | Mean whole-machine CPU | 95th percentile |
|---|---:|---:|
| Doxa without assistive technology | 13.68% | 29.2% |
| Doxa with Windows Magnifier | 14.73% | 30.5% |
| Doxa with NVDA | 17.31% | 33.0% |
| Doxa with ZoomText | **59.43%** | **97.9%** |

In a later dedicated **30-minute ZoomText 2027** trial, ZoomText remained present in 360/360 samples:

| Ten-minute phase | Mean whole-machine CPU | Maximum |
|---|---:|---:|
| Static | 61.3% | 100% |
| Laptop-only animation | 48.4% | 95% |
| Three Doxa screens animated | 57.5% | 100% |
| **Overall 30 minutes** | **55.7%** | **100%** |

Of the 360 samples, 32 reached at least 90% CPU and 16 reached 100%. A shorter unmatched ZoomText-OFF control had 10.4% CPU static and 16% animated. Those comparisons strongly motivate the diagnosis without defining a precise causal percentage attributable to ZoomText alone.

## Final repeated settings experiment (13 November)

One fresh Windows boot; a fixed four-display topology; ZoomText verified ON at **2×** before and after every accepted interval. Configuration order: **Text Quality → Best Performance → Text Quality → Best Performance**, with vendor restart per mode switch. Each of the eight validated intervals lasted 12 seconds. Animated fixture updates were nearly matched, approximately 11.6–11.8 per second.

| Setting and workload | SMI host CPU | DWM CPU | ZoomText CPU | Four tracked processes combined |
|---|---:|---:|---:|---:|
| Text Quality, static | 9.63% | 6.51% | 3.17% | **19.85%** |
| Best Performance, static | 0.23% | 0.01% | 12.53% | **12.98%** |
| Text Quality, animated | 9.47% | 6.80% | 4.61% | **22.66%** |
| Best Performance, animated | 7.27% | 3.04% | 7.35% | **18.47%** |

Best Performance reduced the four-process sum by **6.87 percentage points (about 35%) in static intervals** and **4.20 points (about 19%) during animation**. Both repeat pairs show reductions. Its static ZoomText process alone used approximately 12.5% of whole-machine CPU (one logical processor). It is a **workload redistribution plus net improvement** for the measured processes, not elimination of all rendering overhead.

The external camera confirmed large magnified words remained visible in each mode. A fine-font clarity and long-duration user-quality equivalence trial was **not part of this CPU experiment**. The Capture API setting was also tested separately and did not improve the animated overhead; its original OFF setting was restored.

## Observed graphics mechanism

In existing GPU ETW traces of matched one-second intervals with animated content:

| Operations initiated from the SM770 driver host | ZoomText closed | ZoomText ON |
|---|---:|---:|
| DeviceAllocation Start | 10 | **469** |
| PagingQueuePacket Start | 20 | **511** |

The 469 allocation starts occurred across **three Intel-GPU device objects** owned by the SMI host, so the evidence does not isolate a defective single Doxa output. Most notification handles had rapidly matched stop events, which does not establish a growing memory leak or a particular proprietary CreateTexture/DestroyTexture implementation. CPU sampling separately placed the hotspot in the SMIIddX770.dll module.

**Most plausible cause:** repeated graphics-resource allocation, residency and synchronisation work along the ZoomText capture/presentation → Windows GPU memory manager → SMI indirect-display path. We cannot establish from public traces whether ZoomText, Windows/Intel, Silicon Motion or their interaction is principally responsible.

A faster or newer laptop could have more headroom but is **not demonstrated to cure the inefficient path**. The separate ASUS inventory established native HDMI-reported monitors and no detected DisplayLink service; **ASUS was not used for ZoomText tests** and its different Windows build and graphics generation are not a matched control.

## Decision, ownership and restoration

- **Functional testing:** PASS, documented in the companion functional v2 report.
- **Performance investigation:** COMPLETE. The CPU saturation risk and graphics-operation category are characterised. This is **not approval of production-grade sustained ZoomText efficiency** on this old Dell.
- **Configuration:** preserve the installed signed driver. Best Performance may be offered as a deliberate user trade-off after optical/text-quality review; do not silently make it a default.
- **Action:** no more generic CPU loops, no speculative hardware purchase, no vendor contact or ETL sharing without a new owner decision.
- **Final machine state:** ZoomText and the fixture stopped, four displays active, Wi-Fi Up, no hardware change. Original ZoomText DisplayAdapter.ini SHA256 **DECF903BAE8EBE45535C6CDCDB46886BDE2B5D16E0487D45A19283733EEC706E** restored exactly.

## Preserved evidence

- artifacts/2026-11-09__doxa_zoomtext2027_30min/ — 360-sample sustained run and reference.
- artifacts/2026-11-13__zoomtext_trace_deep_analysis/ — Intel adapter/device and GPU allocation attribution.
- artifacts/2026-11-13__zoomtext_performance_closure/ — eight raw 12-second records, aggregate CSV/JSON, camera photos, original configuration and byte-exact restoration.
- lab/doxa-at-qualification/cases.json — final evidence and verdict catalogue.

This report supersedes the earlier performance conclusions in artifacts/2026-11-10__sm770_at_qualification_FINAL_v1.0.md and the 13 November performance closure v1.0 wherever later controlled evidence provides more precise findings. Original historical files are preserved.

**Final programme status: PERFORMANCE RESEARCH CLOSED WITH A DOCUMENTED ZOOMTEXT CPU CAPACITY WARNING.**

