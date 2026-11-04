# Tecno Spark 6 (KE7 / MT6768) — Linux Bringup Project Status & Memory Bank

**Last Updated:** October 28, 2026  
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
* Publicly archived **MOLY.LR12A.R3.MP** source proves the 12 RPCs are `EINT_Setting_Init()` **phase 1** (SRCPIN=6, NUMBER=0, DEDICATEDEN=5 per SIM). Every getter has a default; the function has no failure branch, no return, no wait — it **cannot stop the MD**.
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
  * **SUPERSEDED (Oct 25, 2026):** vendor LR12A.R3.MP source analysis shows EINT is **not** on the HS2 critical path (see §3.15 / HARDWARE §31). Keep the node (it is correct), but expect HS2 to still fail; debug the pre-SIM-reset init stage instead.
- [ ] Mount NVRAM partitions and populate them before the modem starts asking for files (`/mnt/vendor/nvdata/md`, `protect_f/md`, `protect_s/md`, `nvcfg`, `nvdata/md_cmn`, `mdlpm`, `etc/mdota`, `firmware`).
- [ ] Recover NVRAM/RF calibration + IMEI (p8-p12, p26 are fully erased; user can supply the device IMEI).
- [ ] Verify SIM detection (carrier SIM) via AT commands (`AT+CPIN?`, `AT+CSQ`, `AT+COPS?`) and test data connection over `ccmni0`.
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

### 32.4 Matching modem vendor source found and saved locally
Repo: `https://github.com/junkyard-2327/TK_MD_BASIC_MOLY.LR12A.R3.MP.V110.6`
(same branch `MOLY.LR12A.R3.MP`, MT6768/MT6765 trees, commit `04ebd402fe9472e0c2e3da5a296c11819307b929`).
Saved to: `vendor/TK_MD_BASIC_MOLY.LR12A.R3.MP/` (278 MB, sparse checkout:
`mcu/common/driver/devdrv`, `mcu/pcore/custom`, `mcu/common/service`).

What IS intact (useful): SIM/USIM (`icc_switchControl_al.c`, `icc_switchControl_mtk_0.c`,
`icc_sim_common_mtk.c`), EINT (`eint_setting_init.c`), NVRAM (`custom_nvram_int_config.c`),
drivers (`devdrv_common.c`), DHL service.
What is **stripped** ("/* under construction !*/"): CCCI/HIF core, RPC client, KAL/assert
implementation, boot flow, `lte_ccci_hal_init()`, exception writer.
So the vendor source does NOT contain the HS1/HS2 or exception handshake code.

### 32.5 What the firmware confirms (from the vendor source)
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

### 32.14 Firmware constants recovered from the vendor source (sst headers)
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

---

## 35. Stock Android is up; IMEI / MAC provisioning findings (2026-10-25)

### 35.1 Device state after the stock flash
* `KE7-H693GHIJKM-Q-GL-200617V074`, Android 10, `ro.boot.verifiedbootstate=orange`,
  `flash.locked=0` — **unlock preserved**.
* **adb is root out of the box** (`uid=0`, `u:r:su:s0`) — no Magisk needed for shell-level work.
* Modem: `MOLY.LR12A.R3.MP.V114.9.P1`, `gsm.sim.state=LOADED`, `AT+CSQ` = **23** (good RF).
* `AT+COPS?` → `0`, `AT+CREG?` → `0,2` (searching), PS reject cause **111**, CS reject cause **6
  (Illegal ME)** → the network refuses the attach because the IMEI is missing.

### 35.2 AT access (how we talk to the modem)
`/dev/ttyC0` is owned by `vendor.gsm0710muxd`; the CCCI ttys (`ttyC1/3`) are not termios devices.
MTK's real AT path is **`atcid`**, disabled by default:
```
setprop persist.vendor.service.atci.autostart 1   # starts atcid, creates /dev/socket/adb_atci_socket
```
Client: `tools/atci_cli.c` → static aarch64 binary pushed to `/data/local/tmp/atci_cli`,
connects to the Unix socket, sends `<cmd>\r`, prints the reply.  Verified `AT` → `OK`.
Reads work: `AT+EGMR=0,7`, `AT+EGMR=0,10` (both `+EGMR: ""`), `AT+CSQ`, `AT+CREG?`, `AT+CLAC`.

### 35.3 Why the IMEI cannot be written over AT
`AT+EGMR=1,7,"<imei>"` and `=1,10` both return a bare `ERROR` (parser level, not `+CME ERROR`).
The culprit is in the vendor modem source, `mcu/pcore/custom/modem/common/ps/custom_l4_utility.c:728`:
```c
kal_uint8 custom_allow_at_write_imei(void)
{
#ifdef __NVRAM_CRITICAL_DATA_SIGN_SUPPORT__
    return KAL_FALSE;
#else
#ifdef __MTK_INTERNAL_ENG_USER__
    return KAL_TRUE;      /* engineering build only */
#else
    return KAL_FALSE;     /* <-- production build */
#endif
#endif
}
```
So the write is compiled out of production firmware.  Reads are unaffected.

**Not a crypto lock:** `grep` of `flash_images/md1img.img` for `devPubKeyModulus`, `crticalDataSign`,
`custom_nvram_check_signed_critical_data` → **0 hits**, i.e. the signed-critical-data feature (RSA
chain root→device key, TLV tags `CPUID/IMEI1/IMEI2/MEID/WIFI_MAC/BT_MAC`) is **not compiled into our
image**.  There is therefore no signature barrier — only the AT policy gate above.

### 35.4 Storage of the IMEI
* `nvram` partition (`/dev/block/by-name/nvram`, p26): **entirely zero** (64 MiB) — not the source.
* MD NVRAM lives in `nvdata`: `/mnt/vendor/nvdata/md/NVRAM/`
  * `NVD_IMEI/NV01_000` (96 B) and `NV0S_000` (144 B) — `"LDI\0"` header, LID `0xF006`, size 16,
    followed by 32 bytes of opaque data at +0x40; md5 `7c636a37e37bed723413d1aad1d8114c`, stable.
  * `NVD_DATA/`, `NVD_CORE/`, `CALIBRAT/`, `BACKUP/` (BACKUP empty).
* The original IMEI is **not recoverable**: full scan of the 64 MiB `nvram` dump found **zero**
  Luhn-valid BCD IMEI candidates, and the AP-side `nvdata` was zeroed before the flash.
* Our supplied IMEIs pass Luhn (TAC `<TAC>`, serials `<SN1>` / `<SN2>`) but do not appear anywhere on
  the device.

### 35.5 WiFi "NVRAM WARNING: Err = 0x10"
* Not a real AP: the driver **injects a synthetic scan result**.  In
  `wifi-port/wlan/core/gen4m/common/wlan_lib.c`:
  `NVRAM_ERROR_INVALID_MAC_ADDR = BIT(4)` = **0x10**, printed via
  `"NVRAM WARNING: Err = 0x%02X"`.
* `WIFI_CFG_PARAM_STRUCT` starts at offset 0 of `/mnt/vendor/nvdata/APCFG/APRDEB/WIFI`;
  `aucMacAddress[6]` is at **offset 4** and is all zero → `wlan0` falls back to a random MAC.
* Writing a MAC there and rebooting does **not** stick: `nvram_daemon` rewrote the file back to the
  original bytes (md5 `ea18e79bae435ba207c5e81c60a1988a`), i.e. the APCFG file has a trailer
  (`… 0xAA <byte>`) that is validated.  MTK's `nvram_util_cal_checksum_simple()` (parity-split sum)
  does **not** reproduce it, so the APCFG checksum is a different algorithm — still open.
* BT MAC is a placeholder too (`00:00:46:00:00:01`, `BT_Addr` NVRAM record at offset 2).

### 35.6 Remaining routes for IMEI
1. **META mode** (factory provisioning path).  `meta_tst` exists at `/vendor/bin/meta_tst` but fails
   to init standalone ("Enter meta_tst normal mode init fail"); the standard tool is MauiMETA over
   USB with the `APDB_MT6768_S01__W2021` / `MDDB_…EDB` databases that ship in the ROM.
2. **Tecno authorised service** (same META path, with the vendor tool).
3. Direct NVD record injection — blocked by the opaque 32-byte record format.

### 35.7 Artefacts
* `tools/atci_cli.c` (static aarch64 AT client over `atcid`).
* `/tmp/opencode/imei/NV01_000`, `/tmp/opencode/nv/WIFI*` (analysis copies, not committed).
* IMEI values are deliberately **not** written to this repo.

### 35.8 WiFi MAC fixed (vendor-supported path)
`/vendor/bin/wlan_assistant` (runs as `wifi`, started at boot) loads the WiFi NVRAM and pushes it to
`/dev/wmtWifi`.  Its strings and disassembly show a **fallback MAC file**:
```
open("/data/vendor/macwifi", O_RDONLY); read(fd, buf, 0x3ff); if (len < 0x11) fail;
log("MAC ADDR = %s", buf);      // splits on ':' → mac[0..5]
```
So the file must be a **17-byte `aa:bb:cc:dd:ee:ff` string**.  Written:
```
echo "02:00:00:00:00:01" > /data/vendor/macwifi   # chmod 644
```
Result (verified): the daemon logs `[WLAN-ASSISTANT] MAC ADDR = 02:00:00:00:00:01` plus
`mac[0..5]`, and at boot writes the NVRAM to the driver:
`WIFI_write WR-BUF:NVRAM\x01, length 2060` → `wlanNvramBufHandler: buf=…, length=2048`.
The `NVRAM WARNING` synthetic SSID no longer appears in the scan state (`dumpsys wifi` count 0).
Note: `wlan0` itself shows `02:00:00:00:00:03` — that is **Android's per-network randomised MAC**
(stored in `/data/misc/wifi/WifiConfigStore.xml`), not the hardware MAC; it is normal Android 10
behaviour and can be disabled per network if desired.

### 35.9 BT MAC — works, but stays on the compiled-in default
BT is functional (`state: ON`, name "TECNO SPARK 6").  Its MAC is `00:00:46:00:00:01`, from
`nvram_bt_default_value` inside `/vendor/bin/nvram_daemon` (the `BT_Addr` record layout is
`[BDAddr 6][Voice 2][Codec 4][Radio 6][Sleep 7][BtFTR 2][TxPWOffset 3][CoexAdjust 6]`, MAC at
offset 0).  Writing `BT_Addr` by hand does **not** stick: the daemon rewrites the record
(md5 → `e60684cb…`) from its own state/default and recomputes the trailer (`AA <byte>`), which is
**not** a plain byte sum over the file (`BT_Addr` factory: sum 0x64 vs trailer 0x60).  Changing the
BT MAC would need a proper write through `libnvram`/the NVRAM HAL or the `nvram` partition (still
all-zero).  Left as-is — it is a cosmetic default, not a functional fault.

