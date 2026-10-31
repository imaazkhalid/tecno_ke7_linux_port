# Android UI rendering bottleneck — measured 2026-10-31

Measurements taken on the working rooted Android 10
(`KE7-H693HJKM-Q-GL-220729V478`) to establish *why* the UI feels sluggish, so an
Android 17 port can target the real cause instead of guessing.

## TL;DR

The bottleneck is **not** CPU, **not** GPU and **not** memory. It is the
**present/composition path**: frames reach the display at an effective **~30 Hz**
with present intervals alternating 16.7 ms / 33.4 ms, while the SoC is idle.

## Measurements

### Frame statistics (`dumpsys gfxinfo com.android.systemui`)

| Metric | Value |
|---|---|
| Janky frames | **56.6 %** (89.8 % during a shade open/close burst) |
| 50th percentile | 20 ms (46 ms during the burst) |
| 90th percentile | 57 ms |
| 99th percentile | 200 ms |

`com.android.settings` during a scroll: **98.5 % janky, 38 ms median** — so this
is the whole UI, not one app.

### Per-frame phases (`dumpsys gfxinfo … framestats`)

| Phase | Median |
|---|---|
| traversal → draw (CPU) | 1.2 ms |
| sync / upload | 0.8 ms |
| **draw → swap** | **22.8 ms** |
| total vsync → done | 66.0 ms |

CPU draw work is negligible; the time disappears between issuing draw commands
and swapping buffers, i.e. waiting on the display pipeline.

### Clock pinning experiments (both negative)

| Experiment | Result |
|---|---|
| All 8 CPUs pinned to max (`scaling_min_freq = cpuinfo_max_freq`) | 87.5 % janky, 38 ms median — **no change** |
| GPU pinned to OPP 0, verified `real clock freq = 823011` during animation | 88.1 % janky, 40 ms median — **no change** |

So neither CPU frequency nor GPU frequency is the limiter.

### Memory

- `/proc/pressure/memory`: `some avg10=0.00  full avg10=0.00` — no pressure.
- 3.8 GB RAM, ~210 MB free + 2 GB swap with only 42 MB used — not thrashing.

### SurfaceFlinger counters

```
Total missed frame count: 3993
HWC missed frame count:   3993     <- the display path misses
GPU missed frame count:    229     <- GPU is basically fine
```

Display reports `720x1640 @ 60.0 fps`, `appVsyncOffset 8.3 ms`,
`presDeadline 9.37 ms`.

### Actual present cadence (the key measurement)

`dumpsys SurfaceFlinger --latency StatusBar#0` during shade animation:

```
present intervals: 16 ms -> 17 frames
                   33 ms -> 19 frames   (plus a few 50/167 ms)
median 33.36 ms  =>  effective 30.0 Hz
```

Half the frames land perfectly on vsync, half land one vsync late. The pipeline
*can* do 60 Hz, but it delivers roughly every second frame.

## Interpretation

- The "touch pointer feels smooth" observation is consistent: pointer updates are
  input-driven and land on whichever vsync is near, so they feel continuous even
  when the cadence is 30 Hz. Animations with strict frame pacing expose the
  halving.
- App-side rendering is fast (1–2 ms), so this is not a Skia/GPU throughput
  problem.
- The alternation 16.7 / 33.4 ms is characteristic of a **display/DSI present
  path issue**, not of application jank: something is consuming or delaying
  every other frame before it reaches the panel.

## What to do in an Android 17 port

1. **Measure first, with the same commands.** If `--latency` shows 16.7/33.4
   alternation, it is the display path — do not tune governors.
2. Panel/DSI bring-up matters more than SoC performance:
   - correct video vs command mode,
   - correct porches/pixel clock so the panel really runs at 60 Hz,
   - TE (tear effect) / vsync source wired correctly,
   - `appVsyncOffset` / `presentDeadline` matching the panel.
3. Check the MTK display driver (DISP/DSI/CMDQ) configuration — the CMDQ path is
   the usual suspect for every-second-frame delivery.
4. Only after the cadence is a clean 16.7 ms should CPU/GPU governors be tuned.

## Commands used

```bash
adb shell dumpsys gfxinfo com.android.systemui
adb shell dumpsys gfxinfo com.android.systemui reset
adb shell dumpsys gfxinfo com.android.systemui framestats
adb shell dumpsys SurfaceFlinger | grep -iE 'missed|composition'
adb shell dumpsys SurfaceFlinger --latency-clear
adb shell dumpsys SurfaceFlinger --latency 'StatusBar#0'
adb shell cmd statusbar expand-notifications   # / collapse
adb shell su -c 'cat /proc/gpufreq/gpufreq_var_dump'   # real GPU clock
adb shell su -c 'echo 823000 > /proc/gpufreq/gpufreq_opp_freq'   # pin, 0 = auto
```
