# MEMORY — read this first

One-page operational memory. Detailed narrative lives in `docs/`; this file is the
"where are we, what boots, where are the backups, what to do next" sheet.

**Update after every meaningful step, then commit immediately** —
`git add MEMORY.md && git commit -m "<what changed and why>"`.
An uncommitted note is lost work. Permanent facts (tool paths, partitions, USB IDs,
hard rules) belong in `/home/mk/AGENTS.md` §3 instead, which is loaded every session.

**Last updated:** 2026-10-31 19:41 — Android restored and verified rooted; Linux port parked (see box below).


> **DIRECTION CHANGE (2026-10-31 19:40):** the Linux port is **parked, not abandoned**.
> Decision: Android is the target again, with the goal of **porting a newer Android**
> to this phone. All Linux artifacts stay on disk and verified
> (`backup/arch_state_20261025/`: rootfs.tar.zst 673 pkgs, esp.tar.zst, all raw
> partitions; `u-boot/` source tree; LK/U-Boot findings in §3.5-§3.6). Do not delete
> them. Do not resume the Linux boot-chain work unless the user asks.
> Android is restored from `backup/known-good-rooted-20261031-124522/`
> (boot/recovery/vbmeta×3/misc) — that state is verified working, rooted, data intact.
---

## 1. Current state

| Item | Value |
|---|---|
| Device | Tecno Spark 6 KE7, MT6768 |
| Android | retail `KE7-H693HJKM-Q-GL-220729V478`, **rooted (Magisk 27)**, working |
| Root | `adb shell su -c id` → `uid=0` (Magisk) |
| Linux | Arch ARM on SD card (1 GB FAT16 `BOOT` + 13.6 GB ext4 `KE7ROOT`) |
| SD rootfs | PARTUUID `30d61490-6ca8-4f0c-9016-c5259867fcb3` |
| Internal ESP | p40 intact: kernel, initramfs, DTBs, systemd-boot |
| Internal rootfs | p43 is now Android `/data` — old Arch rootfs there is gone |
| LK | **stock retail 2022 `f977f6ef…`** (restored 19:40) — Android boot set |
| dtbo | **Android** `68023` (`backup/dtbo_android_20261031.bin`) — saved 19:03 |
| Android check | 19:40:21 adb OK — build `KE7-H693HJKM-Q-GL-220729V478`, `orange`, `su`→`uid=0` (Magisk), `/data` 11 GB used |
| boot | **Android kernel** (known-good-rooted) — Linux U-Boot not flashed |
| vbmeta | **stock AVB** `SHA256_RSA2048, Flags 0` — verification enabled again |
| adb | `./platform-tools/adb` (in-repo; `/tmp/opencode/platform-tools` is lost on reboot) |
| Linux status | **does not boot** — blocked at LK `fdt_op.c:855` DTB assert, see §3.5 |

## 2. Backups (all on the laptop, verified)

| Path | Contents |
|---|---|
| `backup/arch_state_20261025/` | **the Linux port**: GPT, p1–p36/p40/p41/p42 raw, boot0/boot1, `rootfs.tar.zst` (2.4 GB → 673 packages, full Arch + Phosh + home), `esp.tar.zst` (50 MB) |
| `backup/known-good-rooted-20261031-124522/` | rooted Android: boot/recovery/vbmeta*/misc/seccfg/boot_para/proinfo/NV/protect + SHA-256 |
| `backup/android-full-20261031-132104/` | in progress: `super.img.zst`, `userdata.img.zst`, small partitions |
| `tools/save-state.sh` | snapshot before **every** write |
| `tools/backup-android-full.sh` | full Android one-flash restore set |

## 3. Boot chain facts (hard-won)

```
preloader (eMMC boot0) → LK (p27/p28) → U-Boot (p30) → systemd-boot (p40 ESP) → Linux
```

- **LK matters.** There are three different LKs:
  - current `b5e46508…` — rejects rebuilt U-Boot images
  - port-era `732445a1…` (in `arch_state/mmcblk0p27.bin`) — **the one that booted U-Boot**
  - stock `f977f6ef…`