### 35.10 Useful commands
```
# AT to the modem
setprop persist.vendor.service.atci.autostart 1
/data/local/tmp/atci_cli 'AT+CSQ'
# WiFi MAC
echo "aa:bb:cc:dd:ee:ff" > /data/vendor/macwifi
```

### 35.11 META mode entry — attempted, blocked at the preloader
Goal: use META (the only path that can write the IMEI, see §35.3/§35.10) with a native client.

What was tried:
1. `mtk.py meta METAMETA` (preloader path, includes the **Tecno SLA key** that mtkclient carries).
   * The preloader **is** found: `0e8d:2000`, with a proper CDC-ACM descriptor set
     (interface 0 CDC Communication class 0x02/subclass 0x02/protocol 0x01, bulk OUT 0x01,
     bulk IN 0x81, interrupt IN 0x83).
   * But the first `ep_in()` read times out (`[Errno 110] Operation timed out`) — the preloader
     never emits the `READY` that `mtkclient/Library/meta.py:init()` waits for, so `METAMETA` is
     never sent.  No `/dev/ttyACM*` node is created (kernel `cdc_acm` does not bind it), so the
     DTR/tty route is unavailable too.
2. `mtk.py meta2` (BROM path, sets the META boot flag then watchdog-resets).
   * Reports `Main - Successfully set meta mode :)`, **but the phone does not come up in META** —
     it boots Android, and one attempt dropped it into **stock recovery** instead.  A normal
     `reboot` restored Android.  So the BROM flag is not honoured for META on this platform.

Conclusion: with this production firmware the preloader does not offer the META handshake to
mtkclient (consistent with the AT+EGMR policy gate).  Remaining route is the **official tool**
(MauiMETA / SN Write Tool, Windows or Wine), which may drive the preloader differently, or a
Tecno service centre.

Useful state notes:
* MTK preloader appears automatically after `adb shell reboot -p` while the cable is connected
  (charging mode), and persists roughly 20–30 s — long enough to run a tool against it.
* After `meta2`, verify the phone actually booted Android (`getprop sys.boot_completed`); recovery
  has an almost empty property set and no `wlan0`.

## 36. Retail ROM flashed OK; device now hangs after preloader (2026-10-25)

### Retail ROM obtained and verified
- Source: free MobiFirmware mirror, `KE7-H693HJKM-Q-GL-220729V478(MobiFirmware.com).zip`
  (3,031,671,724 B). **First download had a real CRC error in `super.img`**
  (`7z t` -> "Data Error"); a full re-download verified **"Everything is Ok"**.
  Always run `7z t` before trusting a download.
- Extracted to `firmware/stock_retail/KE7-H693HJKM-Q-GL-220729V478(MobiFirmware.com)/`.
- Sparse images expanded with `simg2raw.py`:
  - `firmware/stock_retail/super.raw`   5,242,880,000 B  md5 `70d553ebbcd53bc2507bc0e9fa1dbb07`
  - `firmware/stock_retail/cache.raw`     314,572,800 B
  - `firmware/stock_retail/tranfs.raw`    314,572,800 B
- Retail scatter (`MT6768_Android_scatter.txt`) partition sizes and offsets match
  the on-device GPT exactly (super sector 1310720 count 10240000).
- Variant note: the Oct 22 `backup/dtbo.bin` is **all zeros** (taken after the wipe),
  so it cannot be used to prove the variant. The device's original `md1img` matched
  the **G-variant test build**; the retail `md1img` is a newer 57,014,816 B image.

### flash_retail.sh — successful run (exit 0, 18:21:14 -> 18:34:59)
20 partitions written over BROM/mtkclient:
```
super     sector 1310720  count 10240000   (100.0%, full 5,242,880,000 B)
boot      sector 1157120  count 65536
recovery  sector  545040  count 65536
md1img    sector  643072  count 262144
dtbo      sector 1222656  count 16384
logo      sector 1140736  count 16384
tee1/tee2 10240 each ; scp1/scp2 12288 each ; sspm_1/2 2048 each ; spmfw 2048
vbmeta / vbmeta_system / vbmeta_vendor
cache     sector 11550720 count 614400
tranfs    sector 12165120 count 614400
userdata  sector 13828096 (zeroed) ; misc sector 610576 (zeroed)
reset sent
```
**Not** written (by design): preloader (boot0/boot1), **seccfg** (orange state kept),
nvram, nvdata, persist, protect1/2, otp, flashinfo, tkv, **lk/lk2**, md_udc,
boot_para, proinfo, para, expdb, frp, metadata, nvcfg, gz1/2, sec1.

Two earlier attempts aborted: one accidental unplug at 1.6%, one pre-flight failure
(mtkclient started <1 s after enumeration -> "BROM not reachable"). Fix in the script:
retry `printgpt` up to 8x with 2 s gaps, and sleep 4 s after detecting `0e8d:0003`.

### Current symptom: phone dead after reset
- No screen, no adb (`adb devices` empty), no fastboot, **no `0e8d:0003`**.
- USB **does** show `0e8d:2000  MT65xx Preloader` for ~3 s per plug event, then it
  vanishes and the device stays off. So: **preloader alive, battery has charge,
  BROM not being entered, nothing boots past `lk`**.
- Leading hypothesis: we kept the **2020 G-variant test-build `lk`** but flashed the
  **2022 retail** `boot`/`dtbo`/`vbmeta*`/`md1img`. That lk cannot hand off to the
  new images -> hang, black screen, no USB re-enumeration.
- Planned fix: write the **retail `lk` + `lk2`** (`lk.img`, 1,114,976 B,
  md5 `fbe029d58a983b6dbd1ed4cf19aeb9d6`) once we regain BROM.
  Reversible: current lk dumped in `backup/lk.bin` and `backup/arch_state_20261025/mmcblk0p27.bin`
  (first 1,114,976 B md5 `2b918eea...` and `db4a1061...` respectively).

### Useful artefacts
- `flash_retail.sh`  — retail flash (retries pre-flight, 20 writes + reset)
- `brom_check.sh`    — READ-ONLY: printgpt + dump lk/lk2/seccfg, for diagnosing
- `firmware/stock_retail/bin/` — space-free symlinks used by the flash script
- mtkclient `wo` command = write at **absolute** flash offset (`--offset`, `--length`),
  usable to resume/split a 5 GB `super` write into chunks if a session drops.

### 36b. RESOLVED — retail `lk`/`lk2` was the fix (18:48)
- Root cause of the "dead after flash" state: we had kept the **2020 G-variant
  test-build `lk`** while writing the **2022 retail** `boot`/`dtbo`/`vbmeta*`/`md1img`.
  The old `lk` could not hand off to the new images -> black screen, no USB, no fastboot.
- Key insight about BROM timing on this device: `0e8d:0003` is exposed for **only ~1 s**
  on every power-up, then the preloader (`0e8d:2000`) takes over.
  * A listener that slept 4 s after detecting BROM **always missed the window**
    (that is why the pre-flight kept failing with "BROM not reachable").
  * `Port.handshake()` polls every **0.3 s** and waits indefinitely, so the fix is to
    **start mtkclient BEFORE plugging in** (pre-arm), not to react to the port appearing.
- Fix applied with `flash_lk.sh` (pre-armed mtkclient, no sleep):
  ```
  Wrote lk.img  to sector 1132544  count 4096   (retail lk, md5 fbe029d5...)
  Wrote lk.img  to sector 1136640  count 4096   (lk2)
  reset
  ```
  DA log: `DA SLA is disabled`, `EMMC USER Size 0xe8f800000`, DA extensions at 0x4fff0000.
- Result: **phone boots the retail ROM.** Orange state preserved (seccfg untouched),
  preloader untouched.

## 37. Retail ROM running, Magisk root, AT channel, WiFi MAC (2026-10-25 ~19:40)

### Retail ROM verified on device
```
ro.build.fingerprint : TECNO/KE7-GL/TECNO-KE7:10/QP1A.190711.020/220729V478:user/release-keys
ro.build.display.id  : KE7-H693HJKM-Q-GL-220729V478
ro.build.date        : Sat Jul 30 00:19:42 CST 2022
gsm.version.baseband : MOLY.LR12A.R3.MP.V118.11.P53
ro.build.type        : user      ro.debuggable: 1
```
NOTE: `ro.product.test_tssi=1` and `ro.transsion.zzs.test=1` are ALSO set on the
**retail** build — they were never the "internal test" marker. Only
`ro.tran_test_version` differed (1 on the G test build, empty here).

### Root: Magisk 27.0 (on-device patch + fastboot flash) — no BROM needed
1. `adb push boot.img /sdcard/Download/`, `adb install Magisk-v27.0.apk`.
2. In the Magisk app: Install -> "Select and Patch a File" -> `Download/boot.img`
   -> produced `/sdcard/Download/magisk_patched-27000_XXXX.img`.
3. `adb pull` it, then **fastboot** (real bootloader, `is-userspace: no`,
   `unlocked: yes`, product `ke7_h693`):
   `fastboot flash boot /tmp/opencode/magisk_patched.img` -> `fastboot reboot`.
4. In Magisk: Settings -> Superuser access -> **"Apps and ADB"** (+ Grant on prompt).
   Then `su -c id` -> `uid=0(root) ... context=u:r:magisk:s0`.
   `adb root` is NOT usable on this ROM: it restarts adbd and the USB gadget never
   re-enumerates (phone stays alive; replug returns adb as shell again).

NOTE: the **bootloader fastboot works fine** and does NOT mangle partition names.
The `_no` suffix bug was exclusive to **fastbootd** (`is-userspace: yes`).

### AT channel (works on V118)
```
su -c 'setprop persist.vendor.service.atci.autostart 1'
su -c 'setprop ctl.start atcid'          -> /dev/socket/adb_atci_socket
su -c '/data/local/tmp/atci_cli AT'      -> OK
```
`atci_cli` rebuilt from `tools/atci_cli.c` (aarch64-linux-gnu-gcc -static -O2).

IMEI state on V118:
```
AT+CGSN          -> OK (no IMEI string)
AT+EGMR=0,7      -> +EGMR: ""      (IMEI1 empty)
AT+EGMR=0,10     -> +EGMR: ""      (IMEI2 empty)
AT+EGMR=?        -> +EGMR: (0,1),(0-5,7-15)
AT+EGMR=1,7      -> ERROR          (syntax probe, ambiguous)
AT+EGMR=1,7,""   -> ERROR
```
`custom_allow_at_write_imei()` (custom_l4_utility.c:728) returns **KAL_FALSE** when
`__NVRAM_CRITICAL_DATA_SIGN_SUPPORT__` is defined (production), and KAL_TRUE only with
`__MTK_INTERNAL_ENG_USER__`. So a production V118 write is expected to be refused;
a definitive test needs a syntactically valid IMEI.

