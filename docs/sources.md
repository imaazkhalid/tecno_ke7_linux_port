# Sources and provenance

Where every artifact in this project comes from, and where you can obtain your own
copy. **Nothing listed here is hosted in this repository** — the links are
provenance, so you can verify what we used and reproduce it legally.

---

## 1. Device firmware

| Item | Value |
|---|---|
| Build | `KE7-H693HJKM-Q-GL-220729V478` (retail GL, Android 10) |
| Mirror used | **MobiFirmware.com** — search the build string or “Tecno KE7 firmware” |
| Discussion / alternate mirrors | **Hovatek** forum, thread “Tecno Spark 6 KE7 Stock ROM” (thread 35594) |
| Verification | [`../tools/verify_firmware.sh`](../tools/verify_firmware.sh) + the SHA-256 table in [firmware.md](firmware.md) |

Firmware is copyrighted. Download it yourself from a public mirror; do not
redistribute it. If a mirror disappears, the same build is usually reposted under
the exact build string — search for that, not for “KE7 ROM” in general.

## 2. SoC / bootloader tooling

| Tool | Source | Used for |
|---|---|---|
| **mtkclient** | `https://github.com/bkerler/mtkclient` | BROM access, GPT, partition read/write, the kamakiri exploit |
| **SP Flash Tool** (optional) | vendor packages | only if you prefer a GUI; not required |
| **libusb** / udev rules | your distro | BROM device permissions |

`mtkclient` implements the BootROM protocol and the kamakiri SLA/DAA bypass; it is
the only flashing tool this project depends on.

## 3. Vendor kernel and modem source

The CCCI/CLDMA analysis was done against the **MediaTek vendor kernel source**
release for this platform (`MOLY.LR12A.R3.MP`, kernel 4.14). That code is
GPL-2.0 (kernel drivers) and is distributed by MediaTek/OEMs for GPL compliance.

| Source | What it is |
|---|---|
| MediaTek GPL kernel source releases (via OEM support / GPL request) | the vendor kernel tree, including `drivers/misc/mediatek/eccci` |
| Public archive `MOLY.LR9.W1444.MD.LWTG.MP.V296` (`github.com/cvolo4yzhka/...`) | older, near-identical modem source used for cross-checking the EINT init sequence |

The **modem firmware source** (the `TK_MD_BASIC_MOLY…` tree, `mcu/pcore/...`) is
proprietary and is **not** redistributed here. Our driver port lives in
[`../cellular-port/`](../cellular-port) and is GPL-2.0.

## 4. Windows vendor tools

| Tool | Where it comes from |
|---|---|
| **SN Write Tool v1.2020.00** | ships inside many MTK firmware/tool archives; used for the IMEI write |
| **ModemMETA** | same archives; used to inspect the modem and NV items |

These are vendor binaries. They are not redistributed here; obtain them from the
same public archives everyone uses, and **run them in a VM** (they are closed-source
and some are flagged by antivirus).

The one-byte TEE bypass and the correct `SN_Setup.ini` are documented in
[imei-restore.md](imei-restore.md) and [`../tools/SN_Setup.patched.ini`](../tools/SN_Setup.patched.ini).

## 5. Upstream projects this port builds on

| Project | Role |
|---|---|
| **Linux kernel** (`git.kernel.org`) | mainline 6.18; our changes are in [`../patches/linux/`](../patches/linux) |
| **U-Boot** (`source.denx.de/u-boot/u-boot`) | UEFI payload; our changes in [`../patches/u-boot/`](../patches/u-boot) |
| **Arch Linux ARM** (`archlinuxarm.org`) | aarch64 rootfs |
| **GNOME / Phosh / Phoc** | mobile shell |
| **mt76** | MediaTek Wi-Fi driver family (MT6631/MT7663 class) |
| **Panfrost** | Mali-G52 GPU driver |
| **novatek-nvt-ts** | Novatek touchscreen driver (i2c; SPI variant added by us) |
| **rt9471** | Richtek charger driver |
| **mt6358** | PMIC regulator/ADC/audio codec drivers |

## 6. Community references worth reading

| Topic | Reference |
|---|---|
| MT6768 mainline status | postmarketOS device/SoC pages and the linux-mediatek mailing list |
| MTK boot chain (BROM → preloader → LK) | mtkclient documentation and the kamakiri write-up |
| Firmware / recovery | Hovatek forums (KE7 thread), XDA Tecno Spark 6 threads |
| MTK NV / IMEI | public reverse-engineering notes on `NV0S_*`, `NV01_*`, LID tables |
| Panel identification | LK image strings (`lk.img`, LCM driver table) |

## 7. What we deliberately do not link

- Direct download links to copyrighted firmware (use the mirror search instead).
- Repositories that redistribute leaked NDA modem source.
- Paid “IMEI repair” services.

If a link in this document dies, the artifact is still identifiable by its exact
build string or file hash — that is why [firmware.md](firmware.md) lists SHA-256
checksums for every image.