- **AVB has two layers**: `vbmeta` partition + per-image `AVBf` footer.
  - stock vbmeta chains `boot` to vendor key `9d808b…`
  - Magisk boots because it **keeps the vendor-signed footer**; LK skips image hash
  - rebuilt images with `avbtool --algorithm NONE` were rejected anyway
- **`fastboot boot` is a no-op** on this LK (prints OKAY, never executes).
- **The `recovery` slot cannot host U-Boot** (different LK handoff).
- **gzip header must match**: `1f 8b 08 00 00 00 00 00 02 ff` (`gzip -9 -n`, OS byte patched to `ff`).
- U-Boot known-good payload: `arch_state/mmcblk0p30.bin` (gzip 329,690 B, ramdisk 796,063 B,
  decompresses to 700,576 B). Its env `bootcmd` loads `mmc 0:28`, which is **stale**
  (ESP is p40 in the current GPT).

### 3.1 The boot set is ATOMIC — never flash it partially

The Linux boot set is **six partitions that only work together**:

| # | Partition | Image | Must match |
|---|---|---|---|
| 1 | `lk` (p27) | `arch_state/mmcblk0p27.bin` | port-era `732445a1…` |
| 2 | `lk2` (p28) | `arch_state/mmcblk0p28.bin` | port-era |
| 3 | `boot` (p30) | `arch_state/mmcblk0p30.bin` | known-good U-Boot |
| 4 | `vbmeta` (p34) | `arch_state/mmcblk0p34.bin` | `Algorithm NONE, Flags 3` |
| 5 | `vbmeta_system` (p35) | `arch_state/mmcblk0p35.bin` | `Algorithm NONE, Flags 3` |
| 6 | `vbmeta_vendor` (p36) | `arch_state/mmcblk0p36.bin` | `Algorithm NONE, Flags 3` |

- **Flashing any subset = reset loop.** LK validates `boot` against `vbmeta`; a port-era
  LK/U-Boot with stock AVB vbmeta loops in preloader (`0e8d:2000`, ~2 s, repeat, black
  screen — looks dead but is alive).
- **The inverse is also true:** restoring Android must write its own
  `boot`+`recovery`+`vbmeta`+`vbmeta_system`+`vbmeta_vendor`+`misc` together, which
  *destroys the Linux boot set*. Keep a separate copy of the six port partitions so a
  round-trip never requires guessing.
- **Cross-switching is a 6-partition write, both directions.** Treat "boot Android" and
  "boot Linux" as two atomic bundles, never as individual partitions.
- **Symptom → cause table:**

| Symptom | Cause |
|---|---|
| black screen, `0e8d:2000` every ~2 s | vbmeta/LK mismatch (AVB reject) |
| orange/logo loop | LK rejected `boot` image itself |
| `0e8d:0003` stays | BROM, waiting for DA — safe to flash |
| nothing on USB at all | phone off / flat battery / bad cable |

### 3.2 Failure signatures — read this before touching anything

**If the host log shows `error -71` / `device descriptor read/64` / `unable to enumerate`
and no `idVendor=0e8d`, no tool can help.** The phone never finished USB enumeration,
so there is no `/dev/bus/usb` node for mtkclient to open. Observed 2026-10-31 17:00-17:20.

What the phases mean (measured that day):

| Preloader USB window | Cause | Result |
|---|---|---|
| ~25 s | battery low, preloader parks in charge mode | enumerates cleanly |
| ~3 s | battery charged, phone actually tries to boot | descriptor reads fail `-71`, reset loop |

So a **charged phone enumerates *worse* than a low one** — it tries to boot and dies
faster. Do not read `-71` as "listener bug" or "damaged hardware": a successful
480 Mbps chirp (`new high-speed USB device`) already proves the PHY and D+/D- work.

**Escape is the BROM strap, not a better listener:**
1. unplug, hold **Power 15 s** (force off),
2. hold **Volume Up** (or Vol Up + Vol Down),
3. plug in, hold ~3 s, release.

BROM then waits indefinitely — no window to miss. Confirmed working 2026-10-31 17:20:
`Preloader - BROM mode detected` → `DAA_SIG_VERIFY_FAILED` (normal, patched) →
`Kamakiri Run` → `DA sync` → writes.

