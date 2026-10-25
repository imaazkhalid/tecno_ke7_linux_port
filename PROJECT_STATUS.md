# Tecno Spark 6 (KE7 / MT6768) — Linux Bringup Project Status & Memory Bank

**Last Updated:** October 25, 2026  
**Primary Goal:** Fully functional Arch Linux ARM (aarch64) with GNOME Phosh, touchscreen, battery management, USB gadget networking, and internal MediaTek CONNSYS Wi-Fi (`wlan0`).

---

## 1. Device & Environment Overview
* **Model:** Tecno Spark 6 (KE7 / KE7 JS1)
* **SoC:** MediaTek Helio G70 (MT6769V / MT6768, HW Code 0x707, arch k68v1)
* **CPU:** 2x Cortex-A75 (2.0 GHz) + 6x Cortex-A55 (1.7 GHz)
* **RAM:** 4 GB LPDDR4X
* **Storage:** 64 GB eMMC (`/dev/mmcblk0`)
  - ESP Partition: `/dev/mmcblk0p40` (vfat, mounted at `/boot/efi`)
  - Rootfs Partition: `/dev/mmcblk0p41` (ext4, mounted at `/`)
* **OS:** Pure 64-bit Arch Linux ARM (aarch64)
* **Desktop:** GNOME Phosh mobile shell + Phoc compositor
* **Kernel:** Upstream Mainline Linux 6.18.0-rc (`6.18.0-gf612f7e0293a-dirty #7`)
* **Networking (Current):**
  - USB Gadget Ethernet: Device IP `172.16.42.2/24`, Host IP `172.16.42.1/24` (interface `enp0s20f0u3`)
  - SSH: `ssh -F /dev/null -o StrictHostKeyChecking=no root@172.16.42.2`
  - Host Proxy: `http://172.16.42.1:8080` via `fast_proxy.py`

---

## 2. Working Subsystems & Verification
1. **Bootloader & Partitioning:**
   - LK -> U-Boot (UEFI payload) -> systemd-boot -> Linux Kernel.
   - AVB unlocked, partitions 1-39 intact, user partitions repurposed for Arch Linux.
2. **Display & Framebuffer:**
   - SimpleFB active at 720x1640x32bpp inherited from bootloader.
   - Phosh and Phoc running smoothly with GPU software fallback (panfrost prep ready).
3. **Touchscreen:**
   - Novatek NT36xxx SPI digitizer (`/dev/input/event3`) fully functional.
4. **Terminal / GNOME Console (kgx) Shell Integration:**
   - GNOME Console (`org.gnome.Console` / `kgx 51.0-1`) uses `libadwaita` and `vte4` (VTE `0.84.1-1`).
   - Root cause for terminal hanging/infinite spinner: On Arch Linux ARM, non-login interactive shells do not source `/etc/profile.d/vte.sh`. GNOME Console's `KgxEmpty` widget remains visible with `spinner-visible=TRUE` until VTE receives `vte.shell.precmd` (`\e]666;vte.shell.precmd!\e\`), OSC 7 (`\e]7;file://...`), and OSC 133 prompt markers.
   - Fix: Source `/etc/profile.d/vte.sh` at the end of `/home/alarm/.bashrc` (after `$PS1`) and `/etc/bash.bashrc`.
5. **Power & Battery Fast-Charging & UI:**
   - RT9471 charger IC boost script `/usr/local/bin/usb-charger-boost.sh` sets `input_current_limit` to 1.5A (`1500000` uA), overcoming standard USB 2.0 500mA limit.
   - Persistent udev rule `/etc/udev/rules.d/99-charger-fastcharge.rules` maintains 1.5A charging concurrently with USB data gadget.
   - Linked `fuel_gauge` (`adc-battery`) to `charger` (`richtek,rt9471` at `0x53`) via `power-supplies = <&charger>;` in DTB, allowing Phosh shell and Settings app to accurately display active charging state and lightning bolt icon.
6. **USB Connectivity:**
   - Zero-OTG USB Gadget Ethernet operational on boot with concurrent 1.5A fast charging.
   - SSH and fast internet proxy forwarding working.

---

## 3. Cellular LTE Modem Bringup (MT6768 CCCI / CLDMA)
* **Hardware / Architecture:** MediaTek Helio G70 (MT6768) integrated LTE modem (`md1img`), communicating with AP via CLDMA (Communication Logical DMA) over AP-MD shared memory (`0x78000000` - `0x79800000`).
* **Unified Kernel Driver:** `ccci.ko` (unified 1.8 MB module ported to mainline Linux 6.18) + `ccci_util_lib.ko`.
* **Key Technical Resolutions:**
  1. **MTCMOS MD1 Power Domain:** Bound `mdcldma@10014000` to `<&spm MT6768_POWER_DOMAIN_MD1>` in DTS and wired `pm_runtime_get_sync()` in `md_cd_power_on()`. Powers on MDTOP registers (`0x20140000`), allowing `md1_pll_init` to verify PLL version (`0x20160627`) and release MD boot slave (`MD boot slave = 0x1`).
  2. **CLDMA HIF Initialization Binding:** Exposed `ccci_cldma_hif_init()` and invoked it directly from `ccci_modem_probe()` so `cldma_ctrl` and RX/TX descriptor rings are initialized without requiring a detached DT node.
  3. **FSM State Machine:** Fixed `CCCI_COMMAND_START` (enum 1) in `boot_md_store()` and `ccci_md_register()`. Reset `needforcestop = 0` upon start and decoupled `dev_char_close()` in `ccci_fsm_monitor.c` so userspace queries don't inadvertently terminate modem.
  4. **Infracfg Regmap Fallback:** Added compatible fallback `syscon_regmap_lookup_by_compatible("mediatek,mt6768-infracfg_ao")` and guarded `cldma_plat_hw_reset()` against NULL/error pointers.
  5. **CCIF Driver Integration:** Mapped AP CCIF (`0x10209000`) and MD CCIF (`0x1020a000`) with interrupts 164 & 165, compiling `ccci_hif_ccif.o`, `ccci_ringbuf.o`, and `ccci_debug_info.o` directly into `ccci.ko`.
  6. **Fixed False `early exception detected`:** Added `-DMD_GENERATION=6293` to `cellular-port/eccci/Makefile` to prevent misidentification of channel 1 control messages as `D2H_EXCEPTION_INIT`.
  7. **Fixed ARM64 Alignment Fault in Register Dump:** Replaced raw `ccci_util_mem_dump()` on `ioremap` registers with safe 32-bit `readl_relaxed()` words to prevent kernel oopses in `__pi_memcpy_generic`.
  8. **Fixed Unload IRQ Storm:** Added `disable_irq()` and `free_irq()` in `ccci_cldma_exit()` and `ccci_ccif_exit()` to prevent unhandled interrupt storms when unloading `ccci.ko`.
  9. **Identified Queue 1 RPC Traffic:** Verified that incoming Queue 1 packets are `channel=32` (`CCCI_RPC_RX`), which the modem uses to query hardware pins/clocks before completing Handshake 2.
  10. **ROOT CAUSE OF HS2 STALL FOUND (Oct 25, 2026) — Missing SIM1 Hot-Plug EINT DT Node:**
      * After HS1 the modem sends exactly **12 RPC packets** (`op_id=0x4005`, `IPC_RPC_GET_EINT_ATTR_OP`) covering `MD1_SIM1..SIM4_HOT_PLUG_EINT` × 3 query types (`SRCPIN`=6, `NUM`=0, `DEDICATEDEN`=5), and our driver answered **all 12 with `ret=-11`** (`ERR_SIM_HOT_PLUG_QUERY_STRING`).
      * After those replies the modem goes **completely silent**: `rxq1 isr_cnt=12`, **`rxq4 isr_cnt=0`** (FSD queue), `rxq15 isr_cnt=1` (= HS1 on CCIF channel 15). Boot stats freeze at `md_boot_stats0=0x54430007` ("TC 7") / `md_boot_stats1=0x53320000` ("S2"), and `MD_BOOT_HS2_FAIL!` fires 30 s later.
      * **The FSD theory is not yet the blocker:** with `ccci_fsd.py` already running and `/dev/ccci_fs` open, the modem still issued **zero** FSD requests. FSD is required later, but the modem never reaches the NVRAM stage.
      * **Real difference from stock Android:** the stock boot DTB only contains an empty stub `md1_sim1_hot_plug_eint { phandle = ... }`. The real descriptor lives in the **DTBO overlay `fragment@36`** (`ke7_dump/dtbodts/01_dtbdump_fragment@0.dts` ~line 956) with `compatible = "mediatek,md1_sim1_hot_plug_eint-eint"`, `debounce = <0 10000>`, `dedicated = <0 0>`, `interrupts = <0 8>` (EINT 0, `IRQ_TYPE_LEVEL_LOW`), `sockettype = <0 0>`, `src_pin = <0 1>`, `status = "okay"`.
      * Our mainline DTS had **no such node at all**, so `get_dtsi_eint_node()` logged `MD1_SIM1_HOT_PLUG_EINT: node 0 no found`. On stock, SIM1 answers are valid (SIM2-4 legitimately fail — this is a single-SIM device), so the MD's `md_init` continues. With SIM1 also failing, the MD halts.
      * **Fix applied:** added the node verbatim to `mt6768-tecno-ke7.dts` under `&{/soc}`, right after `mdcldma`. Rebuilt DTB (45,611 bytes, md5 `c9d54203f69a44b4056a23591ec22835`) and deployed to `/boot/mt6768-tecno-ke7.dtb` **and** `/boot/mt6768.dtb` (both used by U-Boot), with `.bak` copies of the previous 45,369-byte DTB kept in `/boot`.
  11. **Operational hazards discovered:**
      * **Never `rmmod ccci` + `modprobe ccci` in the same boot** — the second load hard-hangs the kernel (USB gadget dies, no network, requires a physical power cycle). No reliable FSM reset path without a reboot; reboot instead of reloading.
      * **`systemctl reboot` DOES work** (corrected Oct 25, 2026 — the earlier "phone powered off" conclusion was wrong). The phone comes back in ~50 s, but it comes back on **Wi-Fi only**: the USB gadget does not re-attach by itself, so over USB it looks dead. Command that works: `ssh ... "(sleep 1; systemctl reboot) >/dev/null 2>&1 &"`.
  12. **NVRAM partitions are entirely erased:** `/dev/mmcblk0p8` (nvcfg), `p9` (nvdata), `p10` (persist), `p11`/`p12` (protect1/2) and `p26` (nvram) read back as **all zero bytes** (verified `tr -d '\000' | wc -c` = 0). The pre-repartition dumps in `~/tecno_ke7_linux_port/backup/` (`nvdata.bin`, `nvcfg.bin`, `persist.bin`, `protect1.bin`, `protect2.bin`, `nvram.bin`) are **also 100% zero**, so the data was already lost before the backup was taken. No ext4 superblock (`0x53EF` at offset 0x438) exists in any of them. Consequences: no RF calibration and no IMEI; a restore will be required before network registration can work.
  13. **Process rules codified in `AGENTS.md` / `GEMINI.md` (Oct 25, 2026):** The project instruction files now contain §1 memory protocol, §2 mandatory working protocol (read-before-acting, write-while-acting, minimum write cadence, what/where to record, commit-as-you-go, secret handling), §4 hard-won operational hazards (no `ccci` reload, `systemctl reboot` needs manual power-on, do not trust `ccci_mdinit.py` state, harmless `swtp`/`dtc` warnings, 3-step device-unreachable triage), §5 the modem bring-up runbook and queue map, and §6 build/deploy conventions. Any future session must follow them without being asked.

