# Modem (MT6768 CCCI / CLDMA)

The Helio G70 has an **integrated LTE modem** (MD) that talks to the application
processor (AP) through **CCCI** — a set of shared-memory rings, DMA channels and
mailboxes. Getting it running on mainline Linux is the hardest part of this port.

---

## 1. Architecture

```
┌───────────── AP (Linux) ─────────────┐        ┌──────── MD ────────┐
│ ccci.ko                              │        │  modem firmware    │
│  ├─ FSM (finite state machine)       │        │  (md1img)          │
│  ├─ CLDMA HIF  ── DMA rings ─────────┼────────┼─► shared memory    │
│  ├─ CCIF HIF   ── mailboxes ─────────┼────────┼─► control IRQs     │
│  └─ char devices                     │        │                    │
│     /dev/ccci_fs   (FSD)             │        │  NVRAM (NV0S_*)    │
│     /dev/ttyC0     (AT)              │        │  RF calibration    │
└──────────────────────────────────────┘        └────────────────────┘
```

| Resource | Value |
|---|---|
| AP CCIF | `0x10209000` (IRQ 164) |
| MD CCIF | `0x1020a000` (IRQ 165) |
| CLDMA | `mdcldma@10014000`, MSB `10013000` |
| MD memory window | `0x3000000` base, ATAG `ccci,modem_info_v2` |
| MD power domain | `MT6768_POWER_DOMAIN_MD1` (SPM) |
| Firmware | `md1img` partition (~57 MB) |
| MD generation | **6293** (`-DMD_GENERATION=6293`) |

**Queue map** (generation 6293):

| Queue | Purpose |
|---|---|
| 0 | data (network) |
| 1 | CCCI RPC (channels 32/33) |
| 4 | `ccci_fs` filesystem daemon |
| 5 | `ttyC0` AT channel |
| 15 | CCIF SRAM control (handshake 1) — not a data queue |

---

## 2. The driver port

`cellular-port/` is the vendor 4.14 CCCI driver ported to mainline 6.18 as an
out-of-tree module (`ccci.ko` + `ccci_util_lib.ko`, ~1.8 MB).

| Problem | Fix |
|---|---|
| MD power domain never enabled | bind `mdcldma@10014000` to `<&spm MT6768_POWER_DOMAIN_MD1>` and `pm_runtime_get_sync()` in `md_cd_power_on()`; without it `md1_pll_init` cannot verify the PLL (`0x20160627`) or release the boot slave |
| CLDMA rings uninitialised | call `ccci_cldma_hif_init()` directly from `ccci_modem_probe()` instead of relying on a detached DT node |
| FSM never starts | fix `CCCI_COMMAND_START` enum in `boot_md_store()`/`ccci_md_register()`, clear `needforcestop`, decouple `dev_char_close()` |
| Infracfg regmap missing | fallback to `syscon_regmap_lookup_by_compatible("mediatek,mt6768-infracfg_ao")` and guard `cldma_plat_hw_reset()` |
| CCIF not compiled in | map AP/MD CCIF + IRQs 164/165, link `ccci_hif_ccif.o`, `ccci_ringbuf.o`, `ccci_debug_info.o` into `ccci.ko` |
| false `early exception detected` | `-DMD_GENERATION=6293` (channel 1 control messages were misread as `D2H_EXCEPTION_INIT`) |
| alignment fault in register dump | replace `ccci_util_mem_dump()` on ioremap'd registers with 32-bit `readl_relaxed()` |
| IRQ storm on unload | `disable_irq()` + `free_irq()` in `ccci_cldma_exit()` / `ccci_ccif_exit()` |

Build:

```bash
cd cellular-port
make -C ../linux M=$PWD ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- modules
```

---

## 3. Runbook (once the modem starts)

```bash
systemctl stop ModemManager
modprobe ccci
cat /sys/kernel/ccci/boot                       # expect md1:0 (RESET)

mkdir -p /mnt/vendor/{nvdata/md,protect_f/md,protect_s/md,nvcfg,mdlpm,etc/mdota,firmware,nvdata/md_cmn}
setsid nohup python3 -u tools/ccci_fsd.py /dev/ccci_fs </dev/null >/tmp/ccci_fsd.log 2>&1 &

python3 tools/ccci_mdinit.py
journalctl -k | grep -E 'ccci1/(fsm|chr|cif|rpc)' | tail -40
cat /sys/kernel/ccci/boot                       # want md1:2 (READY)
```

