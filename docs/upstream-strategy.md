# Upstream strategy — keeping this device alive on future kernels

The goal is not "a kernel that boots today". It is a device that keeps booting when
6.19, 6.20, 7.0 and the LTS kernels after that arrive. That changes how every piece
is built.

## 1. Principles

1. **Device tree in the kernel tree.** The board DTS lives in
   `arch/arm64/boot/dts/mediatek/mt6768-tecno-ke7.dts` and is submitted upstream.
   No private DTB blobs, no runtime patching.
2. **Drivers upstream or not at all.** Every driver we write is a standard Linux
   driver with a DT binding (YAML), a MAINTAINERS entry and a `git format-patch`
   series. Out-of-tree modules rot within one release cycle.
3. **No vendor kernel dependency.** The vendor 4.14 tree is a *reference*, never a
   runtime component.
4. **Firmware is data, not code.** Anything that must be loaded (Wi-Fi/BT patch,
   touch firmware, panel init) goes through the standard `request_firmware()` path
   and is documented as user-extractable, never committed.
5. **Everything is described in DT.** No hardcoded register bases, GPIO numbers or
   clock names in C. If a value is board-specific, it belongs in the DTS.
6. **Test every merge window.** A device that is not built against `linux-next`
   regularly is a device that breaks silently.

## 2. Per-subsystem upstream plan

| Subsystem | Current | Target | Effort | Risk |
|---|---|---|---|---|
| CPU / GIC / timers | mainline | already upstream | — | low |
| eMMC / SD | mainline | already upstream | — | low |
| PMIC MT6358 | mainline | already upstream | — | low |
| Charger RT9471 | mainline | already upstream | — | low |
| USB gadget | mainline | already upstream | — | low |
| Touch (Novatek SPI) | out-of-tree patch | send SPI support to `novatek-nvt-ts` | S | low |
| Display panel (NT36525B) | not written | new `panel-novatek-nt36525b` + `mtk_dsi` | M | medium |
| Backlight (OCP2130) | not written | new i2c LED driver (simple) | S | low |
| GPU (Mali-G52) | Panfrost exists | DT node + OPP, no new driver | S | low |
| Audio (MT6358 + amp) | upstream codec | machine driver + `gpio-simple-amplifier` | M | medium |
| Sensors (MXC6655, STK33562, MMC5603) | not started | iio drivers (two exist, one small) | M | medium |
| Fingerprint (Sunwave) | not started | new SPI driver + libfprint backend | L | high |
| Camera (GC02M1/OV02B10) | upstream sensors | CAMSYS/SENINF driver (MTK) | XL | high |
| Wi-Fi/BT (MT6631) | vendor module | new `mt76`-family or `mtk-conninfra` driver | XL | very high |
| Modem (CCCI) | out-of-tree port | upstream `drivers/net/wwan` or `misc/mediatek/ccci` | L | high |
| NFC | not started | NCI driver if chip is PN5xx | M | medium |

**Effort:** S = days, M = weeks, L = months, XL = multi-month / needs vendor help.

## 3. Kernel-version policy

| Track | Purpose |
|---|---|
| **LTS** (6.12 / 6.18) | the kernels the device actually runs |
| **linux-next** | weekly build of DT + drivers; catches API breakage early |
| **Stable** | cherry-pick fixes only |

Rules:

- The DT must compile with **zero warnings** on every new kernel
  (`make dtbs_check W=1`).
- Any driver API change is handled in the same merge window it appears — never
  accumulate a delta.
- Keep a `compatibility.md` note per kernel major: what built, what broke, what was
  fixed.

## 4. Repository layout for upstream work

```
dts/mainline-mt6768-tecno-ke7.dts   # the board DTS (source of truth)
patches/linux/                       # our series, rebased per kernel
patches/u-boot/                      # bootloader series
configs/                             # defconfig + .config for the device
docs/                                # this documentation
```

Each release of the port is tagged (`v6.18-ke7.1`) with the kernel version it was
tested against, so users can pick a known-good combination.

## 5. What "support all future kernels" means in practice

- **No binary blobs in the boot path.** U-Boot and the kernel are built from source
  for every release; nothing depends on a 2022 vendor image.
- **DT bindings documented.** A future maintainer can read the YAML and understand
  the hardware without this repo.
- **Firmware optional.** If a firmware file is missing, the driver must fail
  gracefully (probe defer / disabled node), not hang the boot.
- **Fallbacks.** SimpleFB stays as a fallback until the DRM panel driver is merged;
  the device boots with `nomodeset` if needed.
- **No `#if LINUX_VERSION_CODE`.** Version checks in drivers are a maintenance debt;
  use API-compatible helpers.

## 6. Upstream submission order

1. Board DTS + bindings for already-supported blocks (eMMC, USB, PMIC, charger).
2. Touch SPI support (small, low risk).
3. Panel + backlight (visible win, needed by everyone).
4. Audio machine driver.
5. Sensors (iio).
6. CCCI modem (largest kernel-side piece).
7. Connectivity (needs a vendor-independent driver; hardest).
8. Fingerprint and camera (separate subsystems, can be independent).

## 7. The maintenance contract

For this to survive, every change must answer:

- Does it build against `linux-next` today?
- Is the hardware description in DT (not C)?
- Is there a binding document?
- Does it fail safely when firmware/hardware is absent?
- Is it tested on a real KE7 (not just compiled)?

If the answer is "no" to any of these, it is not done.
