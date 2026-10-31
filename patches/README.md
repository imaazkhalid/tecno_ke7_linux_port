# Patches and configs

Everything needed to rebuild the boot chain and the kernel for the KE7, without
shipping any vendor firmware.

## Contents

| Path | What it is |
|---|---|
| `linux/0001-ke7-board-and-drivers.patch` | board DTS + Novatek SPI touch fixes + MT6358 poweroff driver |
| `u-boot/0001-mt6768-ke7-board.patch` | CCCI `/chosen` forwarding + MD EINT clock fix + board config |
| `../configs/linux-6.18-ke7.config` | the exact kernel `.config` used on the device |
| `../configs/u-boot-ke7.config` | the exact U-Boot `.config` |
| `../dts/mainline-mt6768-tecno-ke7.dts` | the mainline board DTS as a readable file |

## Apply

Kernel (mainline 6.18):

```bash
git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
cd linux
git checkout v6.18          # or the tag matching configs/linux-6.18-ke7.config
git am ../patches/linux/0001-ke7-board-and-drivers.patch
cp ../configs/linux-6.18-ke7.config .config
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) Image dtbs
```

U-Boot:

```bash
git clone https://source.denx.de/u-boot/u-boot.git
cd u-boot
git am ../patches/u-boot/0001-mt6768-ke7-board.patch
cp ../configs/u-boot-ke7.config .config
make ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
make ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc)
```

## What the patches actually change

### Linux

- `mt6768-tecno-ke7.dts`: board description — panel, touch, keys, charger, fuel
  gauge, USB, modem memory reservations, regulators.
- `novatek-nvt-ts-core.c` / `novatek-nvt-ts-spi.c`: SPI transport fixes so the
  KE7 touch controller probes and reports correctly.
- `mt6358-poweroff.c`: poweroff/reset driver rework (the vendor version does not
  power the PMIC down correctly on mainline).

### U-Boot

- `board_late_init()`: copy LK's `/chosen/ccci,*` properties into the Linux DTB.
- `INFRA_AO_MD_SRCCLKENA = 0x21` before the modem boots — the HS2 stall fix.
- board config/DTS tweaks for the KE7 display handover and eMMC.

## Not included (on purpose)

- **Firmware images** — see [../docs/firmware.md](../docs/firmware.md) for the
  manifest and checksums.
- **Vendor modem firmware source** — proprietary; the CCCI *driver* port is in
  [`../cellular-port/`](../cellular-port) (GPL-2.0).
- **Device dumps** — regenerate them from your own phone with
  [`../tools/extract-hardware.sh`](../tools/extract-hardware.sh).
