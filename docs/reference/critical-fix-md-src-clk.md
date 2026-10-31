# CRITICAL FIX: MT6768 Modem Source Clock Enable

## The Missing Piece

**Register:** `INFRA_AO_MD_SRCCLKENA` at `0x10001000 + 0xF0C` (INFRACFG_AO base + offset 0xF0C)
**Value:** `0x21`
**When:** Must be written **before** modem firmware boots (in U-Boot) or during `md_cd_power_on()` in CCCI driver

## Why This Fixes Everything

The vendor kernel `md_cd_power_on()` does this critical step (step 4):

```c
/* step 4: MD srcclkena setting */
reg_value = ccci_read32(md->hw_info->plat_val->infra_ao_base, INFRA_AO_MD_SRCCLKENA);
reg_value &= ~(0xFF);
reg_value |= 0x21;
ccci_write32(md->hw_info->plat_val->infra_ao_base, INFRA_AO_MD_SRCCLKENA, reg_value);
```

**Without this:** The modem's EINT controller clock stays gated. When the modem firmware tries to write `EINT_SRC` (to configure `src_pin=1` for GPIO47/SIM1 hot-plug), the bus hangs permanently because the EINT controller clock is off.

## Root Cause Chain

1. Modem firmware boots, Handshake 1 succeeds
2. Modem sends 12 SIM EINT RPC queries (NUM/DEDICATEDEN/SRCPIN for SIM1-4) → AP replies correctly
3. Modem attempts to configure EINT: writes `EINT_SRC` register to select `src_pin=1` (GPIO47)
4. **EINT controller clock is OFF** → bus hang on register write
5. Modem core stops executing; CCIF doorbells no longer serviced
6. Boot stats freeze at `0x54430007` / `0x53320000` (vendor's "bus hang" signature)

## Where to Apply the Fix

### Option 1: U-Boot (BEST - earliest)
In `u-boot/arch/arm/mach-mediatek/mt6768/init.c`:
```c
#define INFRACFG_AO_BASE    0x10001000
#define INFRA_AO_MD_SRCCLKENA  (INFRACFG_AO_BASE + 0xF0C)

static void mt6768_enable_md_src_clock(void)
{
    writel(0x21, INFRA_AO_MD_SRCCLKENA);
}
```
Call from `board_late_init()`.

### Option 2: CCCI Driver (fallback)
Already present in `md_cd_power_on()` at line ~1340 but **too late** - peri2md handshake must complete first. The modem firmware starts before `md_cd_power_on()` runs.

## Verification
After fix, modem should:
1. Complete Handshake 1 ✓
2. Answer 12 SIM EINT RPCs ✓  
3. **Write EINT_SRC without bus hang** (EINT clock enabled!)
4. Issue DEBOUNCE/POLARITY/SENSITIVITY/SOCKET queries
5. Power VSIM1/2
6. Reach READY state (`md1:2`)

## Current Status (Oct 25, 2026)
- U-Boot fix added to `init.c` in `board_late_init()`
- U-Boot rebuilt with `aarch64-linux-gnu-gcc`
- New binary: `u-boot/u-boot.bin` (700576 bytes)
- **NOT YET FLASHED** - need to write to correct boot partition

## Boot Partition Analysis
| Partition | Start | Size | Content |
|---|---|---|---|
| p1 (26M) | 64 | 53248 | Empty (all zeros) |
| p2 (3M) | 53312 | 6144 | Small data at offset 0x350 |
| p3 (512K) | 59456 | 1024 | Empty |
| **p4 (20M)** | **60480** | **40960** | **SYS_RAM_CONSOLE / SYS_PSTORE_RAW** |
| p14 (32M) | 545040 | 65536 | **ANDROID! boot header** (bootopt=64S3,32N2,64N2) |
| p18 (128M) | 643072 | 262144 | **md1rom** (modem firmware md1img) |

**Likely U-Boot locations:** p1, p2, p3 (early boot), or p4 (ramconsole)

## Next Steps
1. Identify correct boot partition for U-Boot (likely p1, p2, or p4)
2. Flash new U-Boot with `dd if=u-boot.bin of=/dev/mmcblk0pX`
3. Reboot → modem should reach READY