### 3.14 Current Blocker (as of this update)
* **ROOT CAUSE FOUND & FIXED IN U-BOOT (Oct 25, 2026):** The modem bus-hangs on EINT_SRC write because the MD EINT controller clock is gated off. The fix is writing `0x21` to `INFRA_AO_MD_SRCCLKENA` (INFRACFG_AO `0x10001000` + `0xF0C`) **in U-Boot before the modem boots**. Fix implemented in `u-boot/arch/arm/mach-mediatek/mt6768/init.c` (`board_late_init()`). U-Boot rebuilt (700576 bytes). **NOT YET FLASHED** -- need to write to correct boot partition (likely p1, p2, or p4). Once flashed, modem should reach READY and USB gadget will enumerate.
* Phone reachable only over **Wi-Fi SSH** (IP changes on nearly every boot; rediscover with ping sweep of `10.96.213.0/24`, laptop = `10.96.213.247`).

### 3.15 CORRECTION (Oct 25, 2026, later) — EINT is NOT the HS2 blocker; §29 hypothesis disproved
* Public leaked **MOLY.LR12A.R3.MP** source proves the 12 RPCs are `EINT_Setting_Init()` **phase 1** (SRCPIN=6, NUMBER=0, DEDICATEDEN=5 per SIM). Every getter has a default; the function has no failure branch, no return, no wait — it **cannot stop the MD**.
* The 5 missing queries (NUMBER, DEBOUNCE=1, POLARITY=2, SENSITIVITY=3, SOCKET=4) belong to `L1sim_Reset_All()` **phase 2**, which runs only when the SIM task starts card reset (VSIM on). They are absent because the MD never reaches SIM card reset, not because EINT registration aborted.
* The DT node values are canonical (`dedicated=<0 0>`, `src_pin=<0 1>`, `interrupts=<0 8>`, `debounce=<0 10000>`) — identical to Motorola/Infinix/KT-R1 stock DTS. Adding it cannot fix HS2.
* `0x54430007` / `0x53320000` are **normal post-HS1 markers**: a public working MT6765 log shows the same values at HS1 and reaches HS2 0.42 s later (`control 0x0,0x0`, `md_state 3->4`).
* `no md eint settings in DWS, LEAVE_REG_EINT` is set only when an AP RPC returns <0; it skips registration and **continues**. DWS = `codegen.dws` (build-time DCT config), not an NVRAM database. Zeroed `nvdata`/`nvram` does not affect the EINT path.
* Next: find the stall **before** SIM card reset (after `custom_drv_init`/`EINT_Setting_Init`, before the SIM task's first reset request). Instrument all RPC `op_id`s after HS1.
* Full source excerpts/URLs: `HARDWARE_RESEARCH_AND_DRIVER_RE.md` §31.

---

## 3. Wi-Fi Subsystem (CONNSYS Gen4m) Implementation Status
* **Hardware Chipset:** MediaTek MT6631/MT6635 CONNSYS Gen4m integrated Wi-Fi/BT.
* **Firmware:** `WIFI_RAM_CODE_soc1_0_1a_1.bin` placed in `/usr/lib/firmware/` and `/lib/firmware/`.
* **DTS Nodes in Live DTB:**
  - `btif@1100c000` (BTIF hardware controller)
  - `consys@18002000` (CONNSYS APB bridge)
  - `wifi@18000000` (Wi-Fi DMA & control registers)
  - Reserved memory regions: `conn_emi_mem` (`0x5e000000`), `conn_infra_mem`.

### Driver Module Stack (`~/Documents/tecno_ke7_linux_port/wifi-port/`):
1. **`wifiport_shim.ko` [DONE]:**
   - Out-of-tree kernel symbol shim and SDIO/AXI stubs.
   - Built and tested on device.
2. **`btif_drv.ko` [DONE]:**
   - Hardware probed at physical base `0x1100c000`.
   - Built and tested on device.
3. **`wmt_drv.ko` [DONE]:**
   - CONNSYS subsystem management driver (2.85 MB).
   - Built and tested on device.
4. **`wmt_chrdev_wifi.ko` [DONE]:**
   - Provides character device node `/dev/wmtWifi`.
   - Toggles CONNSYS Wi-Fi power rail and firmware download sequence.
   - Built and tested on device.
5. **`wlan_drv_gen4m.ko` [COMPLETE - BUILT]:**
   - Main 802.11 cfg80211 mac80211 wireless driver.
   - Linux 6.18 API updates applied:
     * `timer_delete` / `timer_delete_sync`
     * `class_create`
     * MLO link structs in `gl_kal.c` (`rRoamInfo.links[0].bss`)
     * `cfg80211_ch_switch_notify` (3 arguments with `link_id = 0` in both `gl_kal.c` and `gl_p2p_kal.c`)
     * `MODULE_INFO(import_ns, ...)`
     * `gl_cfg80211.c`: Fixed `mtk_cfg80211_tdls_mgmt` definition and mapped `station_parameters` rate/HT/VHT capabilities via `params->link_sta_params`.
     * `gl_p2p.c`: Replaced 4-arg `netif_napi_add` with `netif_napi_add_weight`.
     * `os/linux/hif/axi/axi.c`: Updated `mtk_axi_remove` return type to `void` for Linux 6.11+ `platform_driver`.
     * `os/linux/hif/common/kal_pdma.c`: Updated `kalAmsduTxDCmp` signature to `const struct list_head *` for `list_sort`.

---

## 4. Immediate Action Checklist
- [x] Create project persistent memory rule (`AGENTS.md` and `GEMINI.md`).
- [x] Fix `station_parameters` compatibility in `gl_cfg80211.c` for Linux 6.18.
- [x] Finish compilation and linking of `wlan_drv_gen4m.ko`.
- [x] Deploy all 5 modules to `/usr/lib/modules/6.18.0-gf612f7e0293a-dirty/extra/` on the phone.
- [x] Fix CONNSYS MTCMOS genpd + MT6358 PMIC (`vcn18`, `vcn28`, `vcn33`) power-on in `wmt_drv.ko`.
- [x] Fix `btif@1100c000` & AP_DMA interrupts (`GIC_SPI 133, 115, 141`) in `mt6768-tecno-ke7.dts` and `btif_drv.ko`.
- [x] Verify full CONNSYS MCU boot (`0x6768`), MCU patch download (`soc1_0_patch_mcu_1a_1_hdr.bin`, 26 fragments), and RF calibration (`gBTCalResultSize=448`, `gWiFiCalSize=8192`).
- [x] Debug and resolve `wlanDownloadFW` (`gConEmiPhyBaseFinal` initialization order in `axi.c` / `fw_dl.c` and `eth_hw_addr_set` for Linux 6.18).
- [x] Verify `wlan0` interface appears in `ip link` and NetworkManager with working 2.4 GHz & 5 GHz Wi-Fi scanning (`nmcli dev wifi list`).
- [x] Install and enable `connsys-wifi.service` (`/usr/local/bin/connsys-wifi-daemon.py`) and update `/boot/mt6768-tecno-ke7.dtb` for automatic Wi-Fi bringup across reboots.
- [x] Connect `wlan0` to Wi-Fi (`172.25.215.128/24`) and verify direct SSH over Wi-Fi and direct internet routing.
- [x] Write, compile, and verify `bt_drv.ko` (`hci0`, MediaTek BT 5.0 `02:00:00:00:00:02`) with `bluez` (`bluetooth.service`) and `bluez-utils`.
- [x] Identify and fix `N_TTY` line discipline 0 overwrite bug in `wmt_drv.ko` (`stp_uart.c` missing `stp_uart_ldisc.num = N_MTKSTP`) that caused `kgx` terminal to hang.
- [x] Download official signed Tecno KE7 `md1img.img` (`57.8 MB`) to `~/tecno_ke7_linux_port/flash_images/md1img.img`.
- [x] Flashed official signed Tecno KE7 modem firmware `md1img.img` (57,860,848 bytes) to `/dev/mmcblk0p18` and verified bit-for-bit with `cmp`.
- [x] Patched U-Boot (`mt6768_copy_lk_chosen_ccci()`) in `u-boot/arch/arm/mach-mediatek/mt6768/init.c` to forward LK's `/chosen/ccci,*` properties into Linux DTB. Built and repacked `boot-uboot.img` with AVB footer and flashed to `/dev/mmcblk0p30`.
- [x] Installed `modemmanager` and `usb_modeswitch` on phone via pacman; enabled `ModemManager.service`.
- [x] Ported and compiled `ccci_util_lib.ko` (382 KB) and unified `ccci.ko` (1.8 MB, including CLDMA, CCCI char ports, UDC, and `ccmni` network driver) for upstream Linux 6.18.
- [x] Added `mdcldma@10014000` device node to `mt6768-tecno-ke7.dts` and installed compiled DTB to `/boot/mt6768-tecno-ke7.dtb`.
- [x] Deployed `ccci_util_lib.ko` and `ccci.ko` to `/lib/modules/6.18.0-gf612f7e0293a-dirty/extra/` on phone.
- [x] Pinpointed and resolved kernel NULL pointer dereference in `ccci_md_register` -> `ccci_port_init` -> `port_smem_init`:
  * Root cause 1: `ccci_md_config` aborted early when `amms_cma_allocate` (weak stub returning 0) did not match `md_resv_smem_addr` (0x78000000), leaving shared memory regions uninitialized. Fixed to allow static LK allocation when `bank4_phy_addr == 0`.
  * Root cause 2: `ccci_init()` in `ccci_core.c` was never executed when compiled as a loadable module, leaving `dev_class` uninitialized and causing `-ENODEV` (ret=-19) on all device node creations. Fixed by calling `ccci_init()` and `ccci_exit()` from `modem_cd_init()`/`modem_cd_exit()` in `modem_sys1.c`.
  * Root cause 3: Added NULL pointer check for `ccb_ctl` in `port_smem_init` and `port_smem_rx_poll`.
- [x] Resolved USB charging & data concurrency:
  * Overcame standard USB 2.0 SDP 500mA charging bottleneck by boosting RT9471 input current limit to 1.5A (`1500000` uA) via persistent udev rule (`99-charger-fastcharge.rules`) and `/usr/local/bin/usb-charger-boost.sh`, allowing simultaneous USB networking and battery charging.
  * Linked `fuel-gauge` (`adc-battery`) to `charger` (`rt9471`) via `power-supplies = <&charger>` in device tree so Phosh and GNOME Settings reflect active charging state.
- [x] Ported and verified modem power sequencing:
  * Added `power-domains = <&spm MT6768_POWER_DOMAIN_MD1>` to `mdcldma@10014000` in `mt6768-tecno-ke7.dts`.
  * Wired `pm_runtime_get_sync()` in `md_cd_power_on()` to power on MD1 MTCMOS domain.
  * Added bounded retry loop (`cnt < 50`) to `md1_pll_init()` to safeguard against kernel hang.
  * Enabled user-accessible modem boot control via `boot_md_store` (`/sys/kernel/ccci/boot`) and removed `VALID_USER` restriction from `CCCI_IOC_DO_START_MD`.
- [x] Verified Handshake 1 (`CCCI_EVENT_HS1`):
  * Modem booted through Stage 2 (`S2`), Task Create 7 (`TC 7`).
  * CCIF SRAM Handshake 1 received (`control message 0x0, 0x5555FFFF`).
  * State changed from `BOOT_WAITING_FOR_HS1` to `BOOT_WAITING_FOR_HS2`.
  * Runtime data successfully prepared and transmitted (`send runtime data 0`).
  * All 21 `ccmni` network interfaces (`ccmni0`-`ccmni20`) and CCCI character nodes (`/dev/ttyC0`-`ttyC6`, `/dev/ccci_*`) registered.
  * Discovered and fixed root cause of ARM64 alignment fault in `ccci_util_mem_dump` by switching from unaligned pointer casts to safe 32-bit `readl_relaxed()`.
- [x] Identified and fixed system power-off hang and auto-reboot:
  * Root cause 1: Mainline Linux on ARM64 defaults to PSCI `SYSTEM_OFF` when shutting down. On MediaTek MT6768, PSCI `SYSTEM_OFF` returns `PSCI_E_NOT_SUPPORTED` from ATF, expecting the kernel PMIC driver to shut down power rails. `CONFIG_POWER_RESET_MT6358` was not enabled in kernel config.
  * Root cause 2: Discovered MT6358 RTC write protection register `MT6358_RTC_PROT` (`0x5bc`) defaults to locked state (`0x9136`), causing all RTC configuration writes to silently fail until unlocked with sequence `0x9136` -> `WRTGR=1` -> `0x586a` -> `WRTGR=1`.
  * Root cause 3: Discovered 2-second auto-reboot timer `PMIC_BBPU_2SEC_EN` (Bit 8) and `PMIC_BBPU_AUTO_PDN_SEL` (Bit 6) set in `MT6358_RTC_AL_SEC` (`0x5a0` = `0x25f0`), which forces MT6358 hardware to automatically power back on 2 seconds after power rails drop.
  * Root cause 4: Discovered `mt6358-poweroff.c` was setting `RTC_BBPU_PWREN` (`BIT(0)`), explicitly keeping power enabled.
  * Root cause 5: Discovered that `machine_power_off()` on ARM64 disables CPU interrupts (`local_irq_disable()`). The power-off callback was using `regmap_write()` / `regmap_read()`, which under `mtk-pmic-wrap` called `readx_poll_timeout` -> `usleep_range()`. Calling `usleep_range()` with interrupts disabled caused the CPU to wait forever for a timer interrupt that never arrived, freezing the kernel at `reboot: Power down`.
  * Fix: Rewrote `drivers/power/reset/mt6358-poweroff.c` to pre-map PWRAP MMIO (`0x1000d000`) at probe time and eliminated all regmap/sleeping calls from `mt6358_do_pwroff()`. The driver now uses pure atomic direct MMIO with `udelay()` busy-polling to unlock RTC (`0x9136`/`0x586a`), disable 2-sec auto-restart (`0x24b0`), clear BBPU power latches, and clear `PMIC_RG_PWRHOLD` in `MT6358_RG_PPCCTL0` (`0xa08`).
  * Compiled `mt6358-poweroff.ko` with exact kernel vermagic match, deployed to `/lib/modules/6.18.0-gf612f7e0293a-dirty/extra/`, configured persistent autoloading in `/etc/modules-load.d/poweroff.conf`, and verified driver probe and binding.
- [x] Resolved CCCI Driver Crashes & Reload Stability:
  * Fixed NULL pointer dereference in `ccci_ringbuf_reset()` (`hif/ccci_ringbuf.c`) for Queue 0 (SRAM queue where `ringbuf == NULL`).
  * Fixed Linux 6.18 `WARN_ON(!work->func)` in `flush_work(&md_ctrl->rxq[i].qwork)` in `hif/ccci_hif_ccif.c` by verifying `qwork.func` before flush.
  * Fixed IRQ 277 (`MD_WDT`) leak on module unload in `modem_sys1.c` by freeing `md->md_wdt_irq_id` in `modem_cd_exit()`.
- [x] Reverse-Engineered CCCI Userspace Boot Flow (`ccci_mdinit`):
  * Disassembled `ccci_mdinit` entry point `0xc001` and main `0xc0d8`.
  * Identified exact ioctl handshake: `CCCI_IOC_SET_BOOT_DATA` (`_IOW('C', 47, ...)` / `0x4040432f`), `CCCI_IOC_DO_START_MD` (`_IO('C', 13)` / `0x430d`), and `CCCI_IOC_GET_MD_STATE` (`_IOR('C', 1, ...)` / `0x80044301`).
- [x] Resolved Premature Modem Auto-Start Bug:
  * Removed erroneous `fsm_append_command(fsm_get_entity_by_md_id(md->index), 1, 0)` from `ccci_md_register()` in `cellular-port/eccci/ccci_modem.c` (line 1304) which was starting the modem with empty parameters before userspace could call `CCCI_IOC_SET_BOOT_DATA`.
  * Rebuilt and deployed clean `ccci.ko` to `/lib/modules/6.18.0-gf612f7e0293a-dirty/extra/ccci.ko`.
- [x] Reverse-Engineered & Implemented CCCI File System Daemon (`ccci_fsd`):
  * Uncovered exact `/dev/ccci_fs` framing (4-byte length prefix + 20-byte CCCI header + packed payload) and all file opcodes (`OPEN`, `SEEK`, `READ`, `WRITE`, `CLOSE`, `CMPT_READ`, `CMPT_WRITE`, `GETFILESIZE`, `DELETE`, `FINDFIRST`, `FINDNEXT`, `FINDCLOSE`).
  * Mapped DOS drive letters used by modem: `Z:` (`/mnt/vendor/nvdata/md`), `X:` (`/mnt/vendor/protect_f/md`), `Y:` (`/mnt/vendor/protect_s/md`), `W:` (`/mnt/vendor/firmware`), `V:` (`/mnt/vendor/nvdata/md_cmn`), `U:` (`/mnt/vendor/mdlpm`), `T:` (`/mnt/vendor/etc/mdota`), `S:` (`/mnt/vendor/nvcfg`).
  * Verified why AT port `/dev/ttyC0` returns `-ENODEV`: in `port_proxy.c`, all char ports reject communication during `BOOT_WAITING_FOR_HS2` except `CCCI_FS_TX` and `CCCI_RPC_TX`. The baseband modem requires FSD to answer its NVRAM calibration queries before sending Handshake 2.
  * Extracted and deployed standalone, pure-Python CCCI FSD daemon to `/usr/local/bin/ccci_fsd.py` on the phone.
  * Implemented and deployed companion modem init script `/usr/local/bin/ccci_mdinit.py` on the phone.
- [x] Verified Phosh Mobile Desktop & UI Subsystems:
  * Verified GNOME Phosh mobile desktop shell running smoothly at 720×1640 @ 60Hz.
  * Verified squeekboard virtual keyboard, GNOME Console with VTE shell markers, and concurrent 1.5A fast charging indicator.
  * Verified clean system power-off from UI without reboot hangs.
- [x] Run `ccci_fsd.py` and `ccci_mdinit.py` on phone with FSD started **before** modem boot (verified `/dev/ccci_fs` open, `md1:0` clean start).
- [ ] **Verify the SIM1 hot-plug EINT DT node fixes the HS2 stall** — rebuild/deploy done, awaiting phone power-on. Check for `rxq4 isr_cnt > 0` (FS requests) or direct `md_state change from 3 to 2` (READY).
  * **SUPERSEDED (Oct 25, 2026):** leaked LR12A.R3.MP source analysis shows EINT is **not** on the HS2 critical path (see §3.15 / HARDWARE §31). Keep the node (it is correct), but expect HS2 to still fail; debug the pre-SIM-reset init stage instead.
- [ ] Mount NVRAM partitions and populate them before the modem starts asking for files (`/mnt/vendor/nvdata/md`, `protect_f/md`, `protect_s/md`, `nvcfg`, `nvdata/md_cmn`, `mdlpm`, `etc/mdota`, `firmware`).
- [ ] Recover NVRAM/RF calibration + IMEI (p8-p12, p26 are fully erased; user can supply the device IMEI).
- [ ] Verify SIM detection (Jazz SIM) via AT commands (`AT+CPIN?`, `AT+CSQ`, `AT+COPS?`) and test data connection over `ccmni0`.
- [ ] Bring up Audio (`snd-soc-mt6768-afe` + `mt6768-mt6358` + GPIO 39 2-pulse external speaker amp).

---

## 5. CRITICAL: MT6768 Boot Chain & Recovery (learned the hard way, Oct 25 2026)

### The real boot chain (KE7)
```
BROM -> Preloader -> LK (partition `lk`, p27) -> U-Boot (packed inside `boot`, p30) -> Linux kernel (ESP /boot)
```
- `lk` / `lk2` (p27 / p28, 2 MB each) contain **LK (Little Kernel)**, NOT U-Boot.
- `boot` (p30, 32 MB) contains **U-Boot packaged as an Android boot image** (`boot-uboot.img`):
  header magic `ANDROID!`, kernel slot = **gzip-compressed `u-boot.bin`**, plus the original ramdisk + DTB.
- LK GUNZIPS the kernel slot before jumping. A raw ARM64 `u-boot.bin` in that slot → `lk_crash`.
- An AVB hash footer (`--partition_name boot --partition_size 33554432`) is mandatory; without it LK crashes.
- LK falls back to `lk2` if `lk` is corrupt, which is why a bad `lk` flash could still boot Linux (but with broken display/logo/SSH).

### THE MISTAKE THAT WAS MADE
Raw `u-boot.bin` (700 KB) was written to the `lk` partition (2 MB) via `mtk.py w`. This is **wrong**:
- It corrupts LK, so the boot chain/display/logo/orange-state suppression regress.
- Recovery needs BROM + reflashing `lk`/`lk2` **and** `boot`.

### Correct deployment of a new U-Boot (never touch `lk` for U-Boot)
1. Build: `make CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc)` → `u-boot/u-boot.bin`
2. Pack (preserves LK-accepted addresses/ramdisk/DTB, re-gzips u-boot):
   ```
   python3 mt6768-mainline-notes/scripts/pack-uboot-boot.py boot-uboot.img u-boot/u-boot.bin /tmp/boot-uboot-new.img
   ./venv/bin/avbtool add_hash_footer --image /tmp/boot-uboot-new.img \
       --partition_name boot --partition_size 33554432 --algorithm NONE
   ```
3. Flash **only `boot`**: `mtk.py w boot /tmp/boot-uboot-new.img` (BROM) or fastboot/dd.
4. `lk` and `lk2` stay untouched.

### Restore known-good state (if boot is broken)
- `lk`  <- `flash_images/lk_patched.img` (patched LK: boots unsigned images, removes orange state)
- `lk2` <- `flash_images/lk_patched.img`
- `boot` <- `boot-uboot.img` (known-good pre-MD-fix U-Boot image, 33,554,432 B)
- Commands (BROM): `mtk.py w lk flash_images/lk_patched.img` then `mtk.py w lk2 flash_images/lk_patched.img` then `mtk.py w boot boot-uboot.img`
- Do NOT reboot between the three writes; do all writes, then `mtk.py reset`.

### MD EINT clock fix (the actual modem blocker)
- Vendor kernel writes `0x21` to `INFRA_AO_MD_SRCCLKENA` (`0x10001000 + 0xF0C = 0x10001F0C`) in `md_cd_power_on()`, but **too late** (MD already bus-hung).
- Fix moved into U-Boot `board_late_init()`: `mt6768_enable_md_src_clock()` in `u-boot/arch/arm/mach-mediatek/mt6768/init.c`.
- Verified compiled in: `board_late_init` does `mov x0,#0x1f0c; movk x0,#0x1000,lsl#16; mov w1,#0x21; str w1,[x0]`.
- Fixed image built at `/tmp/boot-uboot-mdclk.img` (33,554,432 B, AVB `boot`, gzip kernel decompresses byte-identical to `u-boot/u-boot.bin`).

### Recovery executed (Oct 25 2026 ~10:17)
- Detected BROM (HW code 0x707, ME_ID 5AD9DB24..., SBC/DAA true) via `/tmp/opencode/brom_watch.sh`.
- Wrote via mtkclient (Kamakiri DA bypass, all in one BROM session, no reboot between):
  - `lk`  <- `flash_images/lk_patched.img` (sector 1132544 = 0x22900000)
  - `lk2` <- `flash_images/lk_patched.img` (sector 1136640 = 0x22B00000)
  - `boot`<- `boot-uboot.img` (sector 1157120 = 0x23500000, 65536 sectors)
- Readback verification: `boot` byte-identical; `lk`/`lk2` identical over the 1,131,872-byte image, remainder zero-padded to 2 MB.
- Next: boot baseline and confirm display/SSH; then flash `boot-uboot-mdclk.img` to `boot` only and test modem HS2/READY.

### MD-fix U-Boot deployed to `boot` only (Oct 25 2026 ~10:22)
- Baseline verified healthy: kernel 6.18, Phosh/phoc running, DRM simple-framebuffer 720x1640@32bpp, no failed units.
- `boot` current sha256 prefix `8d72fdf2...` == `boot-uboot.img` (baseline), confirmed from device.
- Copied `boot-uboot-mdclk.img` (sha256 prefix `76e1afd0...`) to `/tmp` on phone, `dd` to `/dev/mmcblk0p30` (65536 sectors, not mounted), `conv=fsync`, readback sha256 matches exactly.
- `lk`/`lk2` untouched (still `lk_patched.img`).
- Rebooted. Next: confirm boot, then read `0x10001F0C` (expect 0x21) and run modem bring-up.

### Modem bring-up runbook (device)
```
systemctl stop ModemManager
modprobe ccci
mkdir -p /mnt/vendor/{nvdata/md,protect_f/md,protect_s/md,nvcfg,mdlpm,etc/mdota,firmware,nvdata/md_cmn}
setsid nohup python3 -u /usr/local/bin/ccci_fsd.py /dev/ccci_fs </dev/null >/tmp/ccci_fsd.log 2>&1 &
/usr/local/bin/ccci_mdinit.py
dmesg | grep -E "pcmon|ccci1|md1"
```
Expect at ~30 s HS2 timeout: `[ccci1/pcmon]` samples, EINT debounce/polarity/sensitivity/socket queries, VSIM powered, `md1:2` = READY.

### MD-clock U-Boot fix DEPLOYED but HS2 STILL FAILS (Oct 25 2026 ~10:25)
- Verified `0x10001F0C = 0x00000021` from Linux `/dev/mem` after boot => U-Boot fix persisted. So the MD EINT source clock is NOT (or not the only) blocker.
- Boot chain healthy: ccci loads, `md1:0`, FSD+mdinit start MD, HS1 OK (`control 0x0,0x5555FFFF`), runtime data sent, `md1:3` (WAITING_HS2).
- Failure is identical to before the fix:
  * `rxq1 isr_cnt=12` = exactly the SIM1 (3) + SIM2/3/4 (3x3) EINT RPCs; `rxq4 isr_cnt=0` (NO FS requests at all).
  * EINT queries stop after SIM1 `src_pin`(type 6) / `interrupts`(type 0) / `dedicated`(type 5). No debounce/polarity/sensitivity/socket.
  * `md_boot_stats0:0x54430007` is logged at HS1 completion (before EINT queries) => it is a normal MD boot marker, NOT a hang signature.
  * pcmon: `common+0x800: 00030022 ...`, `common+0x900: 00000001 ... 90db2110 90da875a`, only 1 PC sample in MD image range (`0xae84eda3`) out of 588, while `md2peri EN=0xc0380000 RDY=0xf9f8fc04`.
  * `dbg_apb[0x430] before=0x60 after=0x71` (debug APB clock open works).
- Conclusion: MD halts while processing SIM1 EINT setup, right before the debounce query, regardless of the MD SRCCLKENA. Next: audit our AP-side RPC EINT responses (type 5 `dedicated` / sim_info encoding) vs vendor `port_rpc.c`; a wrong value may send MD into a bad EINT configuration and hang.

---

## 31. Oct 25 2026 (later) — Clean instrumentation, CLDMA/CCIF clocks, and what the modem is actually doing

### 31.1 Removed the destructive debug hook (IMPORTANT)
`md_cd_dump_pcmon_dmesg()` used to do, at the HS2 timeout:
`SIP mdsrc_req`, `SIP md_rgu soft reset`, `pm_runtime_put_sync/get_sync` (MD domain power cycle)
and blind `writel(0xffffffff)` to CLKSW registers.

That **destroyed the state being observed** and left the MD reset without a re-boot (the FSM kept
reporting `md1:3` while the MD had never re-sent HS1; `rxq1` stayed at 12 forever).  The hook is now
**strictly read-only**: boot stats, INFRA_AO regs, full PC-monitor dump (0x0-0x7ff) + a
300 ms liveness re-sample, and a PMIC-wrapper register dump.  `md_cd_dump_debug_register()` is only
reached through `/sys/kernel/ccci/mdsys1/dump` (`echo register`) or the flight-mode/WDT path.

### 31.2 The modem is ALIVE and IDLE, not bus-hung
With the read-only hook, at HS2 timeout and again 6 minutes later:

```
boot_stats0=0x54430007   ("TC", 7 tasks created)
boot_stats1=0x53320000   ("S2" boot stage)
srclkena=0x00000021      (MD source clock enabled)
pcmon[0x000-0x7ff]: 495..499/512 words nonzero
pcmon words changed after 300ms: 144..170   <-- core is still executing
```

PC-monitor record format (16 bytes each, 0x0-0x7ff):
`{ pc_start, pc_end, timestamp, flags }`, e.g.

```
pcm 000: 90294d00 90294cf6 00032bc3 00000000
pcm 080: 90da875a 90da8740 0226b020 80090001
pcm 0a0: 90da8762 90da876c 0226b020 800b0001
pcm 0e0: 90b935a6 90b93596 0226b020 000e0001
```

The executed set is a handful of small loops (`0x90294cf6-0x90294d2e`, `0x90da8740-0x90da876c`,
`0x90b93596-0x90b935a6`) with IRQ flags 0x08/0x09/0x0b/0x0d/0x0e -> **the MD sits in an idle/timer
loop waiting for an event**, it is not stuck on a bus access.  Boot stats never advance past S2/TC7.

`md1img.img` code is **not disassemblable** (entropy ~7.0, no `bx lr`/prologue patterns) -> the code
regions are compressed/obfuscated even though the string/literal tables are plaintext.  Static RE of
the stall point is not viable.

### 31.3 SIM hot-plug reinsert has no effect
User physically removed and re-inserted the SIM1 tray while the MD was idle.  `rxq1` stayed at 12,
no RPC/CCIF traffic, no state change.  The MD is **not** waiting for the SIM-detect EINT at this point.

### 31.4 GPIO47 (SIM1 detect) is muxed and reads HIGH
Raw pinctrl registers (0x10005000):
```
0x350: GPIO47 mode = 1 (MD_INT1_C2K_UIM0_HOT_PLUG)
0x210: DIN bit15 = 1  -> pad HIGH  (= "card inserted" per MTK convention)
```
`pinctrl` debugfs confirms pins 47/172/173/174 claimed by `10014000.mdcldma`, function func1.

### 31.5 VSIM1/VSIM2 are still OFF
`/sys/kernel/debug/regulator/regulator_summary`: `vsim1`/`vsim2` disabled, 1860 mV.
The MD never got as far as powering the SIM.

### 31.6 Added the vendor's CLDMA/CCIF clocks to `mdcldma`
Stock DTB has 8 clocks on `mdcldma@10014000`; our node had none, so
`ccci_hif_ccif` / `ccci_hif_cldma` `devm_clk_get()` calls all failed and the gates were never
enabled by the driver.  Added (vendor order, mainline IDs are identical to the vendor's):

```
clock-names = "infra-cldma-bclk", "infra-ccif-ap", "infra-ccif-md",
              "infra-ccif1-ap", "infra-ccif1-md", "infra-ccif2-ap", "infra-ccif2-md";
clocks = <&infracfg_ao CLK_INFRA_CLDMA_BCLK>, <&infracfg_ao CLK_INFRA_CCIF_AP>,
         <&infracfg_ao CLK_INFRA_CCIF_MD>, <&infracfg_ao CLK_INFRA_CCIF1_AP>,
         <&infracfg_ao CLK_INFRA_CCIF1_MD>, <&infracfg_ao CLK_INFRA_CCIF2_AP>,
         <&infracfg_ao CLK_INFRA_CCIF2_MD>;
```

**Do NOT add `<&scpsys 0>` ("scp-sys-md1-main")**: mainline `mtk-pm-domains` is not a clock provider,
so `clk_get` returns -EPROBE_DEFER and the whole `mdcldma` device never probes (`md1:n/a`).
**Result: no behaviour change** (HS2 still missing) - the gates were already on from LK/U-Boot.

### 31.7 LK memory layout IS available from U-Boot
`/chosen/ccci,modem_info_v2` survives (U-Boot passes LK's FDT through), so the driver logs
`using v3`: `md1 MemStart=0xae000000 size=0x07e00000`, `AP<->MD1 SMEM 0x78000000-0x797fffff`,
`csmem 0x7c000000+23199744`, and the kernel correctly reserves them
(`/proc/iomem`: `77ff0000-797fffff reserved`, `7c000000-7d61ffff reserved`).
Runtime data is accepted by the MD (`rt-data: H2D_SRAM busy cleared after 0ms`).

### 31.8 Everything ruled out so far
- SRCCLKENA (0x21) - set, no effect.
- CCIF/CLDMA infra clocks - now requested/enabled, no effect.
- SIM hot-plug EINT event - modem ignores reinsert.
- MD power domain / MTCMOS - on (`pm_runtime_get_sync ret=0`, `0x10006320=0x10d`).
- PMIC wrapper - all masters enabled (`WACS_MD32_EN=1`, `INIT_DONE_MD32=1`), AP regulators work.
- MD exception - none (`D2H_EXCEPTION_INIT` channel never fires, `rxq*` only 1 and 15).
- Runtime data delivery - doorbell cleared, `send runtime data 0`.
- Memory layout / reservations - correct (`using v3`, reserved in iomem).

### 31.9 Open items / next experiments
1. `scp-sys-md1-main` gate: SCPSYS at 0x10006000 is **not** a clock provider in mainline
   and `0x10006000` is SPM `POWERON_CONFIG_EN[0]`, not a gate register. The vendor clock is a
   *virtual power-gate clock* that runs the MD1 MTCMOS sequence — see §31.13 and HARDWARE doc §30.
2. AP feature mask experiment: force all runtime-data features except BOOT_INFO to NOT_SUPPORT and
   see whether the MD reacts (needs ccci.ko rebuild + reboot).
3. MD log: mode != 0 (`booting_start_id=0x300`) is accepted but the MD writes nothing before HS2
   (CCB devices `rx_len=0 empty=1`); DHL logging starts only after HS2, so it cannot be used here.
4. `mdccci_dbg` smem on HS2 timeout begins with `CCCI`/`EDBG`/`0x70000007`, `+0x28=0x40050006`
   (last RPC op 0x4005 / type 6).  No exception PC captured; AP never saw an EE.
5. `/sys/kernel/ccci/mdsys1/dump` supports `ccif`, `register`, `smem_exp`, `smem_ccism`,
   `smem_ccb_ctrl`, `smem_ccb_data`, `pccif`, `image`, `layout`, `mdslp`, `port`, `cldma`.
   `smem_ccb_ctrl` / `smem_ccb_data` currently dump nothing (regions empty / flags unimplemented).

### 31.10 Files changed today
- `cellular-port/eccci/mt6768/md_sys1_platform.c`: rewrote `md_cd_dump_pcmon_dmesg()` read-only
  (backup of the previous version: `/tmp/opencode/md_sys1_platform.c.bak` on the laptop).
- `linux/arch/arm64/boot/dts/mediatek/mt6768-tecno-ke7.dts`: added the 7 infracfg clocks to
  `mdcldma` (DTB md5 `7f04279830ace571a566b6634ca9303c`, deployed to `/boot/mt6768-tecno-ke7.dtb`
  and `/boot/mt6768.dtb`).
- Deployed `ccci.ko` sha256 `54109cf17a1dbc80a61f46777c4dcd97e7fa411d4b8e533142bd36904b31d14c`
  to `/lib/modules/6.18.0-gf612f7e0293a-dirty/extra/ccci.ko` (old one saved as `ccci.ko.bak3`).
- **Device note:** `ccci` no longer auto-loads at boot on this image; run `modprobe ccci` first.

### 31.11 Handy live commands
```
modprobe ccci
echo register > /sys/kernel/ccci/mdsys1/dump   # read-only snapshot -> dmesg
echo ccif     > /sys/kernel/ccci/mdsys1/dump   # CCIF SRAM dump   -> dmesg
cat /sys/kernel/ccci/boot                      # md1:0..4 (3 = waiting HS2)
python3 /tmp/start_md.py [mdlog_mode]          # SET_BOOT_DATA + START_MD + poll state
```

### 31.12 Oct 25 2026 (night) — new experiments and results

**A. The DRAM modem image is byte-identical to md1img.img (no decompression).**
Read through the linear map (`__va()`, because `ioremap()` refuses: `pfn_is_map_memory()` is true for the
whole DRAM window 0x40000000-0x13fffffff):
```
md_resv base=0xae000000 size=0x7e00000
img+0000   = 50 01 06 3c 78 5a c6 24 ...   == file[0x000200]
img+da8750 = a0 e8 00 65 9c a7 18 62 ...   == file[0x0da8950]
img+294cf0 = 65 67 40 f0 88 42 00 6d ...   == file[0x0294ef0]
```
So LK copies the payload (file offset 0x200) verbatim to MD 0x90000000 / AP 0xae000000, and the
firmware code really is obfuscated at build time (entropy ~7.0, no ARM/Thumb prologues).  Static RE of
the stall loop is impossible without the hardware decryptor.

Confirmed reserved in `/proc/iomem`: `ae000000-bdffffff reserved` (MD image),
`77ff0000-797fffff reserved` (AP<->MD1 smem), `7c000000-7d61ffff reserved` (csmem).

**B. Vendor DTS difference: empty `md1_sim2_hot_plug_eint` stub.**
The stock KE7 DTB keeps an empty (phandle-only) SIM2 node.  Because `get_eint_attr_DTSVal()` returns
`-11` **with a 4-byte payload of -12** when the node exists but its properties are missing, and `-11`
with an **empty payload** when the node does not exist, our reply stream for SIM2 differed from the
vendor's.  Added the empty stub (DTB md5 `9936488c29a94617f7a0355494726a69`).
**Result: no change** — still exactly 12 RPCs then idle.

**C. Runtime-feature bisection is now possible via a module parameter.**
Added `md_feature_force_min` (ccci module param).  With `modprobe ccci md_feature_force_min=1`
(every optional AP feature forced to NOT_SUPPORT, only BOOT_INFO kept) the modem **immediately raises a
proper MD exception**:
```
[ccci1/fsm] md_state change from 2 to 3
[ccci1/mcd] runtime features forced to BOOT_INFO only
[ccci1/fsm] md_state change from 3 to 5
[ccci1/exp] md_cd_ccif_isr: RCHNUM=0x00060000
[ccci1/exp] md_fsm_exp_info: channel_id=0x60000 D2H_EXCEPTION_INIT=16
```
Consequences:
- The modem's exception signalling **works** and our driver detects it (so the normal stall is NOT a
  hidden exception).
- The modem **validates the AP feature reply**; missing mandatory feature data kills it in ~24 ms.
- Boot stats do not change on the exception path (still S2/TC7), so they only record early boot.
- This gives us a bisection knob: enable feature groups one at a time and look for a run where the
  modem reaches HS2 (or changes its stall point).

**D. SCPSYS snapshot (read-only) while the modem idles:**
```
0x10006000=00000001 004=1600f100 008=00815838 00c=0800b06c
0x10006010=00000021 028=00815838 180=860f442f 184=860f442f
0x10006320=0000010d 398=00000001
```
`0x10006000` bit0 is already 1 (vendor `scp-sys-md1-main` gate looks enabled by LK); mainline
`mtk-pm-domains` has no clock provider, so it cannot be toggled from Linux today.

**E. Device passwords set (user request):** `root` and `alarm` passwords are now `<redacted>`;
`alarm` already has `NOPASSWD` sudo via `/etc/sudoers.d/alarm` and `/etc/sudoers.d/99-alarm`.
Phosh runs as `alarm`.

### 31.13 MT6768 vendor power/clock research (Oct 25, 2026) — see HARDWARE doc §30
- **`scp-sys-md1-main` is not a clock gate on MT6768/MT6765.** It is a virtual power-gate clock
  (`PGATE2(SCP_SYS_MD1,...)` in `drivers/clk/mediatek/clk-mt6768-pg.c`), whose enable runs the MD1
  MTCMOS sequence. `0x10006000` is SPM `POWERON_CONFIG_EN`, not a gate; the `0x1` we read is bit0.
- Vendor MD1 power-on (`spm_mtcmos_ctrl_md1_pwr`) uses: `0x10006320` (ON/ON2ND/RST_B/**bit8 SRAM_PDN**),
  `0x10006394` bit0 = 1 (`MD_SRAM_ISO_CON`), `0x10006398` bit0 = 0 (`MD_EXTRA_PWR_CON`),
  status `0x10006180/0x10006184` bit0; bus protect `0x100012A0/A4` (bit7, bits3|4), `0x100012A8/AC` (bit6).
- **Mainline gap:** `mt6768-pm-domains.h` never clears bit8, never writes `0x394`, and never writes
  `0x398` (no `MTK_SCPD_EXT_BUCK_ISO` cap). Live `0x10006320 = 0x10D` ⇒ **SRAM_PDN bit8 still set**;
  vendor post-on value is `0x00D`. Check with `devmem 0x10006320/0x10006394/0x10006398` before
  trusting this as the HS2 cause (causality unproven).
- Other facts: `vmd1` = MT6358 `BUCK_VMODEM_ELR0 0x15A6[6:0]` (off = no-op); `spm_ap_mdsrc_req()`
  is SIP `0xC2000223` + register `0x10006430` bit0/ack bit4; boot stats `0x1020E300/04` are read-only
  on the AP side (MD writes `"S1"/"S2"/"S3"/"TC n"`); LK loads `md1img` and powers MD1 **off** before
  jumping to Linux, so Linux must do a full power-on.


---

## 32. Oct 25 2026 (late) — ROOT-CAUSE DIRECTION FOUND: the modem is in an exception loop

### 32.1 The modem is NOT idle — it crashed into the Nucleus exception dumper
The PC-monitor records (part 31.2) were resolved against the **modem's own symbol table** (see 32.2):

```
0x90da8740  INT_EnterExceptionForOtherCore      (0x90da8740-0x90da8758)
0x90da8758  INT_GetExlog                        (0x90da8758-0x90da8770)
0x90db1bc0  INT_EnableUsipScq16MemoryDump
0x90db20a8  INT_GetUsipScq16MCUViewMappingInfo  (0x90db20a8-0x90db2130)
0x90da5dd4  ex_output_assert
0x90da75a4  ex_cadefa_assert
0x90b935a6  ESAL_AR_STK_Unsolicited_Set         (0x90b93474-0x90b936cc)
```

The live loop is:
`INT_GetExlog` -> `ESAL_AR_STK_Unsolicited_Set` -> `INT_EnterExceptionForOtherCore` -> `INT_GetExlog`
i.e. the MCU is in **`ex_cadefa_*` (Nucleus exception framework)** collecting a
**"other core" (USIP/DSP) exception dump** and never finishes -> the modem never reaches the
13th RPC (`0x400e` DTSI query) and never sends HS2.

`mdccci_dbg` (smem 0x78000000) holds a partial exception header written by the MD:
```
+0x000 43 43 43 49   "CCCI"
+0x004 45 44 42 47   "EDBG"
+0x008 07 00 00 70   0x70000007
+0x020 2e 07 00 00   0x0000072e  (likely line/frame id)
+0x02c 06 00 05 40   0x40050006  (last CCCI op 0x4005 / EINT attr type 6)
```
Everything else in that region is zero, and the `mdss_dbg` region (smem 0x78000800, where
MT6739-class firmware keeps `EX_OVERVIEW`) is all zero. So the MD died before completing the record.

### 32.2 The modem DbgInfo can be decompressed -> 95,602 symbols (HUGE)
`md1img.img` section `md1_dbginfo` (file 0x1e4c080, payload at 0x1e4c280) is **raw LZMA**
(props 0x5d, dict 16 MB, uncompressed size 3,693,978). Decompress:
```python
import lzma
d=open('flash_images/md1img.img','rb').read()
dec=lzma.LZMADecompressor(format=lzma.FORMAT_ALONE)
out=dec.decompress(d[0x1e4c280:0x1f237b0])   # -> 3,693,978 bytes, eof True
```
Header: `CATICTNR` + version + `LR12A.R3.MP TK_MD_BASIC` + `MT6768_S00` +
`MOLY.LR12A.R3.MP.V114.9.P1` + build date `2020/06/11 10:47`.

Symbol table format inside: `<u32 start><u32 end><char name[]\0>` (contiguous ranges).
Parsed and saved: **95602 symbols** -> `/tmp/opencode/md_syms.txt` (regenerate with the script
in 32.6). This resolves ANY modem PC to `function+offset`.

### 32.3 The modem CODE is encrypted (hardware secure-boot image)
Evidence:
- 300 random function start addresses from the symbol table: only **1/300 (0.3%)** has a sane
  Thumb prologue; a normal ARM image would be 80-95%.
- 64 KB entropy across `md1rom`: avg 6.16, 287/469 blocks >= 6.8 (near-random).
- The DRAM copy at 0xae000000 is **byte-identical** to the file (payload at file 0x200), so LK does
  not decompress or transform it; the decryption happens in the MD's fetch path (secure boot).
- Data (strings, DbgInfo, MDDB, layout) is plaintext; only the code is encrypted.
=> Static disassembly of the modem code is impossible without the eFuse/secure-world key.

### 32.4 Matching modem SOURCE code leak found and saved locally
Repo: `https://github.com/junkyard-2327/TK_MD_BASIC_MOLY.LR12A.R3.MP.V110.6`
(same branch `MOLY.LR12A.R3.MP`, MT6768/MT6765 trees, commit `04ebd402fe9472e0c2e3da5a296c11819307b929`).
Saved to: `vendor/TK_MD_BASIC_MOLY.LR12A.R3.MP/` (278 MB, sparse checkout:
`mcu/common/driver/devdrv`, `mcu/pcore/custom`, `mcu/common/service`).

What IS intact (useful): SIM/USIM (`icc_switchControl_al.c`, `icc_switchControl_mtk_0.c`,
`icc_sim_common_mtk.c`), EINT (`eint_setting_init.c`), NVRAM (`custom_nvram_int_config.c`),
drivers (`devdrv_common.c`), DHL service.
What is **stripped** ("/* under construction !*/"): CCCI/HIF core, RPC client, KAL/assert
implementation, boot flow, `lte_ccci_hal_init()`, exception writer.
So the leak does NOT contain the HS1/HS2 or exception handshake code.

### 32.5 What the firmware confirms (from the leak)
`EINT_Setting_Init()` (called at the end of `Drv_Init_Phase2()`) is exactly the 12 RPCs we see, has a
default for every getter and **cannot block**. `EINT_Setting_SW_Init()` + `kal_create_spinlock("eint")`
are the last steps. The 5 "missing" queries (0/1/2/3/4) belong to `L1sim_Reset_All()` in the SIM task
and only run when VSIM is powered. So the EINT phase completed and the crash is **after** it.
`custom_query_md_product_model_id()` in `custom_nvram_int_config.c` is the source of the 0x400e DTSI
query; it is called from `custom_nvram_config()` at NVRAM-task init. The modem dies before that.

### 32.6 Reproduce the symbol table
```python
import lzma
d=open('flash_images/md1img.img','rb').read()
out=lzma.LZMADecompressor(format=lzma.FORMAT_ALONE).decompress(d[0x1e4c280:0x1f237b0])
# symbols: scan for <u32 a><u32 b><name\0> with 0x90000000<=a<b and printable name
```

### 32.7 Also fixed this round
- **MD1 SRAM power-on gap** (mainline `sram_pdn_bits=0`): `md_cd_power_on()` now writes
  SPM `0x10006000=0x0B160001` (project code), clears `MD1_PWR_CON[8]`,
  sets `MD_SRAM_ISO_CON[0]`, clears `MD_EXTRA_PWR_CON[0]`.
  Verified: `md1 sram on: cfg=00000001 pwr=0000000d iso=00000001 extra=00000000`
  (was `pwr=0x10d iso=0 extra=1`). cfg upper bits are read-only.
- **Runtime feature 10 (`MISC_INFO_CCCI`) now 0** (no seq check / no MD status polling), matching the
  known-good 6293 bring-up.
- **CCB(15)/DHL_RAW(16) marked NOT_SUPPORT** (stock `ccci_mdinit` fills the CCB control block first;
  we don't). None of these changed the crash, so they are not the root cause.
- `md_eint_force_err` module param added (answers every EINT query with -11 like the working MTK6739
  port) - also no change, so the SIM1 success reply is NOT the trigger.
- Device passwords: `root` and `alarm` = `<redacted>`; sudo NOPASSWD already set.

### 32.8 Immediate next steps to get the exception reason
1. The MD dies inside the "other core" (USIP/DSP) dump and never raises `D2H_EXCEPTION_INIT`.
   To see the assert we need the MD to finish the dump: the CCCI exception path uses the MD-side
   `ccci_exception_handshake/ccci_except_ack` (symbols exist) - the AP must run the
   `HIF_EX_*` handshake when the MD signals; we never get the signal because it dies first.
2. Therefore find the **first faulting PC**: the trace shows `ESAL_AR_STK_Unsolicited_Set+0x132`
   (a Nucleus stack function) right before the exception entry -> suspect **stack fault/overflow**
   in the init task. `ESAL_AR_STK_*` symbols and the exception record are the place to dig.
3. Alternative: force the MD to dump to the AP by making `ccci_excep_dbg_logging_InHS2` run - this
   symbol exists in the firmware and is specifically for exception logging during HS2.
4. Re-check MD1 SRAM/DSP SRAM power: only the MCU SRAM bit was fixed; the USIP/DSP may need its own
   SRAM/clock bit (the dump failure is in USIP code).

### 32.9 VERIFIED: the DSP sub-images are NOT missing — no LK changes needed
Concern raised: LK loads modem sub-images (`md1dsp`, `md1arm7`, `md1ramdisk`, `l1core`) and we
replaced the `boot` partition with U-Boot.  Checked all three places:

1. **Stock boot.img** (`ke7_dump/boot.img`, 32 MB): ANDROID! v2 header, kernel (0x800, with the DTB
   appended at 0x8b209e), gzip ramdisk (0x8cf800), `second_size=0`, dtb_size=2.  Ramdisk content is
   the standard Android ramdisk (`init`, `fstab.mt6768`, avb keys...).  **No modem images.**
2. **LK** (`flash_images/lk_patched.img`) contains the strings `md1img, md1dsp, md1arm7, md3img,
   scp1, scp2, spmfw` — but only as a generic partition-name table.  The device's GPT has **only
   `md1img`** (no `md1dsp` partition).
3. **md1img partition** (57,860,848 bytes) contains the sub-image as a container section:
   `md1dsp` header @0x16a3850 (magic 0x58881688, size 0x69811c, name "md1dsp"), payload @0x16a3a50
   starting with `MMM\x01` + `FILE_INFO` (size 0x698000, "DSP!" at +0x114).  `md1arm7` /
   `md1ramdisk` do **not** exist for MT6768.

**Runtime proof**: a kernel scan of the MD reserved area (0xae000000, 0x7e00000) for `FILE_INFO`:
```
DSP FILE_INFO @md_resv+0x408     size=0x1546480   <- md1rom payload (at 0xae000400)
DSP FILE_INFO @md_resv+0x7000008 size=0x698000    <- md1dsp payload (at 0xb5000008)
```
So LK **did** load the DSP image at **0xB5000000**, size 0x698000, and the modem image at 0xae000000.
Nothing was lost by flashing `boot`; a custom LK is not needed.

`md1img` was never reflashed and is intact.  The `boot` partition only ever held kernel+ramdisk+DTB.

### 32.10 So the crash is NOT a missing image
The MCU still ends up in `INT_EnterExceptionForOtherCore` / `INT_GetExlog` /
`INT_GetUsipScq16MCUViewMappingInfo` (the USIP/DSP exception-dump path) and never signals the AP.
Relevant firmware symbols found in DbgInfo:
```
90d6960c MD_TOPSM_IsUsipPowerOn      90d696d8 MD_TOPSM_USIP_SW_Control
90da26f4 ex_wait_init_usip           90da3038 ex_init_usip
90da389c usip_deactive_done_check    90da3bc4 usip_activate / 90da3c80 usip_deactivate
90da497c dsp_FillBootPattern         90da49b4 dsp_FillBootProgress
9093b270 ex_init_dsp_exrecord        90da35d0 query_usip_pc
```
i.e. the MCU waits for the USIP to reach a boot/active state and dumps it when it doesn't.
`0x200D0000` (TOPSM / PSMCUSYS SRAM) reads back 0x00000001 for every word via /dev/mem (dummy
window, not usable from userspace).  The AP driver only ioremaps this block and never uses it
(same in the vendor tree).

Next: find why the USIP never reaches the expected state (power/clock/MPU), or make the AP run the
CCCI exception handshake so the MD can finish the dump and report the assert.

### 32.11 New tooling: `mempeek` module (read modem DRAM without rebooting)
`cellular-port/mempeek/mempeek.c` (built like the other modules, `insmod` any time — it is NOT
`ccci`, so the "never rmmod+modprobe ccci" hazard does not apply):
```
make -C linux M=$PWD/cellular-port/mempeek ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- modules
scp mempeek.ko root@<ip>:/tmp/
insmod /tmp/mempeek.ko addr=0xAE000000 len=0x7E00000 mode=<0|1|2|3> [value=0x...] [key=...]
```
* mode 0 = hex dump (16 B/line), 1 = ASCII runs, 2 = scan for a u32, 3 = CRC32, 4 = filtered strings.
* `rmmod mempeek` then `insmod` again to change parameters (safe).
* Uses `__va()` because md_resv is normal RAM in the linear map; `ioremap()` refuses it and
  `/dev/mem` returns `EPERM` for it.
This replaces a 4-minute reboot cycle with a ~1 s test.

### 32.12 The DSP image is intact — negative result, important
`crc32_le` over `0xB5000000 + 0x698000` (the md1dsp payload in DRAM) =
**0x7e736dd0**, identical to `zlib.crc32(md1img.img[0x16a3a50 : +0x698000])`.
So LK's copy is byte-perfect **and the MCU never writes a single byte into the DSP image region**
(any runtime write would change the CRC).  Anything found inside `0xB5000000..0xB5698000` is
**image data**, not runtime state.

**Ruled out (do not repeat):** the words `0x62935566` / `0x67aaaa80` / `0x070a21a8` at
`0xB509DAF0`/`0xB509E000`/`0xB509E028` are **constants in the image file** (verified at file offsets
0x1741a50 / 0x1741a78 / 0x1741540), *not* a USIP handshake.  An earlier "4 of 6 cores never
acked" interpretation was wrong.

### 32.13 Modem-side register blocks are only reachable through ATF (SMC)
`mdreg_write32(reg_id, value)` in `mt6768/md_sys1_platform.c` is an
`arm_smccc_smc(MTK_SIP_KERNEL_CCCI_GET_INFO, reg_id, value, ...)` call, i.e. **ATF** performs the
access.  `enum MD_REG_ID` exposes only 12 fixed registers:
`AP_MDSRC_REQ, PC_MONITOR, PLL_REG, BUS, MDMCU_BUSMON, MDINFRA_BUSMON, ECT, TOPSM_REG, MD_RGU_REG,
OST_STATUS, CSC_REG, ELM_REG` — there is **no offset parameter**, so we cannot read arbitrary
TOPSM/USIP registers through it.
Direct access results (all useless):
* `/dev/mem` mmap of any `0x2000_0000`-space MD register returns `0x00000001` for every word.
* `ioremap()` of `0x0D0D0000` (would-be TOPSM alias) reads all-zero; `0x0D1D0000` reads `deaddead`.
* `ioremap(0x0E630400)` (USIP ungate alias) reads DRAM garbage.
* The only AP-visible MD register block that works is the PC monitor at **0x0D0D9000**.
The vendor mt6768 driver has **no USIP/TOPSM access at all** (only mt6853 has `ap_md_reg_dump.c`
with a USIP block at `0x0D104400`), so the AP is not expected to touch DSP power on this SoC.

### 32.14 Firmware constants recovered from the leak (sst headers)
From `mcu/common/service/sst/include/`:
```
md32_boot.h:      MD32_MAGIC_KEY      0x62930000
                  MD32_USIP0_TH0_BTSLV 0x400   MD32_USIP0_TH1_BTSLV 0x404
                  MD32_USIP1_TH0_BTSLV 0x408   MD32_USIP1_TH1_BTSLV 0x40C
                  MD32_PM 0x00380000  MD32_DM 0x003E0000  MD32_PERI_CTRL 0x351000
us_excep_hdlr.h:  USIP_SCQ16_EX_INIT_PATTERN 0x62935566
                  USIP_SCQ16_EX_SYNC_TIMEOUT  0x200000
                  USIP0_APB_BASE 0xA0084000, USIP1_APB_BASE 0xA0085000
us_excep_hdlr_format.h: USIP_SCQ16_EXCEPTION_ASSERTION = 0x45584300
                  USIP_SCQ_EXCEPTION_RECORD_T = { u32 core_num; {u32 type, u32 stat,
                    union { {u32 line, p1, p2, p3, char file[64]} assert;      (80 B)
                            {u32 status, pc, lr, addr, code1, code2, u8 section} fatal; } } [6]; }
usip_power_test.h (MT6763 addrs): USIP_UNGATE_ADDR_U0..U3 = 0xA1630400..0x40C (0=run, 1=gated)
dsp_control.h:    USIP0_MON_PC = BASE_MADDR_MDMCU_USIP_INT_DBG + 0x20010
```
Scans for `0x45584300` (assertion record) and `0x6293beef` (core-end marker) over the **whole**
`md_resv` (126 MB, 33,030,144 words) both returned **not found** → no DSP exception record exists in
AP-visible memory.

### 32.15 Other confirmations
* `MD_GENERATION = 6293` matches the vendor tree (`mt6768/ccci_config.h`), so the feature
  decisions (`MD_USIP_SHARE_MEMORY` = NOT_SUPPORT, `SMEM_USER_RAW_USIP` size 0) are vendor-correct.
* `md1img` section table (23 sections): `md1rom` @0, `md1dsp` @0x16a3850, `md1_drdi` @0x1547be0,
  `md1_dbginfodsp` @0x1d4c710, `md1_dbginfo` @0x1e4c080, `md1_mddb` @0x1fa3250,
  `md1_mdmlayout` @0x2f89890, `md1_file_map` @0x372de10.  **No `md1arm7`, no `md1ramdisk`.**
  `md1_file_map` is only a `section=debughfile.bin` name table; `md1_mdmlayout` is a **text** OTA
  trace description (`###### VER 2.0 #####`, `OTA_TRACE_ID_OFFSET...`) — neither carries load
  addresses.
* `L1_RGU_BASE (0x26010000)` is marked "AP use" in `modem_reg_base.h` but is **unused in both our
  port and the vendor tree** → not the missing step.

### 32.16 PC trace of the stuck MCU (512 samples, resolved with 95,602 symbols)
Chronological head of the trace (oldest first, `pcmon` words 0..~60):
```
Print_Filter_Setting+0x12
DSP_IsFirstMpuSettingDone+0x72
INT_GetUsipScq16MCUViewMappingInfo
Dsp_Logging_Init+0x60 / +0x56  (repeated 4x, args 0x00010000/0x00020000/0x00030000)
Dsp_Logging_Init+0x72
Print_Filter_Setting+0xc
INT_GetExlog+0xa / +0x14
ESAL_AR_STK_Unsolicited_Set+0x122/0x12c/0x132
INT_EnterExceptionForOtherCore / INT_EnterExceptionForOtherCore+0x10
INT_GetExlog+0x8 / +0xa / +0x14  ... (loops)
```
So the *last normal work* was **DSP logging initialisation** (`Dsp_Logging_Init` per core,
`DSP_IsFirstMpuSettingDone`, `INT_GetUsipScq16MCUViewMappingInfo`), and the MCU then entered the
"other core" (USIP) exception path and stays there.  `ESAL_AR_STK_Unsolicited_Set` is the Nucleus
API that installs an **unsolicited stack + entry function** (`esal_extr.h`: `(start, end,
entry_fn)`), i.e. the dump runs on its own stack — it is not itself the fault.

---

## 33. PIVOT (2026-10-25): freeze mainline state, go stock Android, mine it, return later

### 33.1 Decision
The DSP/USIP does not boot under the mainline kernel and the MCU spins forever in
`INT_EnterExceptionForOtherCore`.  All AP-side configuration now matches the vendor (see §32), the
images are byte-perfect and fully loaded, and the firmware is encrypted, so there is no remaining
AP-side lever to pull blind.  Plan agreed with the user:

1. **Back up the current mainline state** so we can return to it exactly.
2. **Flash a genuine stock Tecno KE7 ROM** (Android 10, build `KE7-H693GHIJKM-Q-GL-200617V060`),
   keeping the bootloader **unlocked (orange state)**.
3. **Root it**, then harvest ground truth from a *working* Android: kernel logs, `dmesg`, vendor
   driver behaviour, power/clock sequencing, MD/DSP bring-up, NVRAM/RF calibration state.
4. **Return to mainline** with that knowledge.

### 33.2 What was backed up (authoritative snapshot)
`backup/arch_state_20261025/` — dumped live over SSH from the running Arch system:
* `gpt_primary.bin`, `gpt_backup.bin` (34 sectors each, 17408 B).
* Raw dumps `mmcblk0pNN.bin` for **p1..p36, p40, p41, p42** (exact `blockdev --getsize64` sizes,
  verified after transfer).
* `rootfs.tar.zst` (p43 `/`, `--one-file-system`, excludes proc/sys/dev/tmp/run/mnt/media/boot).
* `esp.tar.zst` (p40 `/boot`).
* Skipped on purpose: **p37 `super`, p38 `cache`, p39 `tranfs` — verified 100 % zero** (read 64 MB,
  zero non-NUL bytes; Android system is gone, which is why a full stock ROM is required).

Verified identities:
| partition | md5 | meaning |
|---|---|---|
| p30 `boot` | `fda47596d4db7ddc1e9273d187f77682` | == `boot-uboot-mdclk.img` (our U-Boot + MD clock fix) |
| p18 `md1img` | `f399bc7754f1c736cef3db81748a5efb` | first 57,860,848 B == `flash_images/md1img.img` (`c6e068af…`) |
| p27 `lk` | `436c585cb60f7d2242c52d7a19eb9f10` | current on-device LK — **matches neither** `backup/lk.bin`
(`b2d1236c…`) nor `flash_images/lk_patched.img` (`d4ad3eb9…`) |
| p28 `lk2` | `436c585cb60f7d2242c52d7a19eb9f10` | identical to `lk` |
| p16 `seccfg` | `51333e3185cb22375767728444a95a90` | current (unlocked/orange state); first 512 B differ from
`flash_images/seccfg_unlocked.bin` |

**Consequence:** the old `backup/` (Oct 22) was taken *after* the data partitions had already been
wiped and its `lk`/`boot` no longer match the device, so it is **not** a restore source.  Only
`arch_state_20261025/` is authoritative.

### 33.3 Stock ROM source
* Hovatek thread 35594 ("Tecno Spark 6 KE7 Stock ROM") lists the factory files, but every MEGA link
  is **truncated in the HTML** (`…IXqCMgMz6r...VEgk7qr-TM`), so it is unusable for guests.
* Working mirror: `mobileguru4.com` → MediaFire
  `0t6wuhgnqt7jzwc` → `Tecno Spark 6 (KE7-H693GHIJKM-Q-GL-200617V060)_MobileGuru4.com.zip`,
  **2,636,943,405 bytes**, downloaded to `firmware/KE7_stock_200617V060.zip` (resumable direct link
  from the MediaFire page, `accept-ranges: bytes`).
* MediaFire hides the page behind Cloudflare for `curl`; a real browser session is needed to obtain
  the signed `download####.mediafire.com/...` URL.

### 33.4 Flash strategy (once the zip is extracted)
* Use **`mtkclient` / Kamakiri** (BROM exploit) — bypasses the vendor DA, which is the only way to
  write `lk`/`preloader`/`boot` on a locked-down unit.
* **Do NOT flash `seccfg`** from the stock package: that is what re-locks the bootloader.  Keep the
  current unlocked `seccfg` (or re-flash `seccfg_unlocked.bin`) to preserve the orange state.
* Expect the stock package to be a SP Flash Tool layout (`MT6768_Android_scatter.txt` + per-partition
  images).  Map its partitions onto our GPT (`boot_para, proinfo, para, expdb, frp, metadata,
  md_udc, nvcfg, nvdata, persist, protect1/2, tkv, recovery, misc, seccfg, sec1, md1img, spmfw,
  scp1/2, sspm_1/2, gz1/2, nvram, lk, lk2, logo, boot, dtbo, tee1/2, vbmeta*, super, cache,
  tranfs, esp, otp, flashinfo, rootfs`).
* After stock boots: unlock is already present, so patch `boot` with Magisk (or flash a rooted
  `boot`) and disable vbmeta verification to obtain root.

### 33.5 Backup status — COMPLETE
`backup/arch_state_20261025/` = **3.6 GB**, verified:
| Artefact | Size | Check |
|---|---|---|
| `mmcblk0p{1..36,40,41,42}.bin` | 39 files, ~1.35 GB | sizes = `blockdev --getsize64` |
| `mmcblk0boot0.bin`, `mmcblk0boot1.bin` | 4 MiB each | md5 `a7e48ea81d65d918520ad83576814224` |
| `gpt_primary.bin`, `gpt_backup.bin` | 17408 B each | — |
| `rootfs.tar.zst` | 2.4 GiB compressed (6.28 GiB raw) | `zstd -t` OK, 124,424 entries |
| `esp.tar.zst` | 50 MiB (99.7 MiB raw) | `zstd -t` OK, contains `EFI/BOOT/BOOTAA64.EFI`, `Image`, DTBs |

Only skipped entries were live sockets (gpg-agent, ibus dbus) and one journal file that changed
during the read — both harmless.  Restore procedure: `restore_arch.sh`.

### 33.6 Stock ROM download
`firmware/KE7_stock_200617V060.zip` — 2,636,943,405 B, resumable curl from the signed MediaFire
URL.  Peaked at ~5.3 MB/s once the rootfs tar stopped sharing the link.

### 33.7 Stock package audit (2026-10-25)
`firmware/KE7_stock_200617V060.zip` — md5 `fae0c8a27f6a40f21ab404dd31994b6b`, `unzip -t` clean.
Real **SP Flash Tool package**, 42 files, 4,616,418,069 B uncompressed, extracted to
`firmware/stock/Tecno Spark 6 (KE7-H693GHIJKM-Q-GL-200617V060)_MobileGuru4.com/`.
Contents: `MT6768_Android_scatter.txt`, `PGPT`, `preloader_ke7_h693.bin`, `lk.img`, `boot.img`,
`recovery.img`, `dtbo.img`, `md1img.img`, `super.img`, `cache.img`, `tranfs.img`, `userdata.img`,
`tee.img`, `tkv.img`, `scp.img`, `spmfw.img`, `sspm.img`, `vbmeta*.img`, `logo.bin`, APDB, MDDB.

**Build identity confirmed against our device dumps (md5):**
| image | result |
|---|---|
| `md1img.img` | **MATCH** `c6e068af…` == our p18 prefix → same modem firmware |
| `dtbo.img`, `tee.img`, `spmfw.img`, `scp.img`, `sspm.img` | **MATCH** our p31/p32/p19/p20/p22 |
| `lk.img` `db6bb650…` | differs (device LK is `436c585c…`, backup was `b2d1236c…`, `lk_patched` `d4ad3eb9…`) |
| `logo.bin` | differs (we had replaced it with the Arch logo) |
| `tkv.img` | differs → **device-unique TEE key vault, do not flash** |

**`PGPT` is only a template, not a flashable table**: `userdata` has `first=0,last=0` (512 B) and the
header has `last_usable=0`. Flashing it would create a 512-byte `/data` and break Android.
→ We keep the on-device GPT and only **rename p43 `rootfs` → `userdata`**
(`parted -s /dev/mmcblk0 name 43 userdata`, verified in the raw GPT and by `lsblk`). All other
partitions already exist with the stock sizes (`otp`/`flashinfo` differ by 512 B only).

**Stock fstab (from the ramdisk of `boot.img`, `fstab.mt6768`):**
* `/data` = `/dev/block/platform/bootdevice/by-name/userdata`, **f2fs**,
  `wait,check,formattable,quota,resize,reservedsize=128m,...` → Android will format it.
* `/metadata` = `by-name/md_udc` (not the `metadata` partition).
* Also mounts `md1dsp` by name — **no such partition exists in the scatter** (the DSP image is the
  `md1dsp` section inside `md1img`, as established in §32.9).  Vestigial fstab entry.
* `system`/`vendor`/`product` are logical, from `super` with AVB.

**Sparse images**: `super.img`, `cache.img`, `tranfs.img`, `userdata.img` are Android sparse
(`0xED26FF3A`). `mtkclient` writes raw bytes, so they were expanded with `simg2raw.py`:
* `firmware/stock/super.raw` = 5,242,880,000 B (exactly the `super` partition), md5 `9735be00…`,
  LP geometry magic `0x616c6f67` verified at offset 0x1000.
* `firmware/stock/cache.raw`, `tranfs.raw` = 314,572,800 B each.

### 33.8 Flash list (final)
Flash: `super.raw`, `boot.img`, `recovery.img`, `md1img.img`, `dtbo.img`, `logo.bin`,
`tee.img`→tee1/tee2, `scp.img`→scp1/2, `sspm.img`→sspm_1/2, `spmfw.img`,
`vbmeta*.img`, `cache.raw`, `tranfs.raw`, 4 MiB zeros→`userdata`, 4 MiB zeros→`misc`.

**Never flash:** `preloader` (device `AND_SECRO` hash), `seccfg` (orange state), `lk`/`lk2`
(current LK proven to boot unlocked; the ROM LK is a different build), `tkv` (device-unique),
`nvram`, `nvdata`, `persist`, `protect1/2`, `otp`, `flashinfo`, `md_udc`, `boot_para`, `proinfo`,
`para`, `expdb`, `frp`, `metadata`, `nvcfg`, `gz1`, `gz2`, `sec1`.

Script: `flash_stock.sh` (pre-flight GPT check, all writes, zero userdata/misc, reset).

### 33.9 Flash executed — SUCCESS (2026-10-25 ~15:09)
Entered BootROM as `0e8d:0003` (Volume Up+Down while plugging; Volume Down alone gave `0e8d:2000`
preloader). `mtk.py printgpt` worked through Kamakiri and confirmed `userdata` at
`0x1a6000000` length `0xce5cf8000`.

Two `multi` sessions were used (one BROM connection each, no re-plug needed):
1. `super.raw` → sector 1310720, count 10240000 (= 5,242,880,000 B).
2. the remaining 19 writes + `reset`.

| image | sector | sectors | bytes |
|---|---|---|---|
| super.raw | 1310720 | 10240000 | 5,242,880,000 |
| boot.img | 1157120 | 65536 | 33,554,432 |
| recovery.img | 545040 | 65536 | 33,554,432 |
| md1img.img | 643072 | 262144 | 134,217,728 (file 57,860,848) |
| dtbo.img | 1222656 | 16384 | 8,388,608 |
| logo.img | 1140736 | 16384 | 8,388,608 |
| tee.img → tee1/tee2 | 1239040 / 1249280 | 10240 | 5,242,880 each |
| scp.img → scp1/scp2 | 907264 / 919552 | 12288 | 6,291,456 each |
| sspm.img → sspm_1/2 | 931840 / 933888 | 2048 | 1,048,576 each |
| spmfw.img | 905216 | 2048 | 1,048,576 |
| vbmeta.img | 1259520 | 16384 | 8,388,608 |
| vbmeta_system.img | 1275904 | 16384 | 8,388,608 |
| vbmeta_vendor.img | 1292288 | 18432 | 9,437,184 |
| cache.raw | 11550720 | 614400 | 314,572,800 |
| tranfs.raw | 12165120 | 614400 | 314,572,800 |
| zero4m → userdata | 13828096 | (part) | **4,194,304** |
| zero4m → misc | 610576 | (part) | **4,194,304** |

Note: the "sector count" in mtkclient's message is the **partition** size (protocol header); the
actual transfer is the file size — confirmed by the progress counters (`0x400000/0x400000` for
userdata/misc, `0x12C00000` for cache/tranfs).

**Harness gotcha (fixed):** `mtk.py multi` splits on `;` and then `rcmd.split(" ")`, so a `"; "`
separator produces an empty token and aborts with `invalid choice: ''`. Always join multi commands
with a bare `;` **and no space after it**, and keep image paths free of spaces (the stock folder name
contains spaces, hence `firmware/stock/bin/` symlinks).

Reset sent → phone powered off. Logs: `/tmp/opencode/flash.log`, `/tmp/opencode/flash2.log`.
Not flashed (unchanged): preloader boot0/boot1, seccfg (unlock kept), lk/lk2, tkv, nvram, nvdata,
persist, protect1/2, otp, flashinfo, md_udc, boot_para, proinfo, para, expdb, frp, metadata, nvcfg,
gz1, gz2, sec1.

---

## 34. TWRP touch — root cause and fix (2026-10-25)

### 34.1 Why the existing TWRP has no touch
* `flash_images/twrp.img` and the **stock** `recovery.img`/`boot.img` share the **identical kernel**
  (md5 `e0a2d7a7e30273c70156bd6374bbaf7f`, 9,655,894 B) — so it is not a kernel-version mismatch.
* The kernel blob is **gzip + appended DTB** (`d00dfeed`), which is why a naive `strings` on the
  image finds nothing. After inflating (`zlib.decompressobj(16+MAX_WBITS)`) it contains:
  `novatek,NVT-ts-spi`, `focaltech,fts`, `novatek_ts_fw`, `focaltech_ts_fw`, `nt36xxx`, `fts_ts`,
  150 `tpd*` strings → **both touch drivers are built into the kernel** (no `.ko` needed).
* The panel is a **Novatek NT36672A on SPI**: the mainline DTS
  (`mt6768-tecno-ke7.dts:444`) declares `compatible = "novatek,nt36672a-ts"`, `reg = <0>`,
  `spi-max-frequency = <8000000>` and `firmware-name = "novatek_ts_fw.bin"`.  The stock DTBO
  (parsed from `dtbo.img`, big-endian header, 1 entry, 66,943 B) has the matching
  `tran_touch: touch@0` node plus an unused `cap_touch@14` (`mediatek,cap_touch`).
* The driver needs **`novatek_ts_fw.bin`**.  It lives on the **vendor** partition at
  `/firmware/novatek_ts_fw.bin` (118,784 B) — extracted from `super.raw` (LP metadata header at
  **0x3000**, 128-byte header, table descriptors at offset **80**; `vendor` = 1 extent,
  973,352 sectors = 498,356,224 B, ext4 volume label `vendor`).
  `/vendor/lib/modules` holds only 9 modules (bt/fmradio/fpsgo/gps/met/udc/wlan/wmt) — **no touch
  module**, confirming the driver is built-in.
* **TWRP's ramdisk has no firmware directory at all** (`find . -type d -name firmware` → none), while
  its own `ueventd.rc` declares
  `firmware_directories /etc/firmware/ /odm/firmware/ /vendor/firmware/ /firmware/image/`.
  So `request_firmware("novatek_ts_fw.bin")` fails and the panel never registers an input device.

### 34.2 Fix
`inject_twrp_fw.py` appends `cpio` `newc` entries **immediately before the TRAILER**, so every
original entry stays byte-identical (avoids the mode/ownership drift of extract→repack), then
rebuilds the Android boot image with the same kernel+DTB, page-aligned (2048), recomputed SHA1 `id`.

**Firmware choice matters:** the 2020 ROM's `vendor` carries `novatek_ts_fw.bin` md5
`a6e03288da123e500ad0f132e84018e2`, but the **device's original** vendor dump
(`ke7_dump/vendor/firmware/`) and the **mainline** rootfs (`/usr/lib/firmware/`, where touch
actually worked) both carry md5 **`f3b27aef49ac43ec70407a8d8586cf97`**.  The device shipped with a
newer build than the 2020 ROM, so the injected file is the **known-good `f3b27aef…`** one.

Injected into `flash_images/twrp_touch.img` (26,007,552 B, md5 `8d1a41735ebd28955ba77779fb80da87`):
```
lib/                                   (dir 0755)
lib/firmware/novatek_ts_fw.bin         (118784, kernel direct path /lib/firmware)
system/etc/firmware/                   (dir 0755)
system/etc/firmware/novatek_ts_fw.bin  (118784, ueventd path /etc/firmware)
```
Verified: ramdisk at 0x936000, gzip magic OK, 685 entries (680 original + 5), TRAILER last.

**Flash command (BROM):** `mtk.py w recovery flash_images/twrp_touch.img`
Then in TWRP verify: `dmesg | grep -i -E "nt36|novatek|tpd"` and
`cat /proc/bus/input/devices` (expect a `NVT-ts` / `NVTCapacitiveTouchScreen` input device).
If touch is still dead, the next checks are `/proc/device-tree` for the `touch@0` node and whether
the driver logged a firmware timeout.

**Note:** the current TWRP is a port from an **MT6785** tree (`ueventd.mt6785.rc`, image name
`CY-KE7-H693-G`), so other mismatches are possible; the touch fix is the first and most likely one.
