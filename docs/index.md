# Documentation map

> **State first:** [`../MEMORY.md`](../MEMORY.md) — one-page current state, backup inventory, boot-chain facts, next steps.

Start with the [README](../README.md) for the one-page overview. This page is the
map of everything else.

## Read in this order

| # | Document | What you get |
|---|---|---|
| 1 | [overview.md](overview.md) | Goals, constraints, what works and what doesn't, roadmap |
| 2 | [hardware.md](hardware.md) | Board map: SoC blocks, GPIOs, I2C/SPI, IRQs, power rails |
| 2b | [hardware-matrix.md](hardware-matrix.md) | **Per-component driver matrix** — chips, buses, firmware, gaps |
| 3 | [boot-chain.md](boot-chain.md) | BROM → preloader → LK → U-Boot → systemd-boot → Linux |
| 4 | [linux-bringup.md](linux-bringup.md) | Kernel/DT work, display, touch, USB gadget, charging, Phosh |
| 5 | [modem.md](modem.md) | MT6768 CCCI/CLDMA on mainline, the EINT clock bug |
| 6 | [imei-restore.md](imei-restore.md) | NV format, META protocol, the TEE bypass, legality |
| 7 | [android.md](android.md) | Stock ROM recovery, root, debloat, dialer |
| 8 | [tooling.md](tooling.md) | mtkclient wrappers, META handshake, Windows-VM automation |
| 9 | [reproduce.md](reproduce.md) | **Step-by-step from any device state** |
| 10 | [firmware.md](firmware.md) | exact build ID, manifest, SHA-256 verification |
| 11 | [sources.md](sources.md) | where to obtain firmware, tools and vendor source |
| 11b | [dual-boot.md](dual-boot.md) | Android on eMMC + Linux on SD: what works and the AVB wall |
| 12 | [roadmap.md](roadmap.md) | every remaining gap, with the exact method to close it |
| 13 | [upstream-strategy.md](upstream-strategy.md) | how the port survives future kernels (6.19, 7.x, LTS) |
| 14 | [legal.md](legal.md) | Ownership, IMEI law, firmware copyright — read before flashing |

## Deep reference (raw research)

These are the original engineering logs. They are long, chronological and contain
dead ends on purpose — they show *how* the conclusions were reached.

| Document | Contents |
|---|---|
| [reference/hardware-research.md](reference/hardware-research.md) | 33 sections: SoC internals, CCCI, CLDMA, power/clock registers, META, IMEI |
| [reference/project-log.md](reference/project-log.md) | dated session log: every flash, every failure, every fix |
| [reference/hardware-inventory.md](reference/hardware-inventory.md) | complete Android-side inventory with register bases and IRQs |
| [reference/upstream-porting-guide.md](reference/upstream-porting-guide.md) | mainline 7.x upstreaming notes |
| [reference/flash-plan.md](reference/flash-plan.md) | partition-by-partition flashing plan and safeguards |
| [reference/checkpoint.md](reference/checkpoint.md) | snapshot of a known-good state |
| [reference/critical-fix-md-src-clk.md](reference/critical-fix-md-src-clk.md) | the MD SRCCLKENA fix in detail |

## Code and artifacts

| Path | Contents |
|---|---|
| [`../tools/`](../tools) | flashing/backup scripts, hardware extraction, META handshake, VM automation, on-device daemons |
| [`../patches/`](../patches) | our kernel and U-Boot changes, apply-ready |
| [`../configs/`](../configs) | exact kernel and U-Boot `.config` files |
| [`../cellular-port/`](../cellular-port) | CCCI/CLDMA driver ported to mainline 6.18 |
| [`../dts/`](../dts) | decompiled stock device trees + mainline DTS + porting fragments |
| [`../hardware/`](../hardware) | GPT table, sysfs/register dumps, regeneration guide |

## Looking for something specific?

- **"My phone is dead / wiped"** → [reproduce.md §2](reproduce.md#2-recover-from-any-state)
- **"How do I get META mode?"** → [tooling.md](tooling.md#3-meta-mode-the-real-handshake)
- **"Why is my IMEI gone?"** → [imei-restore.md](imei-restore.md)
- **"Why does the modem hang at HS2?"** → [modem.md](modem.md#5-the-hs2-stall)
- **"What panel is in this thing?"** → [hardware.md](hardware.md#display)