Reading `/sys/.../idVendor` and `journalctl` **cannot** reset the phone. Only
mtkclient opening the device can. If a reset loop persists with everything killed,
it is the phone, not the tooling.

### 3.3 The USB/SoC latch — battery pull is the only clear

Confirmed 2026-10-31 17:19. After the failed flashes the phone sat in a latched state:
it pulled up USB (high-speed chirp OK) but died at the first descriptor read, every
time, with **nothing** running on the host. No button combination, no listener design,
and no cable change affected it.

**Opening the phone, disconnecting the battery, reconnecting it, then plugging the
USB cable in with NO buttons held → instant `0e8d:2000` then `0e8d:0003`, and the
flash went through on the first attempt.**

So before concluding "cable" or "hardware damage", and before burning hours on
listener redesigns: **pull the battery.** It is a two-minute fix and it was the actual
root cause both times the phone appeared unreachable. Document this before touching
any tooling.

### 3.4 U-Boot bootcmd is compiled in — there is NO env partition

The `boot` partition (p30) is an Android boot image whose `kernel` field is a gzipped
U-Boot. Its `bootcmd` is **compiled in**; the GPT has no `uboot_env`, and the payload
has no `saveenv`. So changing boot behaviour means flashing a different U-Boot image —
`setenv`/`saveenv` on the phone is not an option.

Three different U-Boot payloads exist in the repo root, all packaged as 32 MiB
`ANDROID!` images with page=2048, kaddr=0x40080000, raddr=0x47c80000, ramdisk 796063:

| Image | bootcmd target | Use |
|---|---|---|
| `arch_state/mmcblk0p30.bin` | `mmc 0:28` `/Image.mainline`, root=/dev/mmcblk0p43 | **STALE** — p28 is `lk2`, p43 is Android `/data` |
| `u-boot-boot.img` | `mmc 0:40 /EFI/BOOT/BOOTAA64.EFI` → `bootefi` | **correct** — ESP *is* p40 → systemd-boot → arch.conf → SD |
| `u-boot-sd-nofooter.img` | `mmc 1:1` `/Image` + DTB, root=PARTUUID(SD) | direct-from-SD fallback, no systemd-boot |

The stale `mmc 0:28` was never going to boot the current layout: p28 has no filesystem,
so `load` fails and the board resets in a ~25 s loop with a black screen.

### 3.5 Why Linux does not boot (as of 2026-10-31 18:15)

**Goal (do not lose this):** U-Boot as the phone's UEFI, so distros are installed by
dropping files on the ESP — no rebuilding boot images, no reflashing. systemd-boot is
optional; **U-Boot is required.** Never "simplify" the chain by dropping it.

Both the port-era U-Boot and `u-boot-boot.img` produce, in LK's own log:

```
[2076] main dtb is not packed with valid fdt format!
[2076] panic: ASSERT at (app/mt_boot/fdt_op.c:855): main_dtb_addr
[12000] lk_wdt_dump -> LEDS off -> reset
```

LK: reads the 32 MB `boot` partition, reserves DTB @ `0x4bc80000` (512 KB),
kernel @ `0x40080000`, ramdisk @ `0x47c80000`, then fails the main-DTB check and
hangs in panic until its watchdog resets the phone (~12 s; ~25 s per full cycle).

Facts established:

**2026-10-31 18:20-18:45 — two root causes found by reading LK's own expdb log:**

1. **`dtbo` partition must match the LK build.** Android's restore left a `dtbo`
   (total_size **68023**) that does not match the 2020 LK's built-in DTB. LK then hits
   `ufdt_overlay_do_fixups(): Couldn't find 'flashlights_aw36515'` →
   `ufdt_apply_overlay() failed!` → `panic at lk_builtin_dtb.c:175`.
   Flashing the port-era `dtbo` (total_size **67007**, `arch_state/mmcblk0p31.bin`)
   fixed it — LK now shows the logo and reaches the boot-image stage.
   The Android dtbo is saved as `backup/dtbo_android_20261031.bin`.
