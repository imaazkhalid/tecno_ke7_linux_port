# MEMORY — read this first

One-page operational memory. Detailed narrative lives in `docs/`; this file is the
"where are we, what boots, where are the backups, what to do next" sheet.

**Update after every meaningful step, then commit immediately** —
`git add MEMORY.md && git commit -m "<what changed and why>"`.
An uncommitted note is lost work. Permanent facts (tool paths, partitions, USB IDs,
hard rules) belong in `/home/mk/AGENTS.md` §3 instead, which is loaded every session.

**Last updated:** 2026-10-31 18:10 — Android restored and verified rooted; Linux blocked at LK DTB assert.

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
| LK | **stock retail `f977f6ef…`** (restored 17:55) — Android boot set |
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

### 3.5 Why Linux does not boot (as of 2026-10-31 18:00)

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
- The `dtb` field of every image (ours **and** retail stock) is a 64-byte DTBO
  table (`d7b7ab1e`) with the FDT at +0x40 — not a raw FDT.
- U-Boot payloads **do** end with their own control DTB (`totalsize≈12104`,
  ending exactly at the payload end).
- Setting `dtb_size=0` at header offset 1648 (3 bytes) to force the
  "DTB packed with kernel" path was flashed but **never actually tested** —
  the phone never booted because mtkclient was hijacking every boot (§4 rule).

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
