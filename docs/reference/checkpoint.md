# CHECKPOINT — Tecno KE7 (MT6768) modem bring-up

**Date:** 2026-10-25 (late)
**Device:** root@10.96.213.234 (Wi-Fi IP changes every boot; sweep 10.96.213.0/24 for port 22)
**State:** booted; `modprobe ccci` (no auto-load); FSD running; modem `md1:3` after start.

---

## 1. Goal
Bring up the MT6768 cellular modem under mainline Linux 6.18 + Phosh: HS2 -> READY -> SIM -> data.

## 2. Boot chain (working)
BROM -> Preloader -> stock LK (`lk` p27 / `lk2` p28) -> **U-Boot in `boot` p30** (Android bootimg,
kernel slot = gzip(u-boot.bin), stock ramdisk+DTB preserved, AVB hash footer) -> Linux from ESP.
Partitions: `md1img` p18, `lk` p27, `lk2` p28, `boot` p30, `ESP` p40, `rootfs` p43.
- Known-good baseline U-Boot: `boot-uboot.img` (sha256 `8d72fdf2...`).
- Deployed U-Boot: `boot-uboot-mdclk.img` (baseline + MD SRCCLKENA fix, sha256 `76e1afd0...`).
- Never `rmmod ccci` + `modprobe ccci` in one boot (hard hang) — reboot instead.

## 3. What works
- HS1 received (`control message 0x0,0x5555FFFF`), AP runtime data accepted
  (`rt-data: H2D_SRAM busy cleared after 0ms`).
- 12 RPC `0x4005` (SIM EINT attrs) answered; the modem consumes all replies
  (CCIF ring Q1 `tx(w=672 r=672)`).
- Memory layout from LK `/chosen/ccci,modem_info_v2` is intact (`using v3`):
  `md_resv 0xae000000+0x7e00000`, AP<->MD smem `0x78000000+0x1800000`,
  csmem `0x7c000000+0x1614000`; all correctly reserved in `/proc/iomem`.
- Modem image in DRAM is byte-identical to `md1img.img` payload (file offset 0x200 -> MD 0x90000000).
- DSP firmware **is loaded**: `md1dsp` section (md1img @0x16a3850, payload 0x698000) was found in
  DRAM at `0xae000000+0x7000000 = 0xB5000000`. No missing sub-images; **no custom LK needed**.
- MD1 SRAM power-on now matches vendor: `MD1_PWR_CON 0x00d`, `MD_SRAM_ISO_CON[0]=1`,
  `MD_EXTRA_PWR_CON[0]=0` (was 0x10d/0/1). SRCCLKENA=0x21.

## 4. THE BLOCKER (root-cause direction found)
The modem is **not idle — it is looping in the Nucleus exception handler**:
```
INT_GetExlog (0x90da8758) <- ESAL_AR_STK_Unsolicited_Set (0x90b93474)
  <- INT_EnterExceptionForOtherCore (0x90da8740) <- INT_GetExlog ...
```
It never sends the 13th RPC (`0x400e` DTSI query), never raises `D2H_EXCEPTION_INIT`, never sends HS2.
Firmware symbols involved: `ex_cadefa_assert`, `ex_output_assert`, `ex_wait_init_usip`,
`ex_init_usip`, `usip_activate/deactivate`, `dsp_FillBootPattern/Progress`,
`MD_TOPSM_IsUsipPowerOn`, `MD_TOPSM_USIP_SW_Control`, `query_usip_pc`, `ex_init_dsp_exrecord`.
=> The MCU is waiting for the **USIP/DSP** to reach boot/active state and dumping it when it doesn't.

`mdccci_dbg` (smem 0x78000000) partial record: `"CCCI" "EDBG" 0x70000007`, `+0x20=0x72e`,
`+0x2c=0x40050006` (last CCCI op 0x4005 / type 6). Rest zero; `mdss_dbg` (0x78000800) all zero.