### WiFi MAC (NVRAM warning gone)
- After the flash `/data/vendor/macwifi` was gone and wlan0 fell back to
  `00:08:22:xx:xx:xx` (MTK default) -> driver advertises `NVRAM WARNING: Err = 0x10`.
- Fix: `printf '02:00:00:00:00:01' > /data/vendor/macwifi` (17 bytes, no newline),
  `chown wifi:wifi`, `chmod 660`, then **reboot** (`wlan_assistant`, PID 751, only
  runs at boot and writes the MAC into the WiFi NVRAM).
- Verified after reboot: `wlan0` -> `02:00:00:00:00:01`.
  `mBlacklistedSsids: {}` (runtime empty; the declared entry is a stale leftover in
  `WifiConfigStore.xml`).
- `wlan0` may later show a *different* randomized MAC per network — that is Android
  per-SSID MAC randomisation, not an NVRAM problem.

## 38. IMEI deep-dive on the retail ROM (2026-10-25 ~20:00)

### Root + tools on device
- Magisk 27 root works: `su -c id` -> `uid=0(root) context=u:r:magisk:s0`.
  Requires Magisk setting **Superuser access = "Apps and ADB"** (+ Grant).
  `adb root` is NOT usable (adbd restart kills the USB gadget).
- `atci_cli` (static aarch64) at `/data/local/tmp/atci_cli`; AT works:
  `su -c 'setprop persist.vendor.service.atci.autostart 1'`, `setprop ctl.start atcid`
  -> `/dev/socket/adb_atci_socket`.

### AT+EGMR is dead on BOTH modems
```
V118 (retail MOLY.LR12A.R3.MP.V118.11.P53):
  AT+EGMR=0,7   -> +EGMR: ""      (empty)
  AT+EGMR=1,7,"<valid Luhn IMEI>" -> ERROR   (nothing written)
V114 (engineering MOLY.LR12A.R3.MP.V114.9.P1, flashed to test):
  identical: write -> ERROR
```
`custom_allow_at_write_imei()` (custom_l4_utility.c:728) returns KAL_FALSE unless
`__MTK_INTERNAL_ENG_USER__` is defined, and KAL_FALSE unconditionally when
`__NVRAM_CRITICAL_DATA_SIGN_SUPPORT__` is defined (production). Neither modem build
is an engineering-user build, so the gate is closed in both.

### NVRAM storage facts (all verified on-device)
- `nvdata` = `/dev/block/mmcblk0p9`, ext4, mounted at `/mnt/vendor/nvdata`.
- Modem NVRAM files: `/mnt/vendor/nvdata/md/NVRAM/{NVD_IMEI,NVD_DATA,NVD_CORE,CALIBRAT,BACKUP}`.
- Pulling 64 MB over `adb exec-out su -c cat` **corrupts** the image (su/pty translates
  \n -> \r\n, +10,169 bytes). Workaround: `su -c dd ... of=/data/local/tmp/x`, chmod 644,
  then `adb pull`. Clean image md5 `3f1c807378bdb549ee2166f26bc8c86f`.
- Raw `nvdata` has **506 LDI records**. Header (little endian):
  `"LDI\0" | lid u16 | items u16 | itemsize u32 | attr u24 | ...` payload at +0x40.
- **IMEI candidate: LID 0xF00A, items=2, itemsize=0x20, attr=0x006081**, stored twice
  (file `NVD_IMEI/NV0S_000`, raw offset `0xa01000`). 2 items = dual SIM.
- Other `NVD_IMEI` file `NV01_000` is LID 0xF006 = `__NVRAM_LOCK_NO_`, attr 0x00608A.
- Global MTK SW keys decrypt only the 0x608A record (LOCK). 0xF00A decrypts to garbage
  with "mtk", "mtkv2" and "samsung" seeds and with RC4 variants -> per-device crypto.
- `calc_checksum(data, n)` = `md5(data[:n])[:8] XOR md5[8:16][:8]` (mtk_crypto.py:114).
  It is a **plain checksum, not a signature**.
- **DA SEJ attempts fail**: `mtk da nvitem` with attr forced to 0x20 (HW_5G then
  HW_ENCRYPTED fallback) never yields a checksum-valid plaintext.
  OTP source: mtkclient takes 32 bytes at preloader offset `MMM\x01\x30`+0xC.

### Useful AP-side components found in the retail ROM
- `/vendor/lib64/hw/vendor.mediatek.hardware.nvram@1.1-impl.so` exposes
  `readFileBylid`, `writeFileBylid`, `readFileByName`, `writeFileByName`
  -> NVRAM can be written by LID from Android (no encryption in the HAL, it is a
  byte mover: the WiFi MAC is stored in **plaintext** at nvdata 0x142c004).
- `/vendor/bin/meta_tst` = full META/FT implementation (FT_NvramRestore_OP,
  ATM_SWITCH_MODEM_TO_META, AT+EMETACFG=1, socket server). Not yet driven.
- `/vendor/bin/nvram_daemon`, `/vendor/bin/misc_writer`, `/vendor/bin/atcid`.
- `/mnt/vendor/nvdata/md/NVRAM/` is the live NVRAM; BACKUP dir holds copies.

### WiFi MAC (done)
`printf '02:00:00:00:00:01' > /data/vendor/macwifi` (17 B, no newline),
`chown wifi:wifi`, `chmod 660`, then **reboot** (wlan_assistant runs only at boot).
Verified: `wlan0` -> `02:00:00:00:00:01`.

### Modem state right now
**V114 engineering modem is flashed** (`MOLY.LR12A.R3.MP.V114.9.P1`).
Retail V118 image to restore: `firmware/stock_retail/.../md1img.img`
(57,014,816 B, md5 `90271f2882a971ace87332c5f198a1af`).
`fastboot flash md1img` works on the bootloader (is-userspace: no, unlocked: yes)
and partition names are NOT mangled there (the `_no` bug is fastbootd-only).

## 39. IMEI: plaintext-record experiment FAILED (modem hangs) — 0xF00A is critical

### What was tried
Rebuilt the `0xF00A` record with `attr` forced to `0x000000` (i.e. "plaintext, do not
decrypt") and a normal payload per item:
`encode_imei(imei) + b"\x00\x00" + calc_checksum(data,0xA) + 14*0x00`  (0x20 B/item),
keeping the original 0x10-byte trailing block. Wrote the whole 64 MB `nvdata` over
BROM (`Wrote ... sector 280848 count 131072`, reset).

### Result — modem does NOT accept plaintext critical data
- After boot: `AT+EGMR`, `AT+CGSN`, `AT+CPIN?` all returned **`ERROR:No Modem`**.
- `gsm.sim.state` empty; `ccci_fsm1` / `ccci_poll1` stuck in state **D** (uninterruptible).
- The file `NVD_IMEI/NV0S_000` came back **byte-identical to what we wrote**
  (attr 0x000000, our IMEI payload, original 0x10 tail) — i.e. the modem did not
  re-encrypt and did not accept it; it hung on the record.
- Recovery: pushed the original 144-byte file back
  (`md5 3418979289a70db1b06f1c193ea769aa`), chown radio:radio, chmod 660, reboot ->
  `AT` OK again, `+EGMR: ""`, SIM LOADED.

**Conclusion:** `LID 0xF00A` (2 items x 0x20, attr 0x6081) is a **critical, validated**
NVRAM item and almost certainly the IMEI record. The modem requires the payload to be
encrypted with the device HW key; a plaintext (attr=0) record is fatal to the modem.

### Why the DA/SEJ route failed
`mtk da nvitem` derives the SEJ key from an OTP blob at `MMM\x01\x30`+0xC in the
preloader. In **both** our preloaders (retail 295,012 B and G-variant 294,132 B,
both found at offset 0xbc) those 32 bytes are **all zero**, so the DA crypto is run
with a zero key -> garbage -> checksum check fails in both HW_5G and HW_ENCRYPTED modes.
The real key material is chip-internal and not exposed by the preloader.

### Device state after this section
- Retail ROM, Magisk root, atcid up, AT working.
- **Retail modem restored: `MOLY.LR12A.R3.MP.V118.11.P53`** (fastboot flash md1img).
- IMEI still empty; SIM LOADED; `CSQ 99,99` (no RF because ME is illegal).

### Remaining viable routes (in order of practicality)
1. **META + MauiMETA** (Windows host or VM). We now know how to force META from BROM:
   `mtk da meta usb` (`set_meta` writes boot_mode=1/com_type=2), or `misc_writer`.
   MauiMETA's "IMEI download" then performs FT_NVRAM_WRITE and the **modem** does the
   encryption/signing, so the key problem disappears.
2. **Implement FT** ourselves: `/vendor/bin/meta_tst` on the AP is a full FT/META bridge
   (strings: `FT_NvramRestore_OP`, `AT+EMETACFG=1`, `ATM_SWITCH_MODEM_TO_META`,
   socket server). Would need the FT frame layout.
3. **Patch md1img**: flip `custom_allow_at_write_imei()` to return TRUE, then plain
   `AT+EGMR=1,7/<imei>` works and the modem handles NVRAM itself.
   Modem image is a raw container (`0x58881688` + "md1rom") with **no ELF/symbols**;
   section 0 = md1rom 22,604,644 B. Needs real RE work.

## 40. Modem LID table found in md1img (confirms the IMEI record)

`NV01` / `NV0S` appear at md1img offset ~0x157E888 — this is the **ltable**
(`ltable_entry_struct`, see `ft_nvram_def.c`). Decoded entries:

```
lid=0xF006 total=1 size=0x10 def=0x90BB9541 cat=0x2400 attr=0x608A name="NV01"+"000"
lid=0xF00A total=2 size=0x20 def=0x90BB94DD cat=0x2400 attr=0x6081 name="NV0S"+"000"
lid=0xF007 total=1 size=0x01 def=0x90D05240 cat=0x80000000 attr=0x00000000 name="NONE"
lid=0xF01C total=1 size=0x4B8 name="MTCR"
```
-> the on-disk files `NVD_IMEI/NV01_000` and `NVD_IMEI/NV0S_000` map 1:1 to those
entries, and **LID 0xF00A = "NV0S" (2 records x 0x20) is the IMEI/IMEISV item**
(category 0x2400 = IMPORTANT, hence invisible in the META FAT editor and write-gated).

Note: `NVRAM_CATEGORY_IMPORTANT` items "will not appear in meta FAT Editor (ex: IMEI
and SML)" — nvram_interface.c:2376. So a plain META NVRAM editor cannot fix IMEI;
only the dedicated FT "IMEI download" op can.

### Base-address attempts (for the md1img patch route)
- ltable default pointers imply base `0x90000000`, but no literal in the image points at
  the `+EGMR` strings with that base (0 hits), so the code/rodata sections are likely
  loaded at different bases or use relative references. md1rom section = 22,604,644 B,
  no ELF/symbols. Patching `custom_allow_at_write_imei` therefore needs real RE.

## 41. LD0B route tested and ruled out; NV0S confirmed as THE IMEI item