2. **The 2020 LK and the 2022 LK want *different* dtb encodings in the boot image:**
   - 2022 LK (`86459a05b`, retail `lk.img` `f977f6ef`): rejects the boot image outright
     (`main dtb is not packed with valid fdt format`, fdt_op.c:855, tick ~2076).
   - 2020 LK (`3fac97d44`, `arch_state/mmcblk0p27.bin` = `732445a1`): gets past the
     overlay, but prints `can't find v2 dtb` when the dtb field holds the **DTBO
     wrapper** (`d7b7ab1e`) — **it requires a raw FDT (`d00dfeed`) there.**
   → `flash_images/uboot_boot_rawfdt.img`: `dtb_size=119923`, raw FDT at `0x113000`,
   kernel = U-Boot with its trailing control DTB **stripped** (326,840 B gz).
- The `dtb` field of retail stock images is a 64-byte DTBO table (`d7b7ab1e`) with the
  FDT at +0x40 — the 2022 LK accepts that, the 2020 LK does not.
- U-Boot payloads end with their own control DTB (`totalsize≈12104`); stock kernels
  have **no** appended FDT, and an appended one changes which path LK takes.
- **2026-10-31 18:50 — LK boot-image check CLEARED.** With `uboot_boot_rawfdt.img`
  (raw FDT at the dtb offset) the 2020 LK logs
  `[7113] kernel real kernel_sz=0x0004fcb8` (= 326,840, our stripped U-Boot) and runs
  to tick 7320 with **no** `can't find v2 dtb` and **no** `fdt_op.c:855` panic.
  The remaining failure is at/after U-Boot, not LK.
- Current test image: `flash_images/uboot_boot_ctrldtb.img` — kernel = stripped U-Boot,
  v2 dtb = **U-Boot's own control DTB** (12,088 B raw FDT), signed with avbtool.
- `flash_images/lk_patched.img` is **cosmetic only**: 100 bytes, exactly three UI
  strings blanked (`0x67FD0`, `0x98878`, `0x98888`). Not a functional patch.
- Static disassembly of `mmcblk0p27.bin` does **not** resolve string addresses
  (mixed ARM32/AArch64, self-relocating). Don't retry objdump; the expdb log is the
  reliable source of LK behaviour.

**Next time:** kill every mtkclient, power-cycle, wait 90 s untouched, *then* dump
`expdb` and check whether the newest LK session still hits fdt_op.c:855.

## 4. Recovery / flashing rules

- **Before any write:** `./tools/save-state.sh <label>`.
- **BROM entry:** phone off, hold **Volume Up**, plug USB. (Not both volume keys.)
- **`adb reboot` lands in BROM on this device** — a pre-armed mtkclient session catches it.
- **Exactly one USB poller allowed.** `fastboot devices`/a second watcher during a DA
  upload produces `Wrong magic` + disconnect.
- **Never leave mtkclient running while testing a boot.** mtkclient grabs the preloader
  the instant it appears and crashes it into BROM (`0e8d:2000` → `0e8d:0003` within ~1 s).
  The phone then never runs LK, `expdb` never changes, and every "boot test" silently
  becomes a BROM session. Symptom: two `expdb` dumps taken minutes apart are
  **byte-identical**, and the phone sits at `0e8d:0003` afterwards. Kill every mtkclient,
  power-cycle, wait ~90 s, *then* dump.
- Restore stock/rooted Android (BROM, single session) — **this wipes the Linux boot set**:
  ```
  ./mtk-venv/bin/python mtkclient/mtk.py multi \
    "w boot <backup>/boot.img;w recovery <backup>/recovery.img;w vbmeta <backup>/vbmeta.img;w misc /tmp/zero_misc.bin;reset"
  ```
- Switch **back to Linux** afterwards (one session, all six):
  ```
  B=backup/arch_state_20261025
  ./mtk-venv/bin/python mtkclient/mtk.py multi \
    "w lk $B/mmcblk0p27.bin;w lk2 $B/mmcblk0p28.bin;w boot $B/mmcblk0p30.bin;\
w vbmeta $B/mmcblk0p34.bin;w vbmeta_system $B/mmcblk0p35.bin;w vbmeta_vendor $B/mmcblk0p36.bin;reset"
  ```
