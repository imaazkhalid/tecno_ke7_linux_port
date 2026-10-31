# MEMORY — read this first

One-page operational memory. Detailed narrative lives in `docs/`; this file is the
"where are we, what boots, where are the backups, what to do next" sheet.
Update it at the end of every session.

**Last updated:** 2026-10-31 (evening)

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
| LK | **current hash `b5e46508…`** (unknown build) |

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

## 4. Recovery / flashing rules

- **Before any write:** `./tools/save-state.sh <label>`.
- **BROM entry:** phone off, hold **Volume Up**, plug USB. (Not both volume keys.)
- **`adb reboot` lands in BROM on this device** — a pre-armed mtkclient session catches it.
- **Exactly one USB poller allowed.** `fastboot devices`/a second watcher during a DA
  upload produces `Wrong magic` + disconnect.
- Restore stock/rooted Android (BROM, single session):
  ```
  ./mtk-venv/bin/python mtkclient/mtk.py multi \
    "w boot <backup>/boot.img;w recovery <backup>/recovery.img;w vbmeta <backup>/vbmeta.img;w misc /tmp/zero_misc.bin;reset"
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

1. Finish `backup/android-full-*` (super+userdata).
2. BROM: write **port-era LK** (p27/p28 from `arch_state`) + **known-good p30**.
3. Boot → U-Boot → systemd-boot (ESP p40) → kernel + **SD rootfs**
   (`arch.conf` already points to the SD PARTUUID).
4. If Linux works: test display/touch/modem; keep Android as default by restoring
   `backup/known-good-rooted-*` boot.
5. If it still loops: restore Android and switch strategy (kexec/netboot), do not
   rebuild boot images blindly.

## 7. Documentation map

- `docs/` curated guides · `docs/reference/` raw research log
- `docs/dual-boot.md` — SD dual-boot findings (AVB, gzip, BROM)
- `docs/hardware-matrix.md` — per-component driver status
- `PROJECT_STATUS.md` → moved to `docs/reference/project-log.md`