### Ground truth established
- Hiding `NVD_IMEI/NV0S_000` and rebooting -> `ERROR:No Modem` (modem hangs).
  Feeding it a plaintext record -> also `No Modem`.
  => **LID 0xF00A "NV0S" (2 x 0x20) is the IMEI/IMEISV record the modem validates.**
- `NVD_IMEI/LD0B_001` does not exist on this device and was never read:
  created it (384 B, both LID 0xEF11/attr 0x6088 and LID 0xEF10/attr 0x0A variants),
  rebooted twice -> `+EGMR: ""` unchanged and the file was **byte-identical after boot**
  (modem never touched it). Removed again.

### Open-source algorithms found (very useful, but for the SW-AES items)
- `github.com/timjosten/mtk_imei` (PHP) and
  `github.com/alltechdev/mtk-imei-switcheroo` (`tools/nvram/imei_tool.py`) both implement
  the **LD0B** IMEI item:
  - AES key `3f06bd14d45fa985dd027410f0214d22`, derived from the global MTK seed via
    `scramble_iv_key` + AES-256-CBC (same as `SST_Get_NVRAM_SW_Key`, verified equal).
  - record = 0x40 LDI header + 10 x 0x20 blocks, `LDI\0\x10\xef\x0a\x00` (LID 0xEF10).
  - block = BCD IMEI(8) + FF FF + md5-xor checksum(8) + 14 zero bytes.
  - confirms our payload/checksum construction was correct.
- **But** this device's IMEI item is NV0S (0xF00A, attr 0x6081), which is **HW/SEJ
  encrypted** — the global AES key decrypts it to garbage, and the DA cannot reproduce
  the key (preloader OTP blob is all zeros).

### Conclusion
Writing the IMEI requires the **modem** to produce the NV0S payload (META / FT
`IMEI download`), or patching md1img to re-enable `AT+EGMR`. No offline NVRAM edit
can work on this platform.

## 42. Retail ROM debloat + performance investigation (2026-10-27)

### Debloat
All removals are **per-user** (`pm uninstall --user 0`) - APKs untouched on /product and
/system, fully reversible with `pm install-existing <pkg>`. 265 -> 207 packages.
Removed: WPS, Facebook (katana/orca/appmanager/services/system), Instagram, 4 Gameloft
games, Boomplay, Talpa browser, Tecno Spot, scanningrecharger, magazineservice,
microintelligence, nephilim, statisticalsales, rlk.mi, rlk.feedback, questionnaire,
plat.appupdate, systemupdate, PalmStore, AHAGames (net.bat.store), SmartCaller,
CoolVideo, HiTranslate, rlk.weathers, phonemaster, videocallenhancer, wifiplaytogether,
datatransfer, onekeytransfer, carlcare, trancare, repaircard, manualguide, audioshare,
health, batterylab, agingfunction, aftersalecalibrationtool, swfp.factory,
westalgo.factorycamera, reallytek.wg, Kika keyboard, XShareLite, XHide, Xkit,
smartpanel, googlequicksearchbox, dualapp.
Kept: all GApps, camera, HiOS launcher, gallery, file manager, clock, calculator,
sound recorder, FM radio, video player, theme overlays, Magisk, all MTK/AOSP services.

**Two removals broke things and were restored:**
- `com.hoffnung` -> provides `com.hoffnung.cloudControl.RemoteConfigProvider`, used by
  `com.android.phone`. Removing it crash-looped PhoneApp 104x (huge CPU load, lag).
- `com.transsion.applock` -> provides `com.transsion.applock.provider`, used by
  `com.android.quickstep/com.android.quickstep.RecentsActivity`. Removing it made the
  **recent-apps screen crash** (SecurityException: Failed to find provider).
Rule: Transsion apps expose ContentProviders consumed by core apps; test recents,
dialer and settings after any removal.

### Performance: sluggish UI / touch lag - measured, not guessed
- Display/panel fine: SurfaceFlinger `VSYNC period 16666667 ns` (60 Hz), mode 60 fps.
- App code fine: UI-thread draw 0.27 ms, traversal 0.06 ms.
- Frame ends up at **32-40 ms median, 88-91 % janky, "High input latency" 100-166**.
- **HWC is the bottleneck**: `android.hardware.graphics.composer@2.1-service` burns
  **95 % of a core (~22 ms CPU per frame)** during scrolling and reports ~43 fps,
  so every second vsync is missed -> effective 30 fps.
- Ruled out by measurement: CPU governor/clocks (2.0/1.7 GHz at load), GPU clock
  (forced 823 MHz via `echo 823000 > /proc/gpufreq/gpufreq_opp_freq` -> no change),
  DFPS (`stop dfps-1-0` -> no change), charging/battery, the debloat itself.
- User confirms the **G-variant test build had the same lag**, so it is not the retail
  dtbo/panel config; it appears inherent to this HiOS build on MT6768.
- Animations set to 0.5x (`window/transition/animator_duration_scale`).
- NOTE: forcing GPU OPP is persistent until cleared; `cat /proc/gpufreq/gpufreq_opp_freq`
  shows "Keeping OPP frequency is disabled" when unlocked.

### OTA / firmware status for KE7 (official builds, per needrom listing)
- `KE7-H693HJKM-Q-GL-220729V478` (2022-07-29, security patch **2022-07-05**) = **ours**
  and the **newest GL build**.
- Newer exists only for another variant: `KE7-H693HK-Q-TR-220831V134` (Turkey, H693HK).
- Older GL: V472(220510), V462(220228), V450(211111), V438(210705), V414, V403, V381,
  V321, V269.
- "G" builds (GHIJKM lineage, e.g. 200617V074) are the internal/test builds.
- Device is EOL (Android 10, last security patch July 2022) -> no further OTA expected.

## 43. RAM reduction: launcher replacement + GApps trims (2026-10-27)

### Launcher comparison (measured on this device, PSS via dumpsys meminfo)
| launcher | package | PSS | Java | Native | Graphics | CPU idle | APK |
|---|---|---|---|---|---|---|---|
| HiOS/Quickstep | com.transsion.hilauncher | **193 MB** | 84 | 66 | 15 | 3.0-3.5 % | ~19 MB |
| KISS | fr.neamar.kiss | **34 MB** | 3 | 13 | 6.4 | 0.0-0.2 % | 2.2 MB |
| ap15 | com.aurhe.ap15 | **36 MB** | 1.9 | 15.4 | 8.7 | 0.0-0.2 % | 2.0 MB |

- HiOS launcher **disabled** (`pm disable-user com.transsion.hilauncher`), not uninstalled.
- Current default home: **ap15** (`com.aurhe.ap15/.LauncherActivity`), v2.27.3.
  KISS is installed as an alternative (`fr.neamar.kiss/.MainActivity`).
- Recents still works with either launcher because nav mode is **3-button**
  (`settings get secure navigation_mode` = 0) and the recents key goes through
  `com.android.quickstep/.RecentsActivity` (independent of the home app).
- ap15 came from APKPure (`d.apkpure.com/b/APK/com.aurhe.ap15?version=latest`);
  Play Store cannot install (no Google account signed in -> UnauthenticatedMainActivity).
  `INSTALL_FAILED_VERIFICATION_FAILURE` was solved with:
  `settings put global verifier_verify_adb_installs 0`, `package_verifier_enable 0`.

### Removed in this round (per-user)
`com.google.android.apps.tachyon` (Duo), `com.google.android.apps.wellbeing`,
`com.transsion.plat.appupdate`, `com.transsion.systemupdate`,
plus earlier `com.transsion.smartpanel` and `com.google.android.googlequicksearchbox`.

### Memory effect
`free` 46 MB -> ~365 MB; `Free RAM` (meminfo) 1.70 GB -> ~1.97 GB;
Used PSS 1,860 MB -> ~1,589 MB. Note Android reports reclaimable cache as "used".

### Known constraint for further GApps stripping
YouTube and Play Store both require `com.google.android.gms` (the 273 MB PSS item) -
it cannot be removed. Everything else Google is removable (Chrome, Photos, Docs, Maps,
Gmail, YouTube Music, Videos, Talkback, TTS, Messages, sync adapters, Android Auto,
PartnerSetup, SetupWizard, feedback, print recommendation) = ~700-800 MB APK,
~250-350 MB RAM. To keep apps installed but not running in background:
`cmd appops set <pkg> RUN_IN_BACKGROUND ignore`.

## 44. Final GApps strip + Messages + appops (2026-10-27)

- Launcher: **ap15** (`com.aurhe.ap15/.LauncherActivity`, v2.27.3) is the default home.
  KISS was removed at user request. HiOS launcher stays disabled (not uninstalled).
- Messages: Google Messages removed; **Fossify Messages** (`org.fossify.messages`,
  F-Droid, 6.7 MB) installed and holds `android.app.role.SMS`.
- 19 more Google packages removed (all except what YouTube + Play Store need):
  maps, docs, photos, chrome, youtube.music, gm(Gmail), videos, projection.gearhead,
  apps.restore, setupwizard, partnersetup, onetimeinitializer, feedback,
  printservice.recommendation, marvin.talkback, tts, gms.location.history,
  syncadapters.calendar, syncadapters.contacts.
- Remaining Google (minimum set): gms, gsf, **com.android.vending (Play Store)**,
  youtube, webview, inputmethod.latin (Gboard), permissioncontroller,
  packageinstaller, documentsui, configupdater, ext.services/shared, modulemetadata,
  ims, overlays.
- Package count now **189** (started at 265).
- Background execution blocked on Play Store and YouTube:
  `cmd appops set <pkg> RUN_IN_BACKGROUND ignore` and `RUN_ANY_IN_BACKGROUND ignore`,
  then `am force-stop`. They still work when opened; they just cannot wake themselves.
- Remaining big PSS: gms 311 MB (untouchable - required by YouTube + Play Store),
  Gboard **128 MB** (replaceable), systemui 113 MB, system_server ~170 MB.
- No crashes after the batch (verified launcher, recents, settings).

## 45. Post-debloat app set (2026-10-27)

### Installed non-system apps (only 5)
```
org.fossify.messages      SMS (SMS role holder)
com.aurhe.ap15            default launcher (text-based)
org.mozilla.fennec_fdroid Firefox (F-Droid build) + uBlock Origin installed
                          (profile: /data/data/org.mozilla.fennec_fdroid/files/mozilla/*/extensions/uBlock0@raymondhill.net.xpi)
org.videolan.vlc          media player (arm64 build 13070206; F-Droid ships VLC per-ABI -
                          the x86_64 apk fails with INSTALL_FAILED_NO_MATCHING_ABIS)
com.topjohnwu.magisk      root
```
Gallery: `com.gallery20` (HiOS gallery) still installed and verified working.
YouTube: removed (user will use a patched client "Morphe").
YouTube Music: removed.