- Partition map: p27 lk, p28 lk2, p30 boot, p40 esp, p43 rootfs(/data now).

## 5. What failed today (do not repeat)

- Rebuilding U-Boot and flashing to `boot` → orange-logo loop (AVB/LK).
- U-Boot in `recovery` → reset loop.
- `fastboot boot` of U-Boot → no execution.
- `avbtool add_hash_footer --algorithm NONE` and RSA-signed footer → still rejected.
- Clean gzip header alone → still rejected.
- Conclusion: the **LK currently on the phone** is the difference. Next test is the
  port-era LK + known-good p30, not another U-Boot rebuild.

## 6. Next steps (in order)

1. ~~Finish `backup/android-full-*`~~ — done, 14 GB, `zstd -t` OK.
2. ~~BROM: write port-era LK/lk2 + known-good boot + all three vbmeta~~ — **done
   2026-10-31 17:20**, all six partitions written and log-confirmed.
3. **Unplug / replug and boot** → U-Boot → systemd-boot (ESP p40) → kernel + SD rootfs.
   Expect `0e8d:2000` → `1d6b:0104` (Linux gadget), then `ping 172.16.42.2`.
4. If Linux works: verify kernel, rootfs (673 pkgs), ssh, `dmesg` over USB.
5. If it does not boot: the boot set is no longer the suspect (all six match) — get a
   serial/UART log or check the U-Boot env `bootcmd` (`mmc 0:28` is stale, ESP is p40).
   Do **not** rebuild boot images blindly; restore Android with `tools/boot-to-android.sh`.

## 7. Documentation map

- `docs/` curated guides · `docs/reference/` raw research log
- `docs/dual-boot.md` — SD dual-boot findings (AVB, gzip, BROM)
- `docs/hardware-matrix.md` — per-component driver status
- `PROJECT_STATUS.md` → moved to `docs/reference/project-log.md`

### 3.6 LK/U-Boot source findings (2026-10-31 19:40)

Upstream MTK LK source: `github.com/svoboda18/lk`
(`app/mt_boot/fdt_op.c`, `app/mt_boot/mt_boot.c`).

- `fdt_op.c:855` is `PAL_ASSERT(main_dtb_addr)` inside `dtb_overlay()` — it fires
  only when the main DTB pointer is NULL.
- `bldr_load_dtb_from_boot()`: for `header_version >= 2` it requires
  **`dtb_size != 0`**; if 0 it prints `can't find v2 dtb` and returns -1.
  It accepts **either** a `DT_TABLE` (mkdtimg wrapper, `d7b7ab1e`) **or** a raw FDT
  (`d00dfeed`) at the dtb offset.
- `boot_linux_fdt()`: for 64-bit kernels LK **always** calls `decompress_kernel()`;
  on failure it panics `decompress kernel image fail!!!`. So the kernel must stay
  gzipped (an uncompressed Image will not work).
- Handoff: `lk_jump64((u32)entry, (u32)tags, 0, KERNEL_64BITS)` → **x0 = DTB (tags
  address, 0x4bc80000)**, x1 = 0, x2 = KERNEL_64BITS.
- Our LK log prints `kernel real kernel_sz=0x0004fcb8` and never
  `decompress kernel image fail` → **LK decompressed U-Boot successfully and
  entered `load_images()` (modem)**. LK is no longer the blocker.

U-Boot side (`u-boot/` in repo):
- `CONFIG_TEXT_BASE = 0x40080000` (matches `kernel_addr`).
- `chosen/stdout-path = "/framebuffer"` → U-Boot console is the framebuffer at
  `0x7e9f0000`, **not** the UART.
- `CONFIG_DEBUG_UART=y`, base `0x11002000`, baud `921600` — a TTL adapter on the
  phone's UART test points would show U-Boot's output verbatim.