## 5. Ruled out (do not re-test)
- SRCCLKENA 0x21 (set) — no effect.
- CCIF/CLDMA infra clocks (added to DT, all resolve) — no effect.
- SIM hot-plug EINT: physical tray reinsert had zero reaction.
- SIM1 EINT success reply: `md_eint_force_err=1` (all queries -> -11 like working MT6739 port) — no effect.
- CCB(15)/DHL_RAW(16) features disabled — no effect.
- Runtime feature 10 (`MISC_INFO_CCCI`) set to 0 (no seq check/polling) — no effect.
- MD1 SRAM power fix — no effect on the crash.
- MD exception signalling itself works: with `md_feature_force_min=1` the modem raises a proper
  `D2H_EXCEPTION_INIT` (channel 16) in ~24 ms, so our driver can receive exceptions.
- Boot stats `0x54430007`/`0x53320000` ("TC7"/"S2") are normal post-HS1 markers, NOT a hang signature.
- Modem code is **hardware-encrypted** (0.3% valid function prologues at 95k symbol starts;
  entropy ~7.0; DRAM==file) — static disassembly impossible.

## 6. Assets saved
- `flash_images/md1img.img` — stock signed modem firmware.
- `flash_images/lk_patched.img` — stock LK (md5 d4ad3eb9379c641286ff54471c438356).
- `ke7_dump/` — stock boot.img, dtbo, DTBs, vendor dumps.
- `vendor/TK_MD_BASIC_MOLY.LR12A.R3.MP/` — matching modem **vendor source** (commit 04ebd402,
  278 MB). SIM/USIM/EINT/NVRAM/drivers intact; CCCI/boot/assert implementation stripped.
- **DbgInfo symbols**: LZMA section of md1img (payload at file 0x1e4c280, raw LZMA).
  95,602 symbols `{u32 start,u32 end,name}` -> `/tmp/opencode/md_syms.txt`
  (regenerate: decompress with `lzma.FORMAT_ALONE`, then scan).
- Kernel-side debug hook in `md_cd_dump_pcmon_dmesg()` (read-only): boot stats, SCPSYS, INFRA,
  PC monitor + liveness, PWRAP regs, MD image head, mdccci_dbg, smem string scan, DSP image scan.
  Trigger: `echo register > /sys/kernel/ccci/mdsys1/dump`.

## 7. Live commands
```
modprobe ccci                       # (or: modprobe ccci md_...=1)
python3 /usr/local/bin/ccci_fsd.py &
python3 /tmp/start_md.py [mdlog_mode]
cat /sys/kernel/ccci/boot           # md1:3 = waiting HS2
echo register > /sys/kernel/ccci/mdsys1/dump   # read-only snapshot -> dmesg
echo ccif > /sys/kernel/ccci/mdsys1/dump       # CCIF SRAM -> dmesg
```
Module build:
```
make -C linux M=$PWD/cellular-port/eccci ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- modules
# deploy to /lib/modules/6.18.0-gf612f7e0293a-dirty/extra/ccci.ko, then reboot
```

## 8. Next step being worked
Find the **DSP/USIP exception record address** (data symbol) using the DbgInfo, read it from the
modem's DRAM, and decode the DSP's fault (PC/reason). DbgInfo also contains ~94k `addr->name`
records, including data symbols. Alternative: kernel-side read of the TOPSM/USIP power registers
(`/dev/mem` on 0x200D0000 returns a dummy 0x1 for every word, so it must be done in-kernel).

## 9. Repo hygiene / notes
- Docs are authoritative: `PROJECT_STATUS.md` (§31, §32) + `HARDWARE_RESEARCH_AND_DRIVER_RE.md`.
- Device passwords: `root` / `alarm` = `<redacted>`; `alarm` has passwordless sudo; Phosh runs as `alarm`.
- `ccci` does not auto-load on this image — always `modprobe ccci` first.