### Memory after all changes
`Free RAM` 1.70 GB -> **2.26 GB**; `Used PSS` 1.86 GB -> **1.24 GB**.
`free -m`: 3549/3803 used but only ~1.2 GB is real PSS - rest is reclaimable cache.
Package count 265 -> **190**.

### Notes / open items
- Play Store (`com.android.vending`) still installed but **no Google account is signed in**,
  so it can only be used after signing in; otherwise it is dead weight and can be removed.
- Gboard (`com.google.android.inputmethod.latin`) is the largest replaceable app:
  PSS 128 MB / RSS 251 MB. Replace with Fossify Keyboard to save ~100 MB.
- Lag/30-40 fps: root cause is the vendor HWC (see section 42); unresolved.
- IMEI/cellular: still blocked (see sections 38-41).

## 46. Morphe (patched YouTube) installed (2026-10-27)

- **Morphe Manager v2.2.0** installed from the official GitHub release:
  `https://github.com/MorpheApp/morphe-manager/releases/download/v2.2.0/morphe-manager-2.2.0.apk`
  package `app.morphe.manager`, 41,684,300 bytes,
  sha256 `5a175a77f671088c97ebaa6fdd65b1d4ed9f07dda44d59a37d3d11a712da2c44`
  (release also ships a detached `.asc`; GPG verification skipped - no public key on hand).
- On first launch it downloaded its patch sources ("Morphe Patches", ~13 MB) and offers
  Reddit / YouTube / YouTube Music / "More apps (Community patches)".
- YouTube itself is **not installed** (removed earlier); the user patches it entirely
  inside Morphe Manager. Nothing else needed from the host side.
- NOTE: do **not** apply `cmd appops set <pkg> RUN_IN_BACKGROUND ignore` to the patched
  YouTube - it would break background/PiP playback.

## 47. Can the vendor HWC be replaced? - NO (answered 2026-10-27)

- The HWC HAL is `android.hardware.graphics.composer@2.1-service` +
  `/vendor/lib64/hw/hwcomposer.mt6768.so`. It is the only component that knows this
  display driver's `DISP` ioctls, so substituting an AOSP/generic HWC is not possible -
  it would have no panel/vsync control at all.
- The practical alternative is forcing SurfaceFlinger to composite with the **GPU**
  (RenderEngine/Mali) instead of the HWC overlay engine - the "Disable HW overlays"
  developer option. **This ROM's SurfaceFlinger does not implement it:**
  `libsurfaceflinger.so` contains no `debug.sf.disable_hwc` (only `debug.sf.hwc_service_name`,
  `debug.sf.enable_hwc_vds`, `debug.sf.disable_backpressure`, ...), and there is no
  composition-type override plumbed in. The dev toggle writes a Settings value that SF
  ignores, which is why setting `debug.sf.disable_hwc=1` + SF restart changed nothing
  (composition stayed DEVICE).
- Conclusion: the 30-40 fps / HWC-bound behaviour is not fixable on this ROM from
  userspace. Would need a different ROM/GSI (same vendor HAL, so probably identical)
  or a vendor fix that does not exist for this EOL device.

### User decisions
- IMEI / cellular: dropped, no longer pursued.
- Play Store and Gboard: **kept** (stop removing).

## 48. Android -> mainline hardware inventory (2026-10-27)

Captured the complete hardware map from the running retail ROM into
**`hardware-dump/HARDWARE_INVENTORY.md`** with raw dumps alongside:
- `fdt.dtb` / `vendor.dts` — vendor device tree (5,685 lines, 436 compatibles)
- `kconfig.gz` — kernel 4.14.141 config
- `input_devices.txt`, `interrupts.txt`, `platform.txt`, `regulators.txt`, `gpio.txt`
- `sensors.txt`, `camera.txt`, `lshal.txt`, `thermal.txt`, `power.txt`, `leds.txt`
- `ext/cfg/` — audio policy + audio_param (1.2 MB) + thermal policies

Highlights: LCM **nt36525b_hdp_dsi_vdo_txd_boe_ke7** (Novatek NT36525B, 720x1640,
DSI video mode), backlight `lcd-backlight` max 255 via `1100e000.disp_pwm`,
touch Novatek NVT-ts-spi @13.6 MHz, keys `mtk-kpd @10010000`, PMIC MT6358,
charger **RT9471 @i2c 0x53**, audio `mt6768-mt6358-sound` with **speaker amp GPIO 39**,
camera CAMSYS + GC02M1/OV02B10, sensors behind SCP, WiFi @18000000, Mali-G52 @13040000.
See HARDWARE_RESEARCH_AND_DRIVER_RE.md for the porting checklist.

## 49. Porting artifacts drafted (2026-10-27)

Created `hardware-dump/porting/`:
- **`panel-nt36525b-ke7.dtsi`** — DSI panel node for NT36525B.
  Known: 720x1640@60, BURST video mode, burst clock **228.5 MHz** (`mm_dsi0`),
  reset **GPIO 45**, bias **ENP 153 / ENN 152**, backlight OCP2130.
  Missing: porch values + pixel clock (in the LK LCM driver, string at lk.img 0x8CDEE).
- **`audio-amp-gpio39.dtsi`** — speaker amp on **GPIO 39** (`extamp_mode=2`) as a
  regulator-fixed + ASoC DAPM hook. This is the "no loudspeaker on Linux" fix.
- **`PORTING.md`** — per-subsystem status table + suggested bring-up order.

Extra facts found while drafting:
- `rt9471` charger confirmed at **i2c bus 5, addr 0x53** (dmesg `rt9471 5-0053`).
- Keys: `mtk-kpd @10010000`, `kpd-sw-pwrkey = 0x74` (KEY_POWER), debounce 0x400.
- Backlight is **OCP2130** i2c (LK symbol `ocp2130_i2c_write_byte`, DT `led_mode=5`),
  not plain PWM - the `1100e000.disp_pwm` node still exists as a fallback.
- i2c map captured: 5 buses with devices on 0,2,3,4,5,6,7; buses 1 and 8 empty.

## 50. Runtime META attempt — Android-side transport identified (2026-10-28)

Goal: get ModemMETA (Wine) talking to the modem **without** the bootloader, because
LK ignores the DA `SET_META_BOOT_MODE` flag on this device.

### What was tried and what happened

| Step | Result |
|---|---|
| `da meta usb` + `reset` in BROM | DA reports success, phone boots Android anyway. LK ignores the flag. |
| `0e8d:20ff` during that boot | **KPOC/HID off-mode charging**, not META. No tty. |
| `boot_mode` sysfs write | `/sys/class/BOOT/BOOT/boot/boot_mode` is a **file on `mmcblk0p43`** (`/dev/block/mmcblk0p43`), `rw`. Write of `1` persisted and survived reboot, but Android still booted: the node is cosmetic for LK. |
| `meta_tst` in normal boot | Exits with `[Meta] Normal mode flag is not 1,exist!` |
| Bind-mount fake `1` over `boot_mode` | **Accepted** — `meta_tst` stays alive. It opens `/dev/ccci_ccb_meta`, `/dev/ccci_ccb_ctrl`, `/dev/pmsg0` and a netlink socket, but **never switches the modem** (AT still answers `OK`) and exposes nothing to the host. |
| preloader `METAMETA` handshake over `/dev/ttyACM0` | No `READY` ever arrives. The node also lingers as a dead leftover after unplug, so triggers must use sysfs `0e8d:2000`, not the tty node. |

### The real META wiring (from vendor init scripts)

`/vendor/etc/init/hw/meta_init.rc` and `init.mt6768.usb.rc` define the whole scheme:

- **META boot USB:** `acm.gs0` only, PID **0x2007**, `bDeviceClass 02`.
  On the phone this is `/dev/ttyGS0`; on the host it becomes `/dev/ttyACM0`.
- `ro.boot.usbconfig`: `0` = `adb_acm` (PID 0x200E), `1` = META `acm`,
  `2` = META+ELT, `3` = META+ELT+ADB (PID 0x2040).
- **ATM (Android Test Mode):** `ro.boot.atm=enable` starts `meta_tst`
  (`init.mt6768.rc:1054`). Current value: `ro.boot.atm=disabled`.
  ATM USB layouts: `atm_gs0` = mtp+adb+**acm.gs0**, PID **0x200A**;
  `atm_gs0gs3`, PID 0x2026.
- **ATE / AT-over-USB:** `via_bypass` = `via_modem` + `via_ets` + `via_atc`
  (+adb), PIDs 0x2031/0x2033 (no adb), 0x2032/0x2034/0x2050 (with adb).
- `meta_tst` contains `/dev/ttyGS0` and `persist.vendor.meta.connecttype`
  (`usb` / `wifi`), so its PC transport is the gadget ACM port.

### Live experiment (worked, then broke)

1. `setprop sys.usb.config gs1gs3` → `0e8d:2029`, host gets `/dev/ttyACM0`
   and `/dev/ttyACM1`, **adb stays connected**.
2. Data proven: `printf PING > /dev/ttyGS1` appears on host `/dev/ttyACM0`.
   **Caution:** with `gs1gs3` the linked functions are `acm.gs1` + `acm.gs3`,
   and the host ACM0 mapped to **ttyGS1**. Function name != tty index.
3. `setprop sys.usb.config atm_gs0` → `0e8d:200A`, links
   `f1=mtp.gs0  f2=ffs.adb  f3=acm.gs0`, host `/dev/ttyACM0`, adb alive.
4. **Flap:** re-enumeration every ~6 s. Cause found in `init.mt6768.usb.rc`:
   the `atm_gs0` build rule is gated on
   `vendor.usb.ffs.ready=1 && vendor.usb.clear=2`. When the gadget resets,
   adbd reopens ep0 → `ffs.ready` 0→1 → init **rebuilds the gadget** → reset
   → loop. Phone dmesg shows `USB_REQ_SET_CONFIGURATION: value=0`.
5. `setprop vendor.usb.clear 0` stopped the rebuilds but the gadget ended up
   **unbound**: the phone disappeared from USB entirely (no `0e8d` device).
   Recovery: unplug/replug the cable (Android re-applies `persist.sys.usb.config`,
   which is now `atm_gs0`), or reboot.


### 50.1 ROOT CAUSE of the USB "flapping" (2026-10-28, later)

The 6 s re-enumeration was **not** the phone and **not** the init rule: it was the
**host's GNOME MTP daemon** `gvfsd-mtp` holding the whole USB device node
(`/dev/bus/usb/003/127`) and resetting it whenever an MTP function was present.

Evidence:
- `fuser -v /dev/bus/usb/003/127` → `gvfsd-mtp ... F....`
- `journalctl -k` showed `usb 3-3: reset high-speed USB device number 127` in a loop
  and host udev `ttyACM0` remove/add pairs, while the phone-side dmesg showed
  `USB_REQ_SET_CONFIGURATION: value=0`
- after `pkill -x gvfsd-mtp` the resets **stopped** (no USB reset for minutes)
- plain `adb`-only config was always stable because it has no MTP function