- `CONFIG_SAVE_PREV_BL_FDT_ADDR=y` (needed for `get_prev_bl_fdt_addr()`).
- `# CONFIG_SKIP_LOWLEVEL_INIT is not set` — U-Boot runs its own low-level init.
- KE7 code in `arch/arm/mach-mediatek/mt6768/init.c` prints `[UBOOT] board_late_init
  reached` and MD-clock traces via `mt6768_trace()`.

**Status:** LK passes, decompresses U-Boot, jumps with x0=DTB — but U-Boot produces
no visible output and never reaches `bootcmd` (debug image's watchdog-disable never
runs, loop continues). Blocker is now inside U-Boot's early init.

## 8. Android rendering bottleneck (measured 2026-10-31)

Full write-up: `docs/android-rendering-bottleneck.md`.

**Not CPU, not GPU, not memory.** All-CPU pinning and GPU pinning (verified
823 MHz) changed jank by <2 %. `/proc/pressure/memory` is 0.00.

The present path delivers an **effective 30 Hz**: `dumpsys SurfaceFlinger
--latency StatusBar#0` shows intervals alternating 16.7 ms / 33.4 ms.
`HWC missed frame count == total missed` (3993 vs 229 GPU). App-side draw is
1.2 ms, sync 0.8 ms, but draw→swap is 22.8 ms.

**For the Android 17 port:** fix the DSI/panel present path (video vs command
mode, porches/pixel clock, TE/vsync source, appVsyncOffset/presentDeadline,
CMDQ), then re-measure. Do not tune governors before the cadence is a clean
16.7 ms.


### 8.1 FIXED 2026-11-03 — UI was 30 Hz because of a vendor prop

`/vendor/build.prop:409` sets `debug.sf.disable_backpressure=1`. With it, SF's DispSync
delivers `VSYNC-app` every second frame:

- `VSYNC-app` median **33.44 ms (29.9 Hz)**; `Choreographer#doFrame` 33.48 ms
- while app work is `DrawFrame 0.53 ms`, `dequeueBuffer 0.63 ms`

Fix: `resetprop debug.sf.disable_backpressure 0` before SurfaceFlinger starts →
`Choreographer#doFrame` **16.48 ms = 60.7 Hz**, SystemUI median frame 46 ms → 17 ms.

**REVERTED 2026-11-03**: applied as a Magisk module, trace confirmed 60.7 Hz, but the
user reported no improvement and *worse* feel. Module removed, prop restored to 1,
rebooted and verified. Do not re-apply without new evidence — frame-pacing numbers
are not the same as felt responsiveness.

Verify with `atrace ... gfx view sched -a com.android.systemui` and measure
`Choreographer#doFrame` intervals. Ignore `gfxinfo` jank % right after boot: Play
Services pushes load average to ~26 (eMMC D-state) for several minutes.

## 9. Backups — complete Android reference

`backup/android-all-20261031-1945/` — **every readable partition** (47 files,
1.8 GB) with `MANIFEST.sha256` and `README.md`: boot chain, calibration, NV,
vendor, display, boot0/boot1, primary+backup GPT. `super`/`userdata` are in
`backup/android-full-20261031-132104/` (unchanged since). Do not write `rpmb`.

Method note: `adb exec-out` through `su` is **not** binary-safe (CR before LF);
use `dd` on device + `adb pull`, then verify SHA-256 against the device.

## 10. Device handed over for daily use (2026-11-03 21:50)

Final configuration of the phone as a normal daily device:

| Item | Value |
|---|---|
| Build | `KE7-H693HJKM-Q-GL-220729V478`, Android 10, security patch **2022-07-05** |
| Boot state | `orange` (bootloader unlocked) |
| Magisk | **31.1** core + app (`31100`) |
| Root access | **only `com.android.shell` (uid 2000, policy=2)**; `app.morphe.manager` denied (policy=1) — verified in the Magisk Superuser UI (Shell ON, Morphe OFF) |
| Play Protect | `package_verifier_enable=1`, `verifier_verify_adb_installs=1` |
| Internal storage | 42 GB free |
| SD card | **reformatted portable**, 14.6 GB, UUID `8968-1D0A` |
| SIM | loaded (`Jazz`) |
| Google accounts | none signed in (user will add) |

