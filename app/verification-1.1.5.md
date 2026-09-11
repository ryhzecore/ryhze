# Ryhze 1.1.5 verification

## baseline

Windows profile build; 1898 x 1174 physical pixels, device pixel ratio 1.5. Three Cyberpunk 2077 gallery open/close cycles using native frame timing callbacks and a fully live frame policy.

| Cycle | Frames | Raster p95 (ms) | Raster maximum (ms) | Raster frames over 16.7ms |
|---|---:|---:|---:|---:|
| 1 | 180 | 9.00 | 21.16 | 1 |
| 2 | 146 | 25.82 | 53.10 | 12 |
| 3 | 180 | 7.78 | 9.86 | 0 |

## optimized

Windows profile build; 1898 x 1174 physical pixels, device pixel ratio 1.5. Three Cyberpunk 2077 gallery open/close cycles using native frame timing callbacks and a fully live frame policy.

| Cycle | Frames | Raster p95 (ms) | Raster maximum (ms) | Raster frames over 16.7ms |
|---|---:|---:|---:|---:|
| 1 | 78 | 5.05 | 6.09 | 0 |
| 2 | 57 | 5.44 | 5.98 | 0 |
| 3 | 71 | 4.46 | 7.15 | 0 |

These are measurements on this PC, not a guarantee for other hardware. The corrected native discovery returned the registered RACE runtime, version 0.1.0, build 1. Widget regression checks cover continuous frame identity, local discovery while online checks wait, missing-engine visibility, refresh, and stale-path fallback.