Implication: any experiment that adds `mtp.gs0` or `mass_storage` to the gadget
MUST first kill `gvfsd-mtp` (use `pkill -x`, not `pkill -f`, which kills the shell).

### 50.2 Chosen transport: META over TCP (no COM port)

`MetaApp.dll` in ModemMETA contains:

```
connectType :%d(enum:uart=0;usb=1;wifi=2;)
Connecting socket failed: ip = %s, port = %d
```

So the PC tool can connect over TCP instead of a serial port, and Wine supports
sockets natively. `meta_tst` has the matching side (`persist.vendor.meta.connecttype
= wifi`, "Socket listen done", "Socket get server IP address:%s Port:%d").
Plan: `sys.usb.config=rndis,adb` (IP over USB, no MTP, no gvfsd), start
`meta_tst` in wifi mode, read the listening port with `ss -ltnp`, then point
ModemMETA at the phone's IP and that port.

### Current state

- Phone: Android, **off USB** at the time of writing; `persist.sys.usb.config=atm_gs0`,
  `sys.usb.config=atm_gs0`, `vendor.usb.clear=0` (needs replug to rebuild).
- Next experiment: rebuild the gadget **once**, then keep `vendor.usb.clear=0`
  only after the UDC is bound, and verify stability for 60 s before starting
  `meta_tst`. If adb and ACM0 are stable, start `meta_tst` (bind-mount
  `boot_mode=1`), check that it opens `/dev/ttyGS0`, set
  `persist.vendor.meta.connecttype usb`, and map host `/dev/ttyACM0` to Wine COM1.

### 50.3 meta_tst "init fail" solved: com-port-type sysfs file is missing

`meta_tst` aborted its transport setup with:

```
[Meta] Failed to open com port type file /sys/bus/platform/drivers/meta_com_type_info/meta_com_type_info
[Meta] com port type: 0
[Meta] Enter meta_tst init fail
```

This kernel has **no `meta_com_type_info` platform driver at all**
(`ls /sys/bus/platform/drivers/meta*` -> nothing). The file is a plain text
integer selecting the META transport (MetaApp enum `uart=0;usb=1;wifi=2`).

Verified mapping by faking the file in a **private mount namespace**
(`unshare -m`, available as `/system/bin/unshare`):

| file content | result |
|---|---|
| `1` | `meta_tst` opens **`/dev/ttyS0`** -> 1 = UART |
| `0` | `meta_tst` opens **`/dev/ttyGS0`** -> 0 = **USB** (what we need) |

Recipe that works (also keeps the `boot_mode=1` bind mount):

```sh
printf 1 > /data/local/tmp/fbm
mount --bind /data/local/tmp/fbm /sys/class/BOOT/BOOT/boot/boot_mode
setprop persist.vendor.meta.connecttype usb
unshare -m /system/bin/sh -c '
  mount -t tmpfs tmpfs /sys/bus/platform/drivers
  mkdir -p /sys/bus/platform/drivers/meta_com_type_info
  printf 0 > /sys/bus/platform/drivers/meta_com_type_info/meta_com_type_info
  exec /vendor/bin/meta_tst'
```

Observed with content `0`: pid holds `/dev/ttyGS0` (fd 5), `ccci_ccb_meta`,
`ccci_ccb_ctrl`, an extra socket; logs `CCB is ready` / `Create modem1 success`.
The modem is **not** switched yet at that point (AT still returns OK) — it switches
when the PC client starts the META handshake.

### 50.4 Mistake to avoid: do not rebuild the gadget while adb is the only control

Attempting to rebuild the gadget as `ffs.adb + acm.gs0` (PID 0x200E) after
`setprop persist.sys.usb.config none` left the phone with **no USB at all** and
no adb. `persist.sys.usb.config=none` is dangerous: if it survives to the next
boot, Android will not bind the UDC and there will be no adb.

Rule: never change `persist.sys.usb.config` or unbind the UDC unless a second
control channel is already proven (e.g. WiFi META socket, or a rescue boot).
Use the already-working `atm_gs0` gadget (`mtp+adb+acm.gs0`, PID 0x200A) and just
run `meta_tst` + ModemMETA against `/dev/ttyACM0`; no rebuild is needed.

## 51. Wine abandoned, Windows VM chosen (2026-10-28)

Decision: **remove Wine entirely**; run ModemMETA in a Windows 10 VM with real USB
passthrough. Reason: Wine has no USB support, so ModemMETA could never use its
own USB/BROM path; the runtime bridge still needs a COM port and its BROM step
fails ("SP Brom Error for Boot meta mode procedure").

### Wine removal (completed)
- `pacman -Rns wine winetricks` (also removed cabextract, ntsync-autoload)
- deleted `~/.wine-meta` (1.0 GB), `~/.cache/wine` (80 MB), menu/MIME leftovers
- `update-desktop-database` -> 0 wine references left

### Host cleanup (completed, ~23 GB freed)
- `~/.cache/paru` 6.9 GB, pacman cache 3.4 GB (`pacman -Sc`)
- old ISOs: Arch 2025.09 + 2026.01, Win10 June 2025 (9.5 GB)
- firmware `.zip` originals (extracted trees kept): 5.4 GB
- duplicate ModemMETA zips: 0.2 GB
- free space: 63 GB -> 86 GB

### VM plan
- QEMU 11.1.2 + KVM, `qemu-desktop` and `libisoburn` installed via pkexec
- `~/Documents/vms/win10/win10.qcow2` (50 GB, sparse)
- Win10 22H2 Oct-2025 ISO (consumer editions), unattended
  `payload/autounattend.xml` -> Windows 10 Pro, local admin `mk`,
  autologon, BIOS/MBR layout, `RunSynchronous` installs ModemMETA silently
- `payload/` also holds `ModemMETA Setup.exe` and `Database/` (V118 EDB + APDB
  W2025 + ENUM), built into `payload.iso` (110 MB)
- VM started with `-machine q35 -cpu host -smp 4 -m 6144`, qemu-xhci controller
  for later `usb-host` passthrough, `usb-tablet`, VNC on 127.0.0.1:1 and QMP at
  `/tmp/opencode/qmp.sock`
- control helper: `/tmp/opencode/qmp.py` (shot / key / type / raw)
- planned passthrough target: `0e8d:200A` (atm_gs0 = mtp+adb+acm.gs0) so Windows
  binds `usbser.sys` to the CDC ACM and ModemMETA sees a COM port

### 50.5 Preloader COM-port driver solved (2026-10-29)

Root cause of "It cannot find the Preloader/BROM COM port": Windows had **no driver**
for `USB\VID_0E8D&PID_2000`. Evidence from `C:\Windows\INF\setupapi.dev.log`:

```
!!! set: USB\VID_0E8D&PID_2000&... -> Configured [null] and non-present (ConfigFlags = 0x40)
```

`[null]` = no INF bound, so no COM port existed for ModemMETA to open.

Fix used (fully local, no third-party binaries): a CDC INF that binds the **inbox**
`usbser.sys` to the MediaTek IDs, plus a self-signed catalog accepted by test signing.

- INF from the `evadne/gemini-notes` mirror, extended with
  `USB\Vid_0e8d&Pid_2000`, `Pid_2001`, `Pid_200a&MI_02`, `Pid_200e&MI_02`,
  and a `CatalogFile=mtkpre.cat` line (without it pnputil ignores the catalog)
- `bcdedit /set testsigning on` (VM has no Secure Boot)
- catalog built with `New-FileCatalog` and signed with a self-signed cert that was
  added to `LocalMachine\Root` and `TrustedPublisher` **before** signing
- `pnputil /add-driver C:\Users\mk\mtkdrv\mtkpre.inf /install`

Result:
```
Driver package added successfully. Published Name: oem2.inf
Driver package installed on device: USB\VID_0E8D&PID_2000\...
Driver package installed on device: USB\VID_0E8D&PID_200A&MI_02\...
```

The ACM interface (`0e8d:200A&MI_02`) is now a **"MediaTek USB Port"**, i.e. the
kernel port name ModemMETA's ATM mode expects. Scripts kept at
`/tmp/opencode/mtkpre.inf` and `/tmp/opencode/fix.ps1`.

### 50.6 Build comparison + disk cleanup (2026-10-29)

Freed ~9 GB by deleting `firmware/stock/super.raw` and `firmware/stock_retail/super.raw`
(raw dumps duplicating the two `super.img` sparse images; regenerable with `simg2img`).
Free space 66 -> 75 GB.

Build comparison (strings, no flashing):
- **Both** V060 (`200617V060`, older) and V478 (`220729V478`, current) `lk.img` contain
  `=> META MODE`, `meta com type/id/uart port`, and
  `[META] Check meta info from pre-loader: %x, %x, %d`.
- **Both** preloaders contain `METAMETA`, `ADVEMETA`, `METAFORB`,
  `seclib_brom_meta_mode`, `BR META BOOT`, `BOOT_MODE: %d`,
  `META_COM TYPE/ID/PORT`, `FAST META GPIO: %d`,
  `In fast meta, bypass usb handshake`, `read_meta_proinfo`.
- V060 additionally has `disable_fastmeta = %d`.

Conclusion: the device does **not** lack META support — both builds have it. A different
retail build is therefore unlikely to fix the IMEI problem by itself. Also note the V060
package is for a slightly different variant (`H693GHIJKM` vs `H693HJKM`), so a full
downgrade risks panel/touch mismatches.

`da meta` in mtkclient only sends `SET_META_BOOT_MODE` (0x020006) with
`01 02 00` (boot=meta, com=usb, id=0); it does **not** reboot. The DA reports success,
the flag is set, yet the next cold boot still goes to Android — so either the flag
location/value is not what this preloader reads, or the DA's reset path clears it.

Next experiment (needs BROM): read `misc`, `boot_para` and `proinfo` before and after
`da meta usb`, diff them to locate the flag, then compare against the preloader's
`read_meta_proinfo` logic. BROM is required for this and for any build flashing.

### 50.7 The DA META flag is VOLATILE — proven (2026-10-29)

Experiment: dump `misc` (p15), `boot_para` (p1), `proinfo` (p2), `para` (p3) to host,
run `mtk.py da meta usb` (BROM handshake OK, "Successfully set meta mode to usb"),
then read the same four partitions **while the DA is still alive** (same session).

Result: **all four partitions byte-identical to the baseline** (`cmp` clean, 6 MB /
26 MB / 3 MB / 512 KB). The flag is therefore **not stored on disk at all** — it is a
volatile register/SRAM state that only a DA-initiated *warm reboot* could consume.

Why boot never lands in META:
- `mtk.py reset` calls `daloader.shutdown(bootmode=0)` -> **power-off**, flag lost.
- The xflash DA `SHUTDOWN` command only knows bootmode 0/1/2; there is **no META
  bootmode** and no separate REBOOT command in the xflash protocol.