Cleanup performed:
- `/data/local/tmp` cleared (332 MB of port files)
- `/sdcard` port dumps removed (`dtbo.img`, `fdt.dtb`, `libcam*.so`, `sensors.mt6768.so`,
  `swfingerprint.default.so`, `mddb.*`, `ta.tar`, `vendor_fw.tar`) and `Download/` APKs (610 MB)
- Internal ESP `p40` cleared (Linux boot files, 100 MB → 4 KB)
- SD card repartitioned: old `BOOT`(FAT16)+`KE7ROOT`(ext4) replaced by one portable volume
- Kept: the one `DCIM` photo

**Magisk update note:** the `boot` partition is **write-protected from Android**
(`dd: Operation not permitted`). Magisk 27.0 → 31.1 was applied by patching the boot image
with the 31.1 assets (`boot_patch.sh` + `magiskboot`/`magiskinit`/`magisk`/`init-ld` from the
APK) and flashing via **BROM** (`sector 1157120`). Rollback images:
`backup/boot_current_magisk27.img` (sha `7b6242ab…`) and `flash_images/boot_magisk31.img`.
Any future Magisk update must go through BROM too.

## 11. Debloat hides apps — nothing was deleted (2026-11-04)

**Symptom:** contacts/calendar would not sync after signing in to Google.

**Cause:** the ROM's debloat used `pm uninstall --user 0`, which hides a package for the
user but leaves the APK in `/system` or `/product`. 58 packages are hidden this way,
including the two sync adapters:

```
com.google.android.syncadapters.contacts   (/product/app/GoogleContactsSyncAdapter)
com.google.android.syncadapters.calendar
com.google.android.gm                      (/product/app/Gmail2)
```

**Fix (no root needed):**

```bash
adb shell pm install-existing com.google.android.syncadapters.contacts
adb shell pm install-existing com.google.android.syncadapters.calendar
adb shell pm install-existing com.google.android.gm
```

After that, sync engine reports `com.android.contacts` and `com.android.calendar`
under the `com.google` account as `SUCCESS`.

**How to find any "missing" app on this phone:**

```bash
adb shell pm list packages -u        # includes packages hidden per-user
adb shell pm install-existing <pkg>  # restore without reflashing
```

Other notably hidden packages: `com.android.chrome`, `com.google.android.apps.maps`,
`com.google.android.apps.messaging`, `com.google.android.googlequicksearchbox`,
`com.google.android.tts`, `com.google.android.apps.wellbeing`, `com.google.android.youtube`.
The user chose to restore only Gmail + the two sync adapters (TTS restored, then removed again).

**Second account trap:** microG (`app.revanced.android.gms`) registers a second account
with the same Gmail address (`type=app.revanced`). Its contacts sync is disabled; the real
`com.google` account is the one that syncs.

## 12. microG keepalive for Morphe YouTube (2026-11-04)

**Symptom:** after swiping microG from Recents, patched YouTube opens a browser help page
instead of the feed. microG only matters while it is running.

**Cause:** standard Android behaviour — "Clear all" in Recents calls
`killAllBackgroundProcesses()`, which kills any process **without a foreground service**.
ReVanced microG (`app.revanced.android.gms`) has no foreground service, so it dies.
It was already: Doze-whitelisted (`user,app.revanced.android.gms,10152`) and in standby
bucket 5 (EXEMPTED) — neither protects against task-removal kill.

**Fix:** Magisk module `tools/magisk/ke7_microg_keepalive/` (`service.sh`) that re-applies
the Doze whitelist at boot and, every 15 s, respawns microG if its process is gone by
sending the exported action
`app.revanced.android.gms.fitness.GoogleFitnessService.START` (a running service also
lifts the process out of the "background" adj class, so it survives `am kill-all`).

Verified: `am force-stop app.revanced.android.gms` → process gone → back as a new pid
within 25 s; YouTube Morphe then opens the normal feed.

Notes:
- `tran_freeze_cloud_support` was temporarily set to 0 while testing and restored to 1;
  the watchdog does not depend on it.
- microG must stay installed — it provides the Google APIs that Morphe YouTube calls.
