# cellular-port — CCCI/CLDMA on mainline Linux

This directory is a **port of the MediaTek CCCI driver** (from the vendor 4.14
kernel tree, `drivers/misc/mediatek/eccci`, `ccci_util`, `ccmni`) to **mainline
Linux 6.18**.

## Provenance and licence

The original code is Copyright (C) MediaTek Inc. and is licensed **GPL-2.0**
(`SPDX-License-Identifier: GPL-2.0`), like the rest of the Linux kernel. Files keep
their original SPDX headers. Our changes are released under the same licence.

Nothing in this directory is firmware or modem binary code — it is kernel driver
source only.

## What changed

| Area | Change |
|---|---|
| DT bindings | bind `mdcldma@10014000` to `MT6768_POWER_DOMAIN_MD1`, runtime PM in `md_cd_power_on()` |
| HIF | call `ccci_cldma_hif_init()` from `ccci_modem_probe()` |
| FSM | correct `CCCI_COMMAND_START`, reset `needforcestop`, decouple `dev_char_close()` |
| infracfg | regmap fallback `mediatek,mt6768-infracfg_ao`, NULL-safe `cldma_plat_hw_reset()` |
| CCIF | map AP/MD CCIF + IRQs 164/165, build `ccci_hif_ccif.o`, `ccci_ringbuf.o` |
| build | `-DMD_GENERATION=6293` |
| debug | 32-bit `readl_relaxed()` register dumps (fixes arm64 alignment faults) |
| unload | `disable_irq()`/`free_irq()` to avoid an IRQ storm |

## Build

```bash
cd cellular-port
make -C ../linux M=$PWD ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- modules
```

The resulting `ccci.ko` and `ccci_util_lib.ko` are loaded on the device; the
userspace side (`ccci_fsd`, `ccci_mdinit`) lives in [`../tools/`](../tools).

See [`../docs/modem.md`](../docs/modem.md) for the architecture, the queue map and
the HS2 clock-gating bug.

## Status

The driver loads, powers the modem, and reaches the handshake. The remaining
blocker is the gated MD EINT clock, fixed in U-Boot (see
[`../docs/modem.md`](../docs/modem.md#5-the-hs2-stall)).