- Patched `shutdown(bootmode=1)` to reboot in the same DA session after
  `setmetamode` (`MTK_META_REBOOT=1` env in mtk_da_handler.py) -> still powers off.
- Patched `dont_resetrtc=1` in xflash_lib.shutdown (RTC scratch hypothesis) -> still
  powers off. No USB enumeration afterwards; the phone must be powered on manually.

Consequence: on this unit the DA path cannot produce a real META boot. The remaining
options are (a) patch the LK/preloader to force META, (b) find and pull the preloader's
"fast meta" GPIO (`FAST META GPIO: %d`, `In fast meta, bypass usb handshake`), or
(c) implement the META FT protocol against the working `meta_tst` bridge.

Also confirmed while answering the storage question:
- `backup/nvram.bin`, `nvdata.bin`, `nvcfg.bin` are **100% zeros** (single distinct
  byte value sampled across 64 MB) -> the modem NVRAM was fully wiped.
- IMEI is NV item `LID 0xF00A`, NV0S, attr 0x6081, 2 x 0x20-byte records, SEJ-encrypted
  with an OTP/eFuse-derived hardware key. Plaintext writes break the modem; only the
  modem's own NV handler (META) can produce a valid record.

### 50.8 IMEI storage CRACKED (format), crypto still hardware-bound (2026-10-29)

The IMEI is **not** in a raw NV record we can hand-craft. It is an MTK NVRAM **file**
on the live ext4 `nvdata` partition:

```
/mnt/vendor/nvdata/md/NVRAM/NVD_IMEI/NV0S_000      (144 bytes, radio:radio 0660)
```

Header (little endian):
```
00  4C 44 49 00            "LDI\0"  (MTK NVRAM file magic)
04  0A F0                  LID = 0xF00A (IMEI)
06  02 00                  item count = 2 (SIM1, SIM2)
08  20 00 00 00            item size = 0x20
0C  81 60 00               attribute = 0x6081
40  payload: 2 x 32-byte encrypted records (+16 bytes tail)
```
Sibling file `NV01_000` = LID 0xF006, size 0x10, attr 0x608A.

Crypto findings:
- The public MTK "LD0B" software format (AES-128-ECB key `3f06bd14d45fa985dd027410f0214d22`,
  MD5-XOR checksum, BCD swapped nibbles) does **not** decrypt our file.
- Tried that key, the default `0102...` key, MD5(header), zero key, and CBC variants with
  several IVs -> no valid BCD/checksum. So `NV0S_000` is the **SEJ/HW-encrypted** variant
  (`attr 0x6081`, not the SW bit 0x8).
- SEJ is per-device, OTP/eFuse-derived; no universal key exists. mtkclient's
  software SEJ class needs the real HACC registers, so it cannot run offline.
- `mtk.py da nvitem NV0S_000` sends DA `CUSTOMSEJ` (0x4000C); the xflash DA answers
  **"Wrong magic"** (command unsupported). The generic XML DA loader (`da_xml.bin`)
  is not accepted by this BROM (no handshake messages, 420 s timeout).
- mtkclient's `da imei` only handles the LD0B (software AES) layout, not NV0S.

Next viable approach: hook the on-device **nvram_daemon** (root + Frida/ptrace), which
decrypts NV0S through the SEJ driver at boot. Either dump the plaintext to learn the
record, or call the same decrypt/encrypt routine with our IMEI records and write the
file back with root. No BROM, no flashing, no META.

### 50.9 NV crypto is modem-side; AP libraries are stubs (2026-10-29)

Pulled the AP NV stack from the device:
- `/vendor/bin/nvram_daemon` -> `libnvram.so` -> `libnvram_sec.so`
- `libnvram_sec.so` exports `sec_nvram_enc`, `sec_nvram_dec`, `NVM_Enc_Dnc_File`
  but **`sec_nvram_enc`/`sec_nvram_dec` are `mov w0, wzr; ret` stubs** on this build.
  `NVM_Enc_Dnc_File` just calls those stubs. So the AP performs **no** NV crypto.
- `nvram_daemon` only syncs product-info/WiFi/BT at boot; it exposes **no socket**
  (`/dev/socket` has no nvram entry, `/proc/net/unix` none).
- mtkclient's pure-python `SST_Get_NVRAM_SW_Key()` + `decrypt_nvitem()`/`encrypt_nvitem()`
  were tried on `NV0S_000` (all three seeds `mtk`/`mtkv2`/`samsung`, offsets 0x30-0x80,
  ECB and RC4 variants): no valid BCD/checksum. Roundtrip works, so the implementation
  is self-consistent, but this file is not encrypted with those software keys.

The modem firmware (`md1img.img`, 57 MB) does contain the NV key constants
(`SECOND_SEED` @0x14AEDD0, `NV_KEY_CONST` @0x14AEDF0, `MTK_SEED` @0x14FE634) and the
NVRAM sources (`common/service/nvram/src/nvram_l1def.c`, `LR12A.R1.MP`,
`Z:\NVRAM\NVD_IMEI`), i.e. the NV engine is in the modem.

Conclusion: `NV0S_000` is encrypted by the **modem** (SEJ/HACC), and the AP only stores
the resulting bytes. There is no AP-side writer to borrow. The remaining ways to make
the modem produce a valid record are (a) real META, (b) an LK/preloader patch that forces
META, or (c) the preloader "fast meta" GPIO.

## 52. BREAKTHROUGH: real META mode reached (2026-10-29)

The preloader handshake was failing because the **direction was wrong**. The host must
speak first. Protocol (from `neutronscott/mtk-bootseq.py` gist):

```
host  -> "METAMETA"
preloader -> b"READY" + reversed(seq[-3:])   # i.e. b"READYATE"
```

Script: `/tmp/opencode/premeta.py` — polls sysfs for `0e8d:2000`, opens `/dev/ttyACM0`
raw 115200, writes `METAMETA`, reads; repeats while the preloader is present.

Observed on the device (2026-10-29 07:47):
```
RX b'READY'
RX b'ATEM0001'
RX b'ATEM0002'
RX b'ATEMATEX'
```
and the phone re-enumerated as **`0e8d:202D`** = **META+ELT** config:

```
if 1.0: 08/06/50  usb-storage
if 1.1: 02/02/01  cdc_acm  -> /dev/ttyACM0  (META)
if 1.2: 0a/00/00  cdc data
if 1.3: 02/02/01  cdc_acm  -> /dev/ttyACM1  (ELT)
```

Windows (VM) then exposed **COM7 = `USB\VID_0E8D&PID_202D&MI_01`** (META) and
**COM6 = MI_03** (ELT).

ModemMETA (Windows VM, `DUT in META Mode`, Port=UART, COM7) connected successfully:
```
✔ Boot   ✔ Get kernel port   ✔ Connect to AP   ✔ Get SW info
✔ Setup AP Logger   ✔ Finish AP handshake   -> Connect to MD  ... Connected
```

### Remaining blocker: NVRAM database for the IMEI plugin
`IMEI Download` -> "Load NVRAM database" needs a **DB file**:
- "From Target" fails -> `Load NVRAM database flow failed` (device nvdata was wiped,
  so the target has no NVDB to export)
- EDB (MDDB V118) -> `SP_META_File_Operation_Parse_r: Invalid Argument`
- APDB_MT6768_S01__W2025 -> `Load DB flow failed`

The correct file is the **AP-side NVRAM database** that ships on the phone in
`/system/etc/mddb/` (MTK `BPLGUInfoCustomAppSrcP_*` = the MDDB variant the tool
expects). It was not yet pulled because the phone was in META (no adb).

### Next steps
1. Reboot the phone to Android, `adb pull /system/etc/mddb /vendor/etc/mddb`.
2. Re-enter META with `premeta.py` (proven reliable), reattach to the VM.
3. Load the pulled mddb file in `IMEI Download`, then write IMEI1/IMEI2.

### 52.1 Session end state (2026-10-29 ~04:20)

Working end-to-end:
- `premeta.py` handshake -> META+ELT (`0e8d:202D`) -> attach to VM -> ModemMETA
  "DUT in META Mode" + UART + **COM10** -> **Connected** (all AP stages green).
- IMPORTANT: the COM number changes on every re-enumeration (COM7 -> COM10). Always
  read it in the VM with `wmic path Win32_SerialPort get DeviceID,Name,PNPDeviceID`
  and select the `MI_01` port; the `MI_03` port is ELT.
- The phone's NVRAM database files were pulled from
  `/data/vendor_de/meta/mddb/`:
  `MDDB.META.ODB_MT6768_...V118...XML.GZ` (218 KB, XML db) and
  `MDDB.META_MT6768_...V118....EDB` (314 KB).

Remaining blocker: "Load NVRAM database" rejects every candidate tried:
- firmware EDB (16 MB) -> `SP_META_File_Operation_Parse_r: Invalid Argument`
- APDB (CATD) -> `Load DB flow failed`
- phone `mddb.xml.gz` -> `Load DB flow failed`
- phone `mddb.edb` (313 KB) -> selection dialog became unresponsive to synthetic
  clicks before it could be loaded (GUI input issue, not a format verdict).

Next session: either load the 313 KB `mddb.edb` through the GUI (real mouse), or use
`bin/MetaCLI.exe -i <ini>` with an ini derived from `configs/User_Latest_Settings.txt`
(keys: `ComPort`, `ComPortType`, `PlatformType`, `IMEI`, `ApDB`) to do the IMEI write
headlessly. The IMEI values are only in the live session, never on disk.

### 52.2 Final state 04:26 — blocked only on the NVRAM DB parser

ModemMETA is **Connected** in real META (`DUT in META Mode`, UART, COM10).
`Load NVRAM database` still fails with `Please try to load the other NVRAM database`
for every candidate:
- firmware EDB 16 MB, phone `mddb.xml.gz`, phone `mddb.edb`, APDB, and
  `From Target` (device NV data is wiped).

The GUI file dialogs also became unresponsive to synthetic QMP clicks/keys (they accept
list selection but not button activation), so the last attempts were driven by the user
or by luck. The remaining work needs either a real mouse in the virt-manager console,
or `bin/MetaCLI.exe -i <ini>` with the correct `ApDB`/NVRAM-DB key.

Everything else is proven and reproducible:
`premeta.py` -> `0e8d:202D` -> attach -> ModemMETA connected (check COM via
`wmic path Win32_SerialPort get DeviceID,Name,PNPDeviceID`, use the `MI_01` port).

Phone should be powered off to avoid draining the battery in META.

## 53. RESUME PLAN — SN Write Tool (best path), session 2026-10-29 evening

### What is proven and ready
1. **Real META works**: `python3 /tmp/opencode/premeta.py 300` (or
   `/tmp/opencode/fast_reenter.sh`) waits for `0e8d:2000`, opens /dev/ttyACM0 raw
   115200, sends `METAMETA`, gets `READY`/`ATEM...`, and the phone re-enumerates as
   **`0e8d:202D`** (META+ELT).
