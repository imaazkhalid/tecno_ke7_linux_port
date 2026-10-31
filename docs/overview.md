# Overview — goals, constraints and results

## 1. The goal

Turn a **Tecno Spark 6 (KE7)**, a 2020 budget Android phone, into a pocket-sized
Linux computer running a **pure 64-bit Arch Linux ARM** with **GNOME Phosh**, and
document the process so that anyone with the same or similar MT6768 hardware can
repeat it.

"Done" means:

- a standard boot chain we control (U-Boot as UEFI firmware, `systemd-boot`, a mainline kernel);
- a working display, touchscreen and power management;
- USB networking and charging at the same time;
- the internal LTE modem usable from Linux;
- every step written down with commands, register values and failure modes.

It is explicitly **not** a "flash a prebuilt ROM" project. There is no prebuilt image:
you build the kernel, the DT and the boot chain yourself.

## 2. Starting point

The phone was bought second-hand and arrived in a state that most guides call
unrecoverable:

| Partition | Expected content | What we found |
|---|---|---|
| `nvram` (p26) | RF calibration, IMEI | **all zero** |
| `nvdata` (p9) | modem NVRAM filesystem | **all zero** |
| `nvcfg` (p8) | NV config | **all zero** |
| `persist` (p10) | Wi-Fi/BT MAC, sensors cal | **all zero** |
| `protect1/2` (p11/p12) | DRM keys, attestation | **all zero** |

No ext4 superblock, no calibration, no IMEI — the previous owner had wiped the
device with a tool that also erased the "never touch" partitions. The pre-repartition
backups we took were already zero, so the data was lost before we got the phone.

That forced two detours that became a large part of this project:

1. **Reverse-engineer the MediaTek NV/IMEI storage** and restore it through the
   modem's own API ([imei-restore.md](imei-restore.md)).
2. **Go back to stock Android temporarily** to mine the vendor device tree, HALs
   and drivers for the hardware map ([android.md](android.md)).

## 3. Constraints we set ourselves

| Constraint | Reason |
|---|---|
| Never flash the preloader (`boot0`/`boot1`) | the only truly unrecoverable brick on MTK |
| Never write `seccfg` after unlocking | keeps "orange state"; re-locking can hard-brick |
| Preserve `otp`, `flashinfo`, `tkv` | factory-unique, no way to regenerate |
| Keep a full GPT + partition backup before every experiment | recovery from any mistake |
| Use public sources only | reproducibility; no paid firmware services |
| No proprietary blobs in this repo | legal hygiene, and they are not needed |

## 4. What we achieved

- **Boot chain replaced**: stock LK → U-Boot (UEFI payload) → `systemd-boot` → mainline
  Linux 6.18. The stock `boot` partition holds U-Boot; Linux lives on the ESP and a
  rootfs partition.
- **Arch Linux ARM + Phosh** running with software rendering; touch, keys, charging
  and USB networking work.
- **CCCI modem driver ported** from the vendor 4.14 tree to mainline 6.18 — a
  1.8 MB module with CLDMA, CCIF, FSM and the userspace FSD protocol.
- **Modem root cause found**: the MD bus hang is a gated EINT clock; the fix is a
  single register write in U-Boot before the modem starts.
- **IMEI restored** on the stock ROM through META + the vendor SN Write Tool, after
  reversing the NV record format and bypassing a TEE licence gate.
- **Android debloated** from 265 to 190 packages, rooted with Magisk, with a working
  dialer and fixed Wi-Fi MAC.

## 5. What is still open

| Item | Blocker | Next action |
|---|---|---|
| Modem READY on Linux | U-Boot EINT fix built but **not flashed** | flash U-Boot payload, verify `md1:2` |
| Wi-Fi/BT | CONNSYS gen4m driver port incomplete | continue `wifi-port/` |
| Display driver | only SimpleFB; mainline `mtk_drm`/DSI + NT36525B timings missing | disassemble LK LCM driver for porches |
| GPU acceleration | Panfrost not wired into DT | add `mali` node + OPP tables |
| Audio | needs MT6358 machine driver + GPIO 39 amp | DT + simple-amplifier |
| Camera | main sensor unknown (only sub-sensors in DT) | identify from `camera.txt` |
| Sensors | chips behind closed SCP firmware | i2c scan with SCP halted |

## 6. Design decisions worth knowing

- **U-Boot as UEFI, not a custom bootloader.** It gives us a standard
  `systemd-boot`/EFI environment, so the Linux side is completely ordinary.
- **Mainline kernel, not the vendor 4.14 tree.** The vendor tree is 32/64-bit
  hybrid and unmaintainable; the CCCI driver was ported instead.
- **SimpleFB first, DRM later.** Getting a picture with the bootloader's framebuffer
  unblocked userspace work months before a panel driver existed.
- **Modem NV writes go through META, never through file patching.** The records are
  encrypted with a modem-side key; editing files cannot produce a valid record
  (proved experimentally — see [imei-restore.md](imei-restore.md#4-why-you-cannot-just-edit-the-file)).

## 7. Repository conventions

- `docs/` — curated, current documentation (this is what you should read).
- `docs/reference/` — raw logs, kept verbatim for traceability.
- `tools/` — scripts, all paths relative to the repo root.
- `cellular-port/` — kernel driver sources (built out-of-tree against mainline).
- `dts/` — stock decompiled trees and porting fragments.

Nothing in this repository is device-unique: no IMEI, no serial numbers, no
partition dumps, no firmware.
