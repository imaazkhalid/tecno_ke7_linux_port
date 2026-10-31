# Dual-boot: Android on eMMC, Linux on microSD

**Goal:** keep the stock Android install (and its IMEI/calibration) untouched while
running the Linux port from a microSD card, switching with a reboot instead of
reflashing the phone every time.

**Status:** blocked on one specific issue — AVB. Everything else (SD layout, rootfs,
U-Boot build) is ready.

---

## SD card layout used

| Partition | Size | FS | Contents |
|---|---|---|---|
| p1 | 1 GiB | FAT16 (`BOOT`) | `Image`, `mt6768-tecno-ke7.dtb` |
| p2 | 13.6 GiB | ext4 (`KE7ROOT`, PARTUUID `30d61490-…`) | Arch Linux ARM + Phosh |

Created entirely on the phone with `sgdisk`, `newfs_msdos` and `mke2fs` (Android
ships all three). FAT32 was not possible on 1 GiB (below the 65 525-cluster
minimum), so FAT16 is used; U-Boot reads it fine.

Rootfs setup: `fstab` by PARTUUID, `sshd` enabled, USB gadget service
(`g_ether`, `172.16.42.2/24`), root password set, `resolv.conf` written as a real
file (Arch's is a symlink into `/run`).

## The boot chain constraint

The preloader always loads **LK from eMMC**. There is no way to boot a loader
directly from SD. The only options are:

1. U-Boot in the `boot` partition (replaces Android's boot image).
2. U-Boot in the `recovery` partition, entered with `adb reboot recovery`.
3. `fastboot boot` a RAM image.

## What we learned the hard way

### 1. `fastboot boot` is a no-op on this LK
It prints `Sending … OKAY` / `Booting … OKAY`, but the image never executes
(verified with a payload that writes markers). Do not rely on it.

### 2. The recovery slot does not work for U-Boot
LK boots `recovery` with a different handoff than `boot`; the same U-Boot payload
that works from `boot` resets immediately from `recovery`.

### 3. **AVB is the real blocker**
The retail flash (`flash_retail.sh`) restores the **stock `vbmeta`**
(`SHA256_RSA2048`, `Flags: 0`, chain partitions). While that is active, LK verifies
the `boot` image and rejects a custom U-Boot without a valid AVB footer → orange
Tecno logo → reset loop.

The original port worked because it ran with `vbmeta_disabled.img`
(`Algorithm: NONE`, `Flags: 3` = hashtree + verification disabled).

**Therefore:** custom `boot` images need either

- `vbmeta` replaced with a disabled image, **or**
- a matching AVB footer (`avbtool add_hash_footer`) and the corresponding vbmeta.

### 3b. Two AVB layers — disabling vbmeta is not enough

AVB has **two** independent pieces:

| Layer | What it is | Effect of disabling |
|---|---|---|
| `vbmeta` partition | top-level metadata, chain descriptors | verification policy off |
| **footer inside each `boot` image** (`AVBf`) | per-image vbmeta + hash descriptor + size | **still required** — LK parses it to learn the image layout |

Proof: the Magisk-patched `boot` that boots on this phone is signed with a
**different key** (`9d808b…`) than the stock `vbmeta` (`cdbb77…`), so signatures are
not enforced while unlocked. But it *has* a footer. Our rebuilt U-Boot had none and
was rejected even with `vbmeta_disabled` flashed.

Fix: run `avbtool add_hash_footer` on the unpacked content before padding:

```bash
avbtool add_hash_footer --image uboot_content.img \
  --partition_size 33554432 --partition_name boot --algorithm NONE
```

(`--algorithm NONE` produces an unsigned footer; LK accepts it with an unlocked
bootloader.)

### 4. BROM entry key changed
On the current retail bootloader, BROM is **Volume Up + plug**. The older
Vol Up + Vol Down combo no longer applies.

### 5. Concurrent USB pollers break the DA upload
Running `fastboot devices` (or any second watcher) while mtkclient is uploading the
DA produces `Status error: Wrong magic` + `Device disconnected`. Run exactly one
mtkclient session; it has its own `wait_for_device` loop.

### 6. mtkclient restore recipe (used repeatedly)

```bash
# single pre-armed session; phone off, hold Vol Up, plug
./mtk-venv/bin/python mtkclient/mtk.py multi \
  "w boot <stock>/boot.img;w recovery <stock>/recovery.img;w vbmeta <stock>/vbmeta.img;w misc /tmp/zero_misc.bin;reset"
```

`zero_misc.bin` is 6 152 192 bytes of zeros (clears the `boot-recovery` BCB).

## Next steps when resuming

1. Re-root Android (Magisk is still installed on `/data`; patch the stock boot image
   and flash it).
2. Flash `vbmeta_disabled.img`.
3. Build U-Boot with a **short bootcmd** (`mmc dev 1` + two `load` + `booti`,
   ~270 chars) and pack it with a valid AVB footer for the boot partition.
4. Verify: `fastboot flash boot u-boot.img` → reboot → Linux from SD.
5. Keep the stock `boot.img` on the SD FAT partition so Linux can restore Android
   with one `dd` before rebooting.

## Package size note

`u-boot.bin` is 700 KB, the payload is gzip-compressed (330 KB) in an Android boot
image with the 27 MB Linux Image as the "ramdisk" slot. Keep the same layout as the
known-good payload.