`/sys/kernel/ccci/boot` is the only trustworthy state source:

| Value | Meaning |
|---|---|
| `md1:0` | RESET |
| `md1:2` | **READY** |
| `md1:3` | BOOT_WAITING_FOR_HS2 |

Do **not** trust `ccci_mdinit.py`'s printed state — its name table is wrong. A write
to `/sys/kernel/ccci/boot` appends `CCCI_COMMAND_START`; there is no stop command.

---

## 4. The handshake sequence

The AP boots the MD in stages and the two sides exchange handshakes:

1. **HS1** — AP writes the boot address into CCIF SRAM and rings the mailbox.
2. MD firmware starts, initialises its drivers.
3. **HS2** — MD queries the AP over RPC (SIM, EINT, NVRAM config). This is where our
   port stalled: the MD never answered HS2.

### Diagnosing HS2

`rxq4 isr_cnt > 0` in `journalctl -k | grep 'cif]total'` means MD→AP data is flowing.
The RPC channel (queue 1, channels 32/33) shows which MD driver is asking questions.

The stall was not in the AP driver: the MD stopped answering *after* the EINT phase,
inside its own init.

---

## 5. The HS2 stall — root cause

**Symptom:** the modem hangs on the first EINT RPC; the AP sees no further traffic
and the MD never reaches READY.

**Root cause:** the modem writes to `EINT_SRC` to configure its interrupt controller,
but the **MD EINT controller clock is gated off** in the default boot state. The write
to a gated block bus-hangs the MD, which then sits in an exception loop.

**Fix:** enable the clock from the AP **before** the modem boots — in U-Boot, not in
Linux, because Linux starts the MD too late:

```c
/* u-boot/arch/arm/mach-mediatek/mt6768/init.c, board_late_init() */
writel(0x21, (void __iomem *)(0x10001000 + 0xF0C));  /* INFRA_AO_MD_SRCCLKENA */
```

This is the same register the vendor kernel writes in `md_sys1_platform.c` before
powering the modem; U-Boot simply does it earlier.

> **Status:** the U-Boot fix is built (700,576 bytes) but **not yet flashed**. Until
> it is, the modem stalls at HS2 exactly as described.

---

## 6. NVRAM, calibration and the IMEI

The modem keeps its configuration in a small filesystem on `nvdata`
(`/mnt/vendor/nvdata/md/NVRAM/...`). The IMEI lives in
`NVD_IMEI/NV0S_000` (LID `0xF00A`) and the records are **encrypted by the modem**
with a key derived from OTP.

On this unit all NV partitions had been wiped, so:

- the modem had no IMEI → network attach rejected (`Illegal ME`);
- the RF calibration was gone.

Both are now restored through META (see [imei-restore.md](imei-restore.md)). For the
Linux port this matters: the modem now has valid NV data to read during HS2, so the
remaining blocker is purely the EINT clock.

---

## 7. Next steps

1. Flash the U-Boot payload with the `INFRA_AO_MD_SRCCLKENA` fix.
2. Verify the MD reaches `md1:2` and `rxq4 isr_cnt > 0`.
3. Run the FSD daemon and mount the modem filesystem.
4. Bring up `ccmni`/`rmnet` for data and the AT channel for calls/SMS.
5. Only then wire the modem into NetworkManager/ModemManager.

---

## Reference

- Full derivation and experiments: [`reference/hardware-research.md`](reference/hardware-research.md) §26–32
- Session log with every failure: [`reference/project-log.md`](reference/project-log.md) §31–33, §52
- Driver sources: [`../cellular-port/`](../cellular-port)
- Userspace daemons: [`../tools/ccci_fsd.py`](../tools/ccci_fsd.py), [`../tools/ccci_mdinit.py`](../tools/ccci_mdinit.py)
