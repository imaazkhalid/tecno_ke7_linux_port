# Magisk modules for the Tecno KE7

## ke7_vsync_fix — restores 60 Hz UI vsync

**Symptom:** UI animations (notification shade, transitions) run at ~30 fps while CPU
and GPU are idle; touch pointer and video feel fine.

**Cause:** `/vendor/build.prop:409` sets `debug.sf.disable_backpressure=1`.
With it, SurfaceFlinger's DispSync delivers `VSYNC-app` only every second frame:

```
DispSync: VSYNC-app  median 33.44 ms  -> 29.9 Hz
Choreographer#doFrame median 33.48 ms  -> 29.9 Hz
while DrawFrame work = 0.53 ms, dequeueBuffer = 0.63 ms
```

Setting the prop to `0` gives `VSYNC-app` every 16.7 ms and `Choreographer#doFrame`
at 60.5–60.7 Hz.

**Install** (rooted, Magisk):

```bash
adb push ke7_vsync_fix /data/local/tmp/
adb shell su -c 'cp -r /data/local/tmp/ke7_vsync_fix /data/adb/modules/ && chmod 755 /data/adb/modules/ke7_vsync_fix/post-fs-data.sh'
adb reboot
adb shell getprop debug.sf.disable_backpressure   # expect 0
```

**Verify:**

```bash
adb shell su -c 'atrace -t 4 -b 20000 gfx view sched -a com.android.systemui' > trace.txt
# then: median interval of "Choreographer#doFrame" should be ~16.7 ms
```

**Remove:** `adb shell su -c 'rm -rf /data/adb/modules/ke7_vsync_fix'` then reboot.