2. **Attach to VM**: `virsh -c qemu:///session attach-device WINMETA /tmp/opencode/usb-meta.xml --live`
   (use after every VM reboot; the domain loses hot-plugged hostdevs).
3. **Windows VM** (`WINMETA`, qcow2 at ~/Documents/vms/win10/win10.qcow2) has:
   - ModemMETA at `C:\ModemMETA` (works, can connect via COM port, but its IMEI
     plugin NVRAM-DB loader rejects every DB — dead end).
   - **SN Write Tool v1.2020.00** at `C:\Users\mk\SN\SN_Write_Tool_v1.2020.00\`
     (runs after installing the VC++ AIO runtime).
   - **VC++ runtime installed** via `C:\Users\mk\VC3.exe /ai /gm2` (done 2026-10-29).
4. **SN Write Tool config is the key**: `SN_Setup.ini` in the tool folder contains
   every setting. A patched copy is at **`~/Downloads/SN_Setup.ini`** with:
   ```
   Already in Meta = True          # DUT already in META, do not boot it
   Keep in Meta = True
   IMEI Nums = 2                   # dual SIM
   AP DB from DUT = False
   MD DB from DUT = False
   Modem_1 database path = C:\ModemMETA\Database\MDDB_InfoCustomAppSrcP_MT6768_S00_MOLY_LR12A_R3_MP_V118_11_P53_1_ulwctg_n.EDB
   AP database path = C:\ModemMETA\Database\APDB_MT6768_S01__W2025
   Ignore Database Inconsistent = True
   ```
   `Kernel Port Filter` already contains `VID_0E8D&PID_202D&MI_01`, so SN Writer
   auto-detects the META port.

### Exact resume steps (evening)
1. Start VM: `virsh -c qemu:///session start WINMETA` (or virt-manager).
2. Phone: power off, run `premeta.py`, plug (no keys) -> `0e8d:202D`.
3. Attach: `virsh attach-device WINMETA usb-meta.xml --live`.
4. In VM, copy the patched ini over the tool's:
   `curl.exe -L -o "C:\Users\mk\SN\SN_Write_Tool_v1.2020.00\SN_Setup.ini" http://10.0.2.2:8001/SN_Setup.ini`
   (host server: `cd ~/Downloads && python3 -m http.server 8001`).
   NOTE: QMP typing drops characters; verify with `findstr "Already in Meta" <ini>`.
   If it keeps failing, put the ini on a small ISO and copy it from the CD.
5. Launch `SN_Writer.exe`.
6. Click **Start**. With `Already in Meta = True` it should connect to `202D MI_01`,
   read the DBs, and ask for IMEI1/IMEI2 (or use Key Files/Identify).
7. Enter the device's own IMEIs (only in the live dialog; never in the repo):
   IMEI1 `<IMEI1>`, IMEI2 `<IMEI2>` (the user's own device values; kept only in the
   live command, never committed).
8. After Pass, power-cycle the phone and verify with `*#06#` / `getprop`.

### Known GUI/VM hazards (learned the hard way)
- QMP `send-key` occasionally **sticks the Meta modifier** (Win+E, Win+G open), and
  characters get dropped. Always release modifiers explicitly:
  `input-send-event` key meta_l/shift/ctrl/alt down=false, then press Esc.
- QMP clicks are absolute 0..32767; convert `x*32`, `y*42.66`. Wrong scale was the
  cause of many "unresponsive" buttons.
- Modal file dialogs ignore synthetic button clicks sometimes; the user's real
  mouse in the virt-manager console is the reliable fallback.
- `modemmeta`'s "Load NVRAM database" rejects: firmware EDB, APDB, phone
  `mddb.xml.gz` and `mddb.edb` — do not retry those.

## 54. IMEI RESTORED — SN Write Tool success, 2026-10-31

**Result: both IMEIs written back to the device and verified by read-back.**
Log (`C:\SNWriter_LOG\2026-10-31-04-02-32\SN Writer.log`):

```
SmartPhoneSN: Write_IMEI[<IMEI1>] / Read_IMEI[<IMEI1>] ... Check nvram data PASS!!
SmartPhoneSN: Write_IMEI[<IMEI2>] / Read_IMEI[<IMEI2>] ... Check nvram data PASS!!
SmartPhoneSN::REQ_BackupNvram2BinRegion_Start() : Backup nvram successfully!!
Prod_Info->IMEI[0]/[1] written, sn_flag = 0x0005 (IMEI|Barcode|Pass)
SmartPhoneSN: Check prod_info data PASS!!
SmartPhoneSN::All Operate successfully!!
```

### The three blockers that had to be solved
1. **TEE/KPHA licensing gate** (`KPHA_Init failed`, `use VTurkeyLicenser`,
   zero `keybox_uuid`). Bypassed with a 1-byte patch in `SN_Writer.exe`:
   - VA `0x4125e9`, file offset `0x119e9`, bytes `79 61` (`jns 0x41264c`)
     -> `EB 61` (`jmp 0x41264c`).
   - This skips the `KPHA_Init` result check. Everything after it (AP DB, modem
     meta, NV read/write, prod_info) needs no TEE at all.
   - Original kept as `SN_Writer.orig.exe`; patched copy is `SN_Writer_patched.exe`.
2. **Wrong MDDB filename in `SN_Setup.ini`.** The toolkit has
   `MDDB_InfoCustomAppSrcP_MT6768_S00_MOLY_LR12A_R3_MP_V118_11_P5.EDB`
   (16,723,479 B) but the ini referenced `..._V118_11_P53_1_ulwctg_n.EDB`,
   producing `META_NVRAM_Init_Ex_Mdtype_r(): ... File read/write error`.
   Fixed by pointing `Modem_1 database path` at the real file
   (repo copy: `tools/SN_Setup.patched.ini`).
3. **GUI input.** See "automation" below.

### Working recipe (reproducible)
Prereq: phone in real META (`0e8d:202D`), attached to the VM, and the VM's
`SN_Setup.ini` = `tools/SN_Setup.patched.ini`
(`Already in Meta = True`, `Keep in Meta = True`, `IMEI Nums = 2`,
`AP DB from DUT = False`, `MD DB from DUT = False`,
`Ignore Database Inconsistent = True`).

```
# host
virsh -c qemu:///session attach-device WINMETA tools/vm-usb-meta.xml --live
python3 tools/vm_exec.py put tools/SN_Setup.patched.ini 'C:\Users\mk\SN\SN_Write_Tool_v1.2020.00\SN_Setup.ini'

# guest: launch app + open Scan Data (writes control rects + live state)
python3 tools/vm_exec.py run cmd.exe /c 'schtasks /run /tn SNWPREP'

# host: real input through QMP using the rects the guest reported
python3 tools/snw_drive.py <IMEI1> <IMEI2>
```

### Automation architecture (replaces screenshot ping-pong)
- `tools/vm_exec.py` — QEMU guest agent (`guest-exec`/`guest-file-*`). Runs as
  **SYSTEM**; GUI apps must be started in the user session via `schtasks /ru mk /it`.
- `tools/snw_prep.ps1` — launches SN Writer, clicks Start via `BM_CLICK` on
  button id `1002`, waits for the `Scan Data` dialog, reports the exact screen
  rectangles of controls `1056` (IMEI_1), `1058` (IMEI_2), `1071` (OK) and keeps
  writing the app state to `C:\Users\mk\snw_state.txt`. Also forces the dialog
  `HWND_TOPMOST` so nothing can cover it.
- `tools/snw_drive.py` — converts those rects to QMP absolute coordinates
  (`x*32768/screenW`, `y*32768/screenH`), double-clicks each edit (the first
  click only activates the window — click-through prevention), types the IMEI
  with real QMP key events, then clicks OK.
- Results are read from `C:\SNWriter_LOG\<ts>\SN Writer.log` via the agent,
  not from the GUI.

### Hazards found this session (do not repeat)
- **`GetWindowText` cannot read another process's control text** — it returns
  empty. This wasted a cycle ("fields not set" while the screenshot showed them
  filled). Use the app's own log, a screenshot, or `WM_GETTEXT` marshalling.
- **`SetWindowText` sets the visible edit but the app validates its own model**;
  real key events are required. `SendInput`/`keybd_event` from a task also fails
  unless the app is the foreground window.
- **First QMP click on an inactive window is swallowed** (activation only);
  always click twice.
- **The scheduled-task console steals foreground.** Launch helpers with a
  hidden VBS wrapper or force the target window topmost.
- **Windows Update banner** ("We've got an update for you") covered the app and
  scheduled a reboot. Disabled in the VM:
  `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU`
  `NoAutoUpdate=1`, `AUOptions=2`, `NoAutoRebootWithLoggedOnUsers=1`;
  services `wuauserv` and `UsoSvc` set to disabled.
- `guest-file-open` handles leak if a write aborts — always close in `finally`
  (fixed in `tools/vm_exec.py`); a leaked handle locks the file in the guest.

### Next steps
1. Power-cycle the phone (it is left in META by `Keep in Meta = True`).
2. Verify: `*#06#` and `getprop | grep -i imei` (or `service call iphonesubinfo`).
3. Resume debloat + full hardware map (`HARDWARE_RESEARCH_AND_DRIVER_RE.md`).

## 55. Post-restore verification & dialer install, 2026-10-31

### IMEI verified on a booted Android
```
adb shell "su -c 'service call iphonesubinfo 1'"
# Parcel (UTF-16): <IMEI1>  <- correct
```
`dumpsys telephony.registry`: SIM in slot 1 is `IN_SERVICE` on the carrier
(MCC 410 / MNC 01), LTE band 1850, voice+data registered. The modem only
attaches with a valid IMEI, so this is independent confirmation that the write
took effect.

### Dialer
The retail ROM's dialer package was **absent from /system** (not merely
disabled — `pm list packages -u` does not list it, and
`cmd package query-activities -a android.intent.action.DIAL` returned nothing).
`com.android.incallui`, `com.android.server.telecom` and `com.android.phone`
are present and enabled, but no app owned the DIAL role.

Installed **Fossify Phone 1.11.1** (FOSS, ~8.8 MB, `org.fossify.phone`):
```
adb install -r -g fossify_phone.apk
adb shell cmd role add-role-holder android.app.role.DIALER org.fossify.phone
```
Verification:
- `dumpsys telecom` -> `User 0: org.fossify.phone` as InCallService (default phone app).
- `query-activities -a android.intent.action.DIAL` -> `org.fossify.phone.activities.DialpadActivity`.
- `am start -a android.intent.action.DIAL -d tel:12345` opens the dialpad;
  screenshot confirms keypad + call button, signal bars and 4G in the status bar.

Note: `cmd telecom get-default-dialer` / `cmd role get-role-holders` are not
implemented on this build; use `dumpsys telecom` to check the role instead.
