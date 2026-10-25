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
      * **`systemctl reboot` did not bring the phone back** (Oct 25 06:01 attempt): USB device de-enumerated completely and did not re-appear even after 5 min, i.e. the phone ended up off/hung. Needs manual power-on. The PMIC `mt6358-poweroff` work covers power-*off*; reboot path still needs verification.
  12. **NVRAM partitions are entirely erased:** `/dev/mmcblk0p8` (nvcfg), `p9` (nvdata), `p10` (persist), `p11`/`p12` (protect1/2) and `p26` (nvram) read back as **all zero bytes** (verified `tr -d '\000' | wc -c` = 0). The pre-repartition dumps in `~/tecno_ke7_linux_port/backup/` (`nvdata.bin`, `nvcfg.bin`, `persist.bin`, `protect1.bin`, `protect2.bin`, `nvram.bin`) are **also 100% zero**, so the data was already lost before the backup was taken. No ext4 superblock (`0x53EF` at offset 0x438) exists in any of them. Consequences: no RF calibration and no IMEI; a restore will be required before network registration can work.
  13. **Process rules codified in `AGENTS.md` / `GEMINI.md` (Oct 25, 2026):** The project instruction files now contain §1 memory protocol, §2 mandatory working protocol (read-before-acting, write-while-acting, minimum write cadence, what/where to record, commit-as-you-go, secret handling), §4 hard-won operational hazards (no `ccci` reload, `systemctl reboot` needs manual power-on, do not trust `ccci_mdinit.py` state, harmless `swtp`/`dtc` warnings, 3-step device-unreachable triage), §5 the modem bring-up runbook and queue map, and §6 build/deploy conventions. Any future session must follow them without being asked.

### 3.14 Current Blocker (as of this update)
* **Phone is not attached to the laptop's USB.** Host shows no MediaTek device (`0e8d:*`) and no `enp0s20f0u3`, so `172.16.42.2` is unreachable. The EINT fix has **not yet been tested** — it was deployed and the phone booted normally (Phosh up, confirming the DTB is safe), but no modem boot was attempted against the running system.
* Pending on-device actions once USB returns: verify `/sys/firmware/devicetree/base/soc/md1_sim1_hot_plug_eint` exists, deploy the hardened `ccci_fsd.py`, then run the `AGENTS.md` §5 runbook.

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
- [ ] Mount NVRAM partitions and populate them before the modem starts asking for files (`/mnt/vendor/nvdata/md`, `protect_f/md`, `protect_s/md`, `nvcfg`, `nvdata/md_cmn`, `mdlpm`, `etc/mdota`, `firmware`).
- [ ] Recover NVRAM/RF calibration + IMEI (p8-p12, p26 are fully erased; user can supply the device IMEI).
- [ ] Verify SIM detection (Jazz SIM) via AT commands (`AT+CPIN?`, `AT+CSQ`, `AT+COPS?`) and test data connection over `ccmni0`.
- [ ] Bring up Audio (`snd-soc-mt6768-afe` + `mt6768-mt6358` + GPIO 39 2-pulse external speaker amp).
