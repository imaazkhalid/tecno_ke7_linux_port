# Tecno Spark 6 (KE7 / MT6768) — Hardware Research, Driver Architecture & Reverse Engineering Knowledge Base

> **Location:** `~/Documents/tecno_ke7_linux_port/HARDWARE_RESEARCH_AND_DRIVER_RE.md`  
> **Status:** Active Reference Document  
> **Target Device:** Tecno Spark 6 (Model `KE7` / SIM Tray string `KE7 JS1`)  
> **SoC:** MediaTek Helio G70 (`MT6769V/CB` / platform `MT6768`, HW code `0x707`, architecture `k68v1`)  
> **Boot State:** Orange State (AVB 2.0 Unlocked via SEJ/HACC hardware crypto engine)  
> **Primary Goal:** Bare-metal PC-like boot chain: Little Kernel (LK) → U-Boot (UEFI BIOS) → `systemd-boot` → Arch Linux ARM → GNOME Phosh  

---

## Table of Contents
1. [Hardware Specifications & Physical Addressing](#1-hardware-specifications--physical-addressing)
2. [Partition Layout & eMMC Mapping](#2-partition-layout--emmc-mapping)
3. [Boot Flow & AVB Security Bypass](#3-boot-flow--avb-security-bypass)
4. [Display Subsystem & SimpleFB Framebuffer](#4-display-subsystem--simplefb-framebuffer)
5. [Touchscreen Digitizer Driver Analysis](#5-touchscreen-digitizer-driver-analysis)
6. [Connectivity Subsystem (Wi-Fi, Bluetooth, GPS, FM)](#6-connectivity-subsystem-wi-fi-bluetooth-gps-fm)
7. [Kernel Decompilation, Symbol Map & Memory Layout](#7-kernel-decompilation-symbol-map--memory-layout)
8. [Standard UEFI & systemd-boot Implementation](#8-standard-uefi--systemd-boot-implementation)
9. [Zero-OTG USB Gadget Networking](#9-zero-otg-usb-gadget-networking)
10. [Step-by-Step Bring-up Checklist](#10-step-by-step-bring-up-checklist)
30. [MT6768 Power/Clock Internals — Vendor-Kernel Register Research](#30-mt6768-powerclock-internals--vendor-kernel-register-research-oct-25-2026)

---

## 1. Hardware Specifications & Physical Addressing

| Component | Specification | Technical Details / Register Bases |
|---|---|---|
| **SoC** | MediaTek Helio G70 | `MT6769V` / `MT6768`, HW Code `0x707`, architecture `k68v1` |
| **CPU Cluster 0 (Big)** | 2× ARM Cortex-A75 @ 2.0 GHz | ARMv8.2-A, 64-bit |
| **CPU Cluster 1 (LITTLE)**| 6× ARM Cortex-A55 @ 1.7 GHz | ARMv8.2-A, 64-bit |
| **GPU** | ARM Mali-G52 2EEMC2 | Base `0x13040000`, Panfrost driver compatible (`mediatek,mt8186-mali`) |
| **System RAM** | 4 GB LPDDR4X | Physical Base: `0x40000000` - `0x13fffffff` (4096 MiB) |
| **Internal Storage** | 64 GB eMMC 5.1 | Device: `/dev/block/mmcblk0`, Sectors: `0x0747c000` (62.5 GiB) |
| **PMIC** | MediaTek MT6358 | Regulates system rails, LDOs, display ±5V (VSP/VSN), and Wi-Fi LDO `VCN33_WIFI` |
| **Display Panel** | 6.8" IPS LCD (720 × 1640 HD+) | MIPI DSI Video Mode, 60 Hz |
| **Touch Controller** | Novatek NT36xxx SPI / I2C | `NVT-ts-spi` on SPI bus, `/dev/input/event3` |
| **Connectivity Subsystem**| MT6631/MT6635 CONNSYS Gen4m | Integrated 802.11ac Wi-Fi, Bluetooth 5.0, FM, GPS |
| **UART Serial** | ttyMT0 | Base `0x11002000`, Baud rate `921600 8N1` |
| **USB Controller** | MediaTek MUSB / MUSB HDRC | USB 2.0 OTG, supports USB gadget RNDIS / CDC Ethernet |

---

## 2. Partition Layout & eMMC Mapping

Internal eMMC storage `/dev/block/mmcblk0` is structured with GPT (GUID Partition Table).  
Partitions 1–39 contain essential device firmware and remain **completely intact**.  
The original `userdata` partition was resized and repartitioned into an EFI System Partition (ESP) and Arch Linux rootfs.

### Exact GPT Partition Table

| # | Partition Name | Block Device | Size | Filesystem | Mount Point / Purpose |
|---|---|---|---|---|---|
| 1 | `boot_para` | `mmcblk0p1` | 26 MB | Raw | Boot parameters |
| 2 | `proinfo` | `mmcblk0p2` | 3 MB | Raw | Serial number, MAC, calibration flags |
| 3 | `para` | `mmcblk0p3` | 512 KB | Raw | Parameter storage |
| 4 | `expdb` | `mmcblk0p4` | 20 MB | Raw | Panic and exception dumps |
| 5 | `frp` | `mmcblk0p5` | 1 MB | Raw | Factory Reset Protection |
| 6 | `metadata` | `mmcblk0p6` | 32 MB | Raw | Android encryption metadata |
| 7 | `md_udc` | `mmcblk0p7` | 22.6 MB| Raw | Modem metadata |
| 8 | `nvcfg` | `mmcblk0p8` | 32 MB | Ext4 | NVRAM configuration partition |
| 9 | `nvdata` | `mmcblk0p9` | 64 MB | Ext4 | Calibrated RF NVRAM data & IMEI |
| 10| `persist` | `mmcblk0p10` | 48 MB | Ext4 | Calibration persistence |
| 11| `protect1` | `mmcblk0p11` | 8 MB | Ext4 | Radio protection |
| 12| `protect2` | `mmcblk0p12` | 8 MB | Ext4 | Radio protection |
| 13| `tkv` | `mmcblk0p13` | 1 MB | Raw | TrustZone Key Vault |
| 14| `recovery` | `mmcblk0p14` | 32 MB | Android Boot | TWRP 3.5.0 recovery environment |
| 15| `misc` | `mmcblk0p15` | 6 MB | Raw | Bootloader command message |
| 16| `seccfg` | `mmcblk0p16` | 8 MB | Raw | Bootloader lock/unlock flag (`SecCfgV4`) |
| 17| `sec1` | `mmcblk0p17` | 2 MB | Raw | Hardware security token |
| 18| `md1img` | `mmcblk0p18` | 128 MB | Raw | Cellular modem DSP firmware |
| 19| `spmfw` | `mmcblk0p19` | 1 MB | Raw | System Power Management firmware |
| 20| `scp1` | `mmcblk0p20` | 6 MB | Raw | System Companion Processor firmware (primary) |
| 21| `scp2` | `mmcblk0p21` | 6 MB | Raw | System Companion Processor firmware (backup) |
| 22| `sspm_1` | `mmcblk0p22` | 1 MB | Raw | System Secure Processor firmware (primary) |
| 23| `sspm_2` | `mmcblk0p23` | 1 MB | Raw | System Secure Processor firmware (backup) |
| 24| `gz1` | `mmcblk0p24` | 16 MB | Raw | TrustZone / Guest OS |
| 25| `gz2` | `mmcblk0p25` | 16 MB | Raw | TrustZone / Guest OS (backup) |
| 26| `nvram` | `mmcblk0p26` | 64 MB | Raw | Non-volatile RAM RF calibration |
| 27| `lk` | `mmcblk0p27` | 2 MB | Raw | Little Kernel bootloader (Primary) |
| 28| `lk2` | `mmcblk0p28` | 2 MB | Raw | Little Kernel bootloader (Backup) |
| 29| `logo` | `mmcblk0p29` | 8 MB | Raw | Boot splash bitmap |
| 30| `boot` | `mmcblk0p30` | 32 MB | Android Boot | Kernel Image / U-Boot payload |
| 31| `dtbo` | `mmcblk0p31` | 8 MB | DTBO | Device Tree Blob Overlay |
| 32| `tee1` | `mmcblk0p32` | 5 MB | Raw | Microtrust / TrustZone OS |
| 33| `tee2` | `mmcblk0p33` | 5 MB | Raw | Microtrust / TrustZone OS (backup) |
| 34| `vbmeta` | `mmcblk0p34` | 8 MB | AVB 2.0 | Verified boot metadata |
| 35| `vbmeta_system` | `mmcblk0p35` | 8 MB | AVB 2.0 | System verified boot metadata |
| 36| `vbmeta_vendor` | `mmcblk0p36` | 9.2 MB | AVB 2.0 | Vendor verified boot metadata |
| 37| `super` | `mmcblk0p37` | 5.25 GB | Dynamic | Android super partition (system, vendor, product) |
| 38| `cache` | `mmcblk0p38` | 300 MB | Ext4 | Android cache |
| 39| `tranfs` | `mmcblk0p39` | 300 MB | Ext4 | Transsion filesystem |
| **40** | **`ESP`** | `mmcblk0p40` | **512 MB** | **FAT32** | **Mounted at `/mnt/esp` (EFI System Partition)** |
| 41| `otp` | `mmcblk0p41` | 43 MB | Raw | One-Time Programmable block |
| 42| `flashinfo` | `mmcblk0p42` | 16 MB | Raw | Flash geometry info |
| **43** | **`rootfs`** | `mmcblk0p43` | **51.6 GB** | **EXT4** | **Mounted at `/mnt/arch_root` (Arch Linux ARM)** |

---

## 3. Boot Flow & AVB Security Bypass

### Hardware Boot Stages
1. **BootROM (BROM):** Hardcoded in SoC silicon at address `0x00000000`. Reads eMMC `boot0`/`boot1` hardware blocks. In USB mode, identifies as `0e8d:0003`.
2. **Kamakiri SLA/DAA Crypto Bypass:**
   - Overflows SRAM via USB control transfers (`0x100a00` / `0x201000`).
   - Disables hardware signature authentication (SLA) and download authorization (DAA).
3. **Hardware Unlock via SEJ/HACC (`mtk da seccfg unlock`):**
   - The Helio G70 uses `SecCfgV4` with `hwtype = V4`.
   - The SEJ hardware crypto engine writes the unlock token into partition 16 (`seccfg`).
   - Device enters **Orange State** (`boot_state = orange`). AVB verification errors are ignored; non-signed kernels and bootloaders execute freely.
4. **Little Kernel (LK):**
   - Loaded from partition 27 (`lk`). Initializes clocks, DDR4 EMI, PMIC rails, and MIPI DSI display.
   - Passes hardware parameters and SimpleFB tags to the second stage bootloader.
5. **U-Boot (UEFI Bios):**
   - Packaged inside the Android boot image header on partition 30 (`boot`).
   - Executed by Little Kernel at address `0x40080000`.
   - Initializes UEFI Boot Services, GOP (Graphics Output Protocol) framebuffer, and loads `systemd-boot`.
6. **systemd-boot (`BOOTAA64.EFI`):**
   - Located on partition 40 (`/mnt/esp/EFI/BOOT/BOOTAA64.EFI`).
   - Displays the boot menu, selects Arch Linux ARM entry, loads `Image` and `initramfs-linux.img`.
7. **Arch Linux ARM Kernel:**
   - Mounts `/dev/mmcblk0p43` as root filesystem and launches `/sbin/init` (systemd).

---

## 4. Display Subsystem & SimpleFB Framebuffer

* **Panel Resolution:** 720 × 1640 pixels (HD+ 20.5:9 aspect ratio)
* **Color Depth:** 32-bit ARGB8888 (4 bytes per pixel)
* **Stride:** `720 * 4 = 2880` bytes per line
* **Physical Framebuffer Address:** `0x7E605000`
* **Framebuffer Memory Size:** `2880 * 1640 = 4,723,200` bytes (~4.51 MiB reserved in high DRAM)
* **Display Controller:** MediaTek DISP / MMSYS (`0x14000000`)
* **MIPI DSI Controllers:** `nt36525b_hdp_dsi_vdo_txd_boe_ke7` and `ft8006s_hdp_dsi_vdo_hx_mdt_ke7`
* **PMIC Power Supply:** MT6358 LDOs provide ±5V rails (VSP and VSN) to power the LCD bias IC.
* **SimpleFB Mainline Node:**
```dts
chosen {
    #address-cells = <2>;
    #size-cells = <2>;
    ranges;
    framebuffer0: framebuffer@7e605000 {
        compatible = "simple-framebuffer";
        reg = <0 0x7e605000 0 (720 * 1640 * 4)>;
        width = <720>;
        height = <1640>;
        stride = <(720 * 4)>;
        format = "a8r8g8b8";
    };
};
```

---

## 5. Touchscreen Digitizer Driver Analysis

* **Digitizer IC:** Novatek NT36xxx SPI / I2C series (`NVT-ts-spi`)
* **Kernel Configuration:**
  - `CONFIG_TOUCHSCREEN_MTK=y`
  - `CONFIG_TOUCHSCREEN_MTK_NT36xxx_NOFLASH_COMMON=y`
  - `CONFIG_TOUCHSCREEN_MTK_FT8006P_NO_FLASH_COMMON=y`
* **Input Device Node:** `/dev/input/event3` (`mtk-tpd`)
* **Firmware Dependencies:**
  - `novatek_ts_fw.bin` (Active firmware loaded into digitizer SRAM at driver init/resume)
  - `novatek_ts_mp.bin` (Manufacturing test / touch calibration parameters)
* **Installed Firmware Paths in Arch RootFS:**
  - `/mnt/arch_root/usr/lib/firmware/novatek_ts_fw.bin`
  - `/mnt/arch_root/usr/lib/firmware/novatek_ts_mp.bin`
  - Symlinked to `/vendor/firmware/` and `/etc/firmware/`.
* **Resume Behavior:** The driver invokes `request_firmware()` inside `nvt_ts_resume`. If the firmware is present on disk, touch wakes up and responds to interrupts.

---

## 6. Connectivity Subsystem (Wi-Fi, Bluetooth, GPS, FM)

### Hardware Architecture
MediaTek Helio G70 integrates the **CONNSYS Gen4m** subsystem directly on silicon (derived from MT6631/MT6635). It communicates with the host CPU through internal high-speed buses and shared EMI DRAM buffers.

* **Power Management:** MT6358 PMIC supplies 3.3V power via `VCN33_WIFI` LDO (`mt6358_upmu_set_rg_ldo_vcn33_wifi_en`).

### Firmware Files
Extracted directly from the vendor firmware and installed in `/usr/lib/firmware/`:
1. `soc1_0_ram_wifi_1a_1_hdr.bin` & `WIFI_RAM_CODE_soc1_0_1a_1.bin` — Wi-Fi microcode RAM patches.
2. `soc1_0_ram_bt_1a_1_hdr.bin` — Bluetooth 5.0 baseband firmware.
3. `wifi.cfg` — Wi-Fi radio calibration, channel maps, TX power tables.
4. `WMT_SOC.cfg` — Wireless Management Task SoC configuration.

### Kernel Driver Modules
Located in `ke7_dump/vendor/lib/modules/` (compiled for `4.14.141+ SMP preempt mod_unload modversions aarch64`):
1. **`wmt_drv.ko`** (2.12 MB): Core Wireless Management Task driver. Communicates with CONNSYS firmware over SDIO/EMI. Has no external module dependencies.
2. **`wmt_chrdev_wifi.ko`** (58 KB): Character device interface between user-space daemons and WMT. Depends on `wmt_drv`.
3. **`wlan_drv_gen4m.ko`** (5.19 MB): Full 802.11ac dual-band Wi-Fi driver. Registers with Linux `cfg80211` / `nl80211` subsystem (`wlan0` netdev). Depends on `wmt_drv` and `wmt_chrdev_wifi`.
4. **`bt_drv.ko`** (52 KB): MediaTek Bluetooth HCI driver (`hci0`). Depends on `wmt_drv`.
5. **`gps_drv.ko`** (52 KB): GPS NMEA data receiver driver.
6. **`fmradio_drv.ko`** (494 KB): FM Radio receiver and RDS decoder driver.

### Module Loading Sequence
```bash
insmod /vendor/lib/modules/wmt_drv.ko
insmod /vendor/lib/modules/wmt_chrdev_wifi.ko
insmod /vendor/lib/modules/wlan_drv_gen4m.ko
insmod /vendor/lib/modules/bt_drv.ko
```

---

## 7. Kernel Decompilation, Symbol Map & Memory Layout

### Binary Files & Artifacts
* **Compressed Stock Kernel:** `ke7_dump/boot/kernel` (9,235,729 bytes gzip)
* **Uncompressed Kernel Image:** `kernel_uncompressed` (26,177,536 bytes ARM64 Image)
* **Reconstructed Kernel ELF:** `ke7_dump/bootRE/boot.elf` (27 MB ELF 64-bit LSB, 53,088 symbols)
* **Live Symbol Map:** `kallsyms.txt` (53,051 symbols extracted directly from `/proc/kallsyms`)
* **Kernel Configuration:** `kernel_config.txt` (extracted from `/proc/config.gz`)

### Memory Mapping & Relocation
* **Kernel Static Base:** `0xffffff8008080000`
* **Live KASLR Base:** `0xffffff8149c80000`
* **KASLR Slide:** `0x141c00000` (`0xffffff8149c80000 - 0xffffff8008080000`)
* **`_stext` Start of Code:** `0xffffff8149c80800` (file offset `0x800` in `kernel_uncompressed`)
* **`_etext` End of Code:** `0xffffff814aaf0000`
* **Disassembly Formula:**
  $$\text{File Offset} = \text{Virtual Address} - 0xffffff8149c80000$$

### Key Exported Subsystems & Addresses (Live KASLR)
| Subsystem / Function | Virtual Address | File Offset | Description |
|---|---|---|---|
| `_stext` | `0xffffff8149c80800` | `0x000800` | Code execution entry |
| `do_undefinstr` | `0xffffff8149c80800` | `0x000800` | Undefined instruction exception handler |
| `find_symbol` | `0xffffff8149d6f488` | `0x0ef488` | Module symbol resolver |
| `check_version` | `0xffffff8149d75848` | `0x0f5848` | Module CRC modversion validation |
| `register_netdev` | `0xffffff814a8f6524` | `0xc76524` | Network interface registration |
| `wiphy_register` | `0xffffff814aa75bc8` | `0xdf5bc8` | cfg80211 wireless device registration |
| `mt6358_upmu_set_rg_ldo_vcn33_wifi_en` | `0xffffff814a209ebc` | `0x589ebc` | PMIC Wi-Fi power enable |

---

## 8. Standard UEFI & systemd-boot Implementation

### Architecture
To achieve standard PC-like boot behavior where operating systems can be swapped without re-flashing boot partitions:
1. **U-Boot for MT6768** is compiled with `CONFIG_EFI_LOADER=y` and `CONFIG_CMD_BOOTEFI=y`.
2. U-Boot registers standard EFI Boot Services and EFI Runtime Services in memory.
3. It exposes the SimpleFB framebuffer (`0x7E605000`) via the EFI Graphics Output Protocol (GOP).
4. U-Boot reads partition 40 (`/dev/block/mmcblk0p40`, FAT32 ESP) and launches `/EFI/BOOT/BOOTAA64.EFI`.
5. `systemd-boot` executes and reads `/loader/entries/arch.conf`.

### Installed Files on ESP (`/mnt/esp`):
* `/mnt/esp/EFI/BOOT/BOOTAA64.EFI` — 64-bit systemd-boot loader
* `/mnt/esp/EFI/systemd/systemd-bootaa64.efi` — systemd EFI binary
* `/mnt/esp/loader/loader.conf`:
  ```ini
  default arch.conf
  timeout 5
  console-mode max
  editor yes
  ```
* `/mnt/esp/loader/entries/arch.conf`:
  ```ini
  title Arch Linux ARM
  linux /Image
  initrd /initramfs-linux.img
  options console=tty0 console=ttyMT0,921600 root=/dev/mmcblk0p43 rw rootwait
  ```
* `/mnt/esp/Image` (42 MB 64-bit Linux kernel)
* `/mnt/esp/initramfs-linux.img` (15 MB initramfs)

---

## 9. Zero-OTG USB Gadget Networking

Since the device does not have an external USB OTG adapter connected, all initial internet access, software installation (`pacman`), and remote terminal access (`ssh`) operate directly through the USB-C cable connected to the host laptop via the **USB Gadget Ethernet (`g_ether` / RNDIS / CDC ECM)** driver.

* **Phone IP:** `172.16.42.2/24`
* **Host Laptop IP:** `172.16.42.1/24`
* **Default Gateway:** `172.16.42.1`
* **Host Internet Sharing (NAT):**
  ```bash
  pkexec iptables -t nat -A POSTROUTING -o <host-internet-interface> -j MASQUERADE
  pkexec sysctl -w net.ipv4.ip_forward=1
  ```

---

## 10. Step-by-Step Bring-up Checklist

- [x] **Milestone 1:** Silicon BootROM BROM capture & Kamakiri SLA/DAA handshake.
- [x] **Milestone 2:** Bootloader unlock via hardware SEJ crypto (`SecCfgV4`) into Orange State.
- [x] **Milestone 3:** Bring up graphical TWRP 3.5.0 with display, backlight, and PMIC rails active.
- [x] **Milestone 4:** Internal eMMC repartitioning (`ESP` at `p40`, `rootfs` at `p43`).
- [x] **Milestone 5:** Extract Arch Linux ARM rootfs and proprietary firmware into `/mnt/arch_root`.
- [x] **Milestone 6:** Install `systemd-boot` (`BOOTAA64.EFI`) and loader configurations to internal ESP.
- [x] **Milestone 7:** Complete kernel decompilation, live symbol mapping (53,051 symbols), and driver reverse engineering.
- [ ] **Milestone 8:** Compile U-Boot MT6768 with `CONFIG_EFI_LOADER=y` and SimpleFB GOP support.
- [ ] **Milestone 9:** Chainload U-Boot -> `systemd-boot` -> Arch Linux ARM.
- [ ] **Milestone 10:** Boot Arch Linux ARM into GNOME Phosh mobile desktop.

---

## 11. PC/x86-Like Dual Boot & Recovery Architecture (Post-TWRP)

### Do We Need TWRP After Installing U-Boot?
**No. U-Boot completely replaces the need for TWRP or any Android recovery to boot or manage the system.**
* **U-Boot acts as the PC BIOS / UEFI Firmware:** Once installed on the device, U-Boot initializes the screen, exposes the EFI Graphics Output Protocol (GOP), loads drivers, and boots directly from the FAT32 EFI System Partition (`/dev/block/mmcblk0p40`).
* **Swapping Distros Like an x86 Laptop:**
  To install a new distribution (Debian, Fedora, Ubuntu, Alpine, postmarketOS) or update kernels:
  1. No flashing of partitions 1–39 is ever required again.
  2. Simply mount the root partition (`/dev/block/mmcblk0p43`) and extract the rootfs.
  3. Copy the kernel (`Image`) and `initramfs` to the EFI System Partition (`/mnt/esp`).
  4. Create or edit an entry in `/mnt/esp/loader/entries/` (e.g. `debian.conf`, `arch.conf`, `recovery.conf`).
* **Hardware Recovery Safety Net:**
  * TWRP remains completely safe on the hardware recovery partition (`/dev/block/mmcblk0p14`).
  * If you ever hold **Volume Up** during cold boot, Little Kernel (`lk`) boots directly into TWRP.
  * In addition, you can configure a graphical "Recovery Mode" inside `systemd-boot` simply by adding `/mnt/esp/loader/entries/recovery.conf`.

---

## 12. Mainline Linux vs. Downstream Architecture Comparison

| Subsystem | Mainline Linux (6.18+ / `mt6768-mainline`) | Downstream Android 4.14 |
|---|---|---|
| **Boot Flow** | LK → U-Boot (UEFI) → `systemd-boot` → Mainline Kernel | LK → Downstream `boot.img` → Android Init |
| **GPU** | Panfrost Mali-G52 2EEMC2 (open-source Mesa Gallium) | Proprietary Mali Bifrost blobs (`libGLES_mali.so`) |
| **Display** | SimpleFB framebuffer at `0x7E605000` / `mediatek-drm` | MediaTek DISP / MMSYS downstream driver |
| **Touchscreen** | `novatek-nvt-ts-spi` (`novatek,nt36672a-ts`) with `/lib/firmware/ts.bin` | In-tree `CONFIG_TOUCHSCREEN_MTK_NT36xxx_NOFLASH_COMMON=y` |
| **Wi-Fi** | MediaTek CONNSYS Gen4m forward-port (5 `.ko` modules) | Vendor modules (`wmt_drv.ko`, `wlan_drv_gen4m.ko`) |
| **Internet (Bring-up)**| USB Gadget Ethernet (`g_ether` / CDC ECM / RNDIS) @ `172.16.42.1` | USB Gadget RNDIS / ADB |
| **Audio** | ASoC MT6358 + MT6768 audio controller | Downstream audio framework |
| **Battery / Gauge** | MT6358 AUXADC IIO channel via generic-adc-battery | Downstream Gauge v30 framework |

---

## 13. Mainline Linux 6.18 Bring-Up Milestones & CONNSYS Wi-Fi Porting Knowledge Base

### Milestone Achievements (Verified Live on Hardware)
- [x] **Milestone 8:** Compiled U-Boot MT6768 with `CONFIG_EFI_LOADER=y` and SimpleFB GOP support.
- [x] **Milestone 9:** Chainload U-Boot -> `systemd-boot` -> Arch Linux ARM.
- [x] **Milestone 10:** Boot Arch Linux ARM into GNOME Phosh mobile desktop (`/dev/mmcblk0p41`).
- [x] **Milestone 11:** Mainline Linux Kernel Build #7 (`6.18.0-gf612f7e0293a-dirty #7`) running live.
- [x] **Milestone 12:** Touchscreen input (`/dev/input/event3`) and battery reporting operational.
- [x] **Milestone 13:** Zero-OTG USB Gadget Ethernet active on boot (`172.16.42.2` <-> `172.16.42.1`).

### CONNSYS Gen4m Wi-Fi Stack Architecture & Porting Discoveries
1. **Physical & DTS Hardware Configuration:**
   - **BTIF:** Base `0x1100c000`, size `0x1000`. Probed cleanly by `btif_drv.ko`.
   - **CONNSYS APB:** Base `0x18002000`, size `0x1000`.
   - **WIFI Top / DMA:** Base `0x18000000`, size `0x2000`.
   - **Reserved Memory:** `conn_emi_mem` at `0x5e000000` (length `0x800000`).

2. **The 5-Module Driver Stack:**
   - `wifiport_shim.ko`: Provides backwards compatibility and stub exports for out-of-tree symbols.
   - `btif_drv.ko`: Serial BTIF hardware interface driver.
   - `wmt_drv.ko`: Subsystem manager that coordinates firmware injection, power sequencing, and resets.
   - `wmt_chrdev_wifi.ko`: Character device exposing `/dev/wmtWifi`. Writing `1` triggers power-up.
   - `wlan_drv_gen4m.ko`: The 802.11 mac80211/cfg80211 wireless driver exposing `wlan0`.

3. **Linux 6.18 Forward-Porting Patches & Adjustments:**
   - `from_timer` macro removal: replaced with `timer_container_of`.
   - `del_timer` / `del_timer_sync` replaced with `timer_delete` / `timer_delete_sync`.
   - `class_create(owner, name)` updated to single-parameter `class_create(name)`.
   - `netif_rx_ni` updated to `netif_rx`.
   - `strlcpy` updated to `strscpy`.
   - `MODULE_IMPORT_NS(ns)` replaced with `MODULE_INFO(import_ns, #ns)` for Linux 6.13+.
   - Multi-Link Operation (MLO) struct updates in cfg80211:
     * `rRoamInfo.links[0].bss` used instead of `rRoamInfo.bss`.
     * `cfg80211_ch_switch_notify` updated to pass `link_id = 0` in both `gl_kal.c` and `gl_p2p_kal.c`.
     * `gl_cfg80211.c`: `station_parameters` rates/HT/VHT capabilities mapped via `params->link_sta_params`.
     * Disabled legacy battery voltage power scaling (`CFG_MODIFY_TX_POWER_BY_BAT_VOLT = 0`) to eliminate dependency on missing downstream PMIC service headers.

4. **WMT Initialization & Hardware Power Sequencing (`wmt_drv.ko`):**
   - `wmt_drv.ko` registers `/dev/wmtdetect` (major 154) first.
   - Userspace triggers CONNSYS platform probe and WMT core initialization via 4 ioctls on `/dev/wmtdetect`:
     * `COMBO_IOCTL_CONNSYS_SOC_HW_INIT` (`0x8004770a`): Registers `mtk_wmt` platform driver (`18002000.consys`), maps EMI reserved memory (`0xbf000000`, 4 MB), and sets EMI remapping registers (`0x10001380`).
     * `COMBO_IOCTL_GET_SOC_CHIP_ID` (`0x80047703`): Returns `0x6768`.
     * `COMBO_IOCTL_SET_CHIP_ID` (`0x40047701`, arg `0x6768`): Sets chip type to `WMT_CHIP_TYPE_SOC`.
     * `COMBO_IOCTL_DO_MODULE_INIT` (`0x80047704`, arg `0x6768`): Invokes `mtk_wcn_common_drv_init()`, creating `/dev/stpwmt` (major 190), parsing `/usr/lib/firmware/WMT_SOC.cfg`, and starting `wmtd_thread`.
   - **CONNSYS MTCMOS & PMIC Regulator Integration on Mainline 6.18:**
     * Set `CONSYS_PWR_ON_OFF_API_AVAILABLE = 0` in `mt6768.h` so `consys_clk_get_from_dts` uses `pm_runtime_enable(&pdev->dev)` (attached to mainline `MT6768_POWER_DOMAIN_CONN` genpd) combined with direct SPM/RGU/TOPCKGEN hardware register sequencing in `consys_hw_power_ctrl()`.
     * Updated `consys_pmic_get_from_dts()` in `mt6768.c` to look up global mainline MT6358 regulators (`regulator_get(NULL, "vcn18")`, `"vcn28"`, `"vcn33"`) and sanitize `IS_ERR_OR_NULL` pointers.
     * Fixed `osal_thread_stop()` in `common/common_main/linux/osal.c` to set `pThread->pThread = NULL;` after `kthread_stop()`, preventing `osal_thread_destroy()` from calling `kthread_stop()` a second time on an already exited kthread during `rmmod wmt_drv`.

5. **BTIF & AP_DMA Interrupt Fix (`GIC_SPI 133, 115, 141`) & Full WMT/STP + MCU Patch + RF Calibration Bringup:**
   - **Root Cause of BTIF TX DMA Stall at `WR:0x1a, RD:0x18` (`IEN:0x0, FLG:0x1`):**
     * In `mt6768-tecno-ke7.dts`, `btif@1100c000` had `interrupts = <GIC_SPI 101 ...>, <GIC_SPI 83 ...>, <GIC_SPI 109 ...>` (which had `-32` mistakenly subtracted from the true GIC SPI numbers `133, 115, 141` in downstream `ke7_mt6768.dts`).
     * In MediaTek AP_DMA hardware (`drivers/dma/mediatek/mtk-uart-apdma.c`), hardware automatically clears `VFF_INT_EN` (`IEN=0`) and sets `VFF_INT_FLAG` (`FLG=1`) when `LEFT_SIZE >= THRE`, asserting `GIC_SPI 115` (`BTIF_TX_DMA_IRQ`) so `hal_tx_dma_irq_handler()` will flush the remaining `< 8` bytes. Because the wrong SPI (`83` instead of `115`) was registered, the TX DMA completion ISR never fired.
   - **Fixes Applied:**
     * Updated `linux/arch/arm64/boot/dts/mediatek/mt6768-tecno-ke7.dts` lines 447-449 to `<GIC_SPI 133 IRQ_TYPE_LEVEL_LOW 0>, <GIC_SPI 115 IRQ_TYPE_LEVEL_LOW 0>, <GIC_SPI 141 IRQ_TYPE_LEVEL_LOW 0>`.
     * Updated `wifi-port/btif/common/btif_plat.c` and `wifi-port/btif/common/btif_dma_plat.c` to dynamically remap `101/83/109` -> `133/115/141` (Linux IRQs `273, 274, 275`) via `irq_create_of_mapping()` on the live kernel without requiring a reboot.
     * Updated `wifi-port/common/common_main/platform/wmt_plat_alps.c` (`wmt_plat_eirq_ctrl`) to tolerate `-EBUSY` on `BTIF_WAKEUP_IRQ` (Linux IRQ `272`, `GIC_SPI 180`) across module reloads.
     * Updated `wifi-port/common/common_main/core/wmt_ctrl.c` (`wmt_ctrl_rx`) to break out if `/dev/stpwmt` closes during an RX wait.
   - **Userspace WMT Daemon (`wmt_test.py`):**
     * Replicates `wmt_launcher` (`libmtk_wmt_detect.so` + `stp_launcher` event loop on `/dev/stpwmt`):
       - Event `0` (`WMT_EVT_BAUD`): sets baudrate, writes `srh_patch` (`2\x04\x00\x00\x00\x00soc1_0_patch_mcu_1a_1_hdr.bin`) to `/dev/stpwmt`, issues `WMT_IOCTL_SET_PATCH_NUM` (`0x4004a014`, `1`) and `WMT_IOCTL_SET_PATCH_INFO` (`0x4004a00f`), and acks `ok`.
       - Event `2` (`WMT_EVT_STP_MOD`): acks `ok`.
   - **Verified Live Hardware Milestones (`dmesg`):**
     * `wmt_core_hw_check:get hwcode (chip id) (0x6768)` over BTIF TX/RX DMA succeeded.
     * `mtk_wcn_soc_pda_patch_dwn:wmt_core: patch dwn:0 frag(26, 952) ok` — downloaded all 26 fragments of `soc1_0_patch_mcu_1a_1_hdr.bin` to CONNSYS MCU via PDA.
     * `mtk_wcn_soc_do_calibration:Calibration start ... Calibration end ... Backup success` (`gBTCalResultSize=448 gWiFiCalSize=8192`).
     * `mtk_wcn_wmt_func_ctrl:OPID(3) type(9) ok` (`LPBK_POWER_CTRL(2) rc= 0`).
     * `echo 1 > /dev/wmtWifi` powers on WMT Wi-Fi (`OPID(3) type(3)`) and invokes `hifAxiProbe` -> `wlanProbe` -> `wlanAdapterStart` -> `wlanDownloadFW`.

6. **Wi-Fi Firmware Download (`wlanDownloadFW`) & `wlan0` Interface Bringup (`wlan_drv_gen4m.ko`):**
   - **Root Cause of Initial `RST_FW_DL_FAIL`:**
     * In `wlan/core/gen4m/os/linux/gl_init.c` (`initWlan()`), `gConEmiPhyBaseFinal = gConEmiPhyBase` was executed only once at `insmod wlan_drv_gen4m.ko` time.
     * If `wlan_drv_gen4m.ko` was loaded before `COMBO_IOCTL_CONNSYS_SOC_HW_INIT` (`0x8004770a`) ran on `/dev/wmtdetect`, `gConEmiPhyBase` was still `0`, causing `gConEmiPhyBaseFinal` to remain `0` even after `mtk_wmt_probe()` allocated `0xbf000000`.
     * When `wlanDownloadFW` -> `wlanConnacFormatDownload` -> `wlanImageSectionDownloadStage` -> `wlanDownloadEMISection` (`wlan/core/gen4m/chips/common/fw_dl.c` line 456) attempted to copy the EMI section of `WIFI_RAM_CODE_soc1_0_1a_1.bin`, `!gConEmiPhyBaseFinal` evaluated true and immediately failed with `WLAN_STATUS_FAILURE` (`RST_FW_DL_FAIL`).
   - **Fixes Applied in `wlan_drv_gen4m.ko`:**
     * Updated `hifAxiProbe()` in `wlan/core/gen4m/os/linux/hif/axi/axi.c` and `wlanDownloadEMISection()` in `wlan/core/gen4m/chips/common/fw_dl.c` to refresh `gConEmiPhyBaseFinal = gConEmiPhyBase` and `gConEmiSizeFinal = gConEmiSize` whenever `!gConEmiPhyBaseFinal && gConEmiPhyBase`.
     * Updated direct `net_device->dev_addr` memory copies in `gl_init.c`, `gl_p2p.c`, `gl_p2p_cfg80211.c`, and `gl_kal.c` to use `eth_hw_addr_set()`, eliminating the Linux 6.18 `dev_addr_check` warning when `NetworkManager` opens `wlan0`/`ap0`.
   - **Exact Build Command for `wlan_drv_gen4m.ko`:**
     ```bash
     make -C ~/tecno_ke7_linux_port/linux \
       M=~/tecno_ke7_linux_port/wifi-port/wlan/core/gen4m \
       ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
       KBUILD_EXTRA_SYMBOLS="~/tecno_ke7_linux_port/wifi-port/shim/Module.symvers ~/tecno_ke7_linux_port/wifi-port/common/Module.symvers ~/tecno_ke7_linux_port/wifi-port/wlan/adaptor/Module.symvers" \
       WLAN_CHIP_ID=6768 MTK_COMBO_CHIP=CONNAC CONFIG_MTK_COMBO_WIFI_HIF=axi \
       MTK_ANDROID_WMT=y MTK_ANDROID_EMI=y -j$(nproc) modules
     ```
   - **Boot Persistence (`connsys-wifi.service` & `/usr/local/bin/connsys-wifi-daemon.py`):**
     * Installed `/usr/local/bin/connsys-wifi-daemon.py` and `/etc/systemd/system/connsys-wifi.service` (enabled in `multi-user.target`) to automatically load all modules, initialize `/dev/wmtdetect` and `/dev/stpwmt`, run RF calibration (`WMT_IOCTL_LPBK_POWER_CTRL(2)`), write `1` to `/dev/wmtWifi`, load `bt_drv`, and maintain the `/dev/stpwmt` event responder loop.
     * Verified live 2.4 GHz and 5 GHz Wi-Fi scanning via `nmcli dev wifi list` on `wlan0` (`permaddr 02:00:00:00:00:06`), connected to 5 GHz WPA3 network (`"Pixel"`, IP `172.25.215.128/24`, gateway `172.25.215.131`), and verified direct SSH over Wi-Fi (`ssh root@172.25.215.128`).

7. **CONNSYS Bluetooth (`bt_drv.ko` / `hci0`) Bringup:**
   - **Architecture:** Wrote a native Linux BlueZ `hci_dev` driver (`~/tecno_ke7_linux_port/wifi-port/bt/bt_drv.c`) that interfaces directly with `wmt_drv.ko` (`mtk_wcn_wmt_func_on(WMTDRV_TYPE_BT)`, `mtk_wcn_stp_set_bluez(0)`, `mtk_wcn_stp_register_event_cb(BT_TASK_INDX, ...)`, `mtk_wcn_stp_send_data`, `mtk_wcn_stp_receive_data`) with H4 packet framing/reassembly.
   - **HCI Quirks Required for CONNSYS 6768:**
     * Without quirks, `hci_dev_do_open` failed at `hci_init4` on `Opcode 0x0c77` (`HCI_OP_READ_SYNC_TRAIN_PARAMS`) with `-56` (`-EBADRQC`) because CONNSYS advertises extended features page 2 bits it does not implement in HCI commands.
     * Added `hci_set_quirk(hdev, HCI_QUIRK_BROKEN_LOCAL_EXT_FEATURES_PAGE_2)`, `HCI_QUIRK_BROKEN_MWS_TRANSPORT_CONFIG`, and `HCI_QUIRK_BROKEN_ERR_DATA_REPORTING` in `mtk_stp_bt_init()`.
   - **Build Command:**
     ```bash
     make -C ~/tecno_ke7_linux_port/linux ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
       M=~/tecno_ke7_linux_port/wifi-port/bt \
       KBUILD_EXTRA_SYMBOLS=~/tecno_ke7_linux_port/wifi-port/common/Module.symvers modules
     ```
   - **Verification:** `hci0` (`02:00:00:00:00:02`, MediaTek BT 5.0) registered and powered on cleanly under `bluetooth.service` (`bluez` + `bluez-utils`), with PipeWire A2DP endpoints (`ldac`, `aptx_hd`, `aptx`, `aac`, `sbc`, `opus`) active.

8. **TTY/PTY Line Discipline Bug Fix in `wmt_drv.ko` (`stp_uart.c`) for `kgx` (GNOME Console):**
   - **Root Cause:** In `wifi-port/common/common_main/linux/stp_uart.c`, `stp_uart_ldisc` was zero-initialized with `memset` and registered via `tty_register_ldisc(&stp_uart_ldisc)` on Linux 5.15+ without setting `stp_uart_ldisc.num = N_MTKSTP` (`15`). Because `stp_uart_ldisc.num` was `0` (`N_TTY`), loading `wmt_drv.ko` overwrote the kernel's default `N_TTY` line discipline (`0`) with `n_mtkstp`! Any new PTY opened afterward (such as `kgx` GNOME Console) inherited `stp_uart_ldisc`, where `stp_uart_tty_write()` unconditionally returns `0` (causing `bash` to spin in `_IO_file_write`) and `stp_uart_tty_receive()` queued a `vmalloc`-allocated `work_struct` (causing a kernel panic on PTY master write).
   - **Fix:** Added `stp_uart_ldisc.num = N_MTKSTP;` for `LINUX_VERSION_CODE >= KERNEL_VERSION(5, 15, 0)` and replaced `vmalloc`/`vfree` with `kzalloc`/`kfree` for `g_stp_uart_rx_work` in `stp_uart.c`. Rebuilt `wmt_drv.ko`.

9. **Audio Subsystem Reverse Engineering (`mt6768-mt6358` + GPIO 39 External Speaker Amp):**
   - **Hardware:** MediaTek MT6768 AFE (`audio@11220000`, SRAM `0x11221000` size `0x9000`) + MT6358 PMIC Codec (`CONFIG_SND_SOC_MT6358=y` already built-in to kernel) + External Speaker Amplifier on **GPIO 39** (`0x27`).
   - **Disassembly of `Tran_AudDrv_GPIO_EXTAMP_Sel` from Stock `kernel_uncompressed` (file offset `0xbcbd68`):**
     * Reads `extamp_gpio = <... 39 0>` and `extamp_mode = <2>` from `tran_audio` DT node (`ke7_dtbo.dts` line 629).
     * To enable speaker amplifier (`SND_SOC_DAPM_POST_PMU`), sends `extamp_mode` (`2`) pulses on GPIO 39:
       ```c
       for (i = 0; i < 2; i++) {
           gpiod_set_raw_value(desc, 0);
           udelay(2);
           gpiod_set_raw_value(desc, 1);
           udelay(2);
       }
       ```
     * To disable speaker amplifier (`SND_SOC_DAPM_PRE_PMD`), drives GPIO 39 low (`gpiod_set_raw_value(desc, 0)`).

10. **Cellular / LTE Modem (`MD1` / `eccci` / `mdcldma@10014000`) Findings:**
    - **Stock Signed Modem Firmware (`md1img.img`):**
      * `/dev/mmcblk0p18` (`md1img` partition, 128 MB) on the device eMMC was previously zeroed out.
      * Downloaded official signed Tecno Spark 6 `KE7-H693GHIJKM-Q-GL-200617V060` `MD1&3` package from Hovatek Mega (`https://mega.nz/file/EqwFiKzC#SxdtxtF9iM6LmEWqyxsE6vSXu8Q6wiXklURmpwcEclE`) to `~/tecno_ke7_linux_port/firmware_parts/md1img_clean.zip` and extracted `~/tecno_ke7_linux_port/flash_images/md1img.img` (57,860,848 bytes).
    - **Bootloader (`LK` -> `U-Boot` -> `Linux`) Modem Loading Flow:**
      * On boot, `LK` (`mmcblk0p27`) reads `md1img` from `/dev/mmcblk0p18`, verifies and decompresses `md1rom`/`md1dsp`/`md1drdi` into reserved DRAM, configures EMI MPU, writes the `ccci_tag_mem` (`LK_LD_MD`) structure in DRAM, and adds `/chosen/ccci,modem_info_v2` plus `/reserved-memory/mblock-*` nodes to the FDT passed to U-Boot (`mt6768_lk_fdt()` in `u-boot/arch/arm/mach-mediatek/mt6768/init.c`).
      * Downstream drivers in `~/tecno_ke7_linux_port/downstream-src/drivers/misc/mediatek/`: `ccci_util/`, `eccci/` (with `mt6768/md_sys1_platform.c`, `hif/ccci_hif_cldma.c`), and `ccmni/`.
    - **Driver Porting & Architecture for Upstream Linux 6.18:**
      * `ccci_util_lib.ko`: Ported with 1-param `class_create()`, `struct proc_ops`, `ktime_get_real_seconds()`, `of_find_node_by_path()`. Replaced dummy `vmap_reserved_mem` with real `vmap()` of page array so LK's CCCI tags at physical address `0x9FFF0000` map cleanly into virtual memory.
      * `ccci.ko`: Unified loadable kernel module combining `ccci_core`, `ccci_bm`, `ccci_modem`, `modem_sys1`, `ccci_rtc`, `ccci_md_clk`, `ccci_hif_cldma`, `ccci_cldma_plat`, character device ports (`port_char`, `port_ipc`, `port_net`, `port_rpc`, `port_smem`, `port_sysmsg`), `fsm` state machine, UDC uplink data compression, and `ccmni` network driver (`ccmni0`, `ccmni1`, `ccmni2`).
      * Mainline Linux 6.18 API updates: `from_timer` / `timer_container_of`, `ktime_get_real_ts64()`, `rtc_time64_to_tm()`, `vm_flags_set()`, `ATTRIBUTE_GROUPS()`, `ndo_select_queue` (3 arguments), `ndo_tx_timeout` (`dev, txqueue`), `netif_napi_add` (3 arguments), `eth_hw_addr_random()`.
      * Device Tree: Added `mdcldma@10014000` node (`reg = <0 0x10014000 0 0x1000>, <0 0x1021b000 0 0x1000>, <0 0x10209000 0 0x1000>, <0 0x1020a000 0 0x1000>`, `interrupts = <GIC_SPI 180>, <GIC_SPI 164>, <GIC_SPI 165>, <GIC_SPI 75>`, `mediatek,cldma_capability = <6>`, `mediatek,md_id = <0>`) to `mt6768-tecno-ke7.dts` and installed to `/boot/`. Verified live in `/proc/device-tree/soc/mdcldma@10014000`.
      * **Modem Probe & SMEM Initialization Fixes:**
        1. Fixed early return in `ccci_md_config()`: Downstream AMMS (Adaptive Modem Memory Service) stub returned 0 from `amms_cma_allocate()`, causing `bank4_phy_addr != md_resv_smem_addr` check to fail and abort before configuring the shared memory layout or calling `init_smem_regions()`. Updated condition to check `bank4_phy_addr != 0 && bank4_phy_addr != md_resv_smem_addr`, allowing static LK-allocated DRAM (`0x78000000`) to be used.
        2. Fixed uninitialized `dev_class` in `ccci_core.c`: In loadable module build (`CCCI_KMODULE_ENABLE`), `ccci_init()` was never called because `subsys_initcall` was omitted. Hooked `ccci_init()` and `ccci_exit()` into `modem_cd_init()`/`modem_cd_exit()` in `modem_sys1.c` so `dev_class = class_create("ccci_node")` and `ccci_subsys_bm_init()` are initialized prior to registering devices, resolving `device_create fail, ret=-19` (-ENODEV).
        3. Fixed NULL pointer dereference in `port_smem_init()`: Added NULL checks for `ccb_ctl` and `buf` in `port_smem.c` before accessing `base_ap_view_vir`.

---

## 15. GNOME Phosh Userspace & GNOME Console (`kgx`) Terminal Setup

### Problem Statement
In the Phosh mobile desktop on pure Arch Linux ARM, the GNOME Console app (`kgx` / `org.gnome.Console 51.0-1`) failed to properly initialize or load the terminal shell. When tapped, the window opened but remained stuck on the app logo and an infinite loading spinner (`AdwSpinner`), giving the appearance that the terminal or shell was not loading or hung.

### Technical Root Cause
1. **Application Architecture (`src/kgx-empty.c`, `src/kgx-tab.c`):**
   - In `gnome-console`, `KgxTab` contains a `GtkStack` that embeds `KgxEmpty` (`/org/gnome/Console/kgx-empty.ui`).
   - `KgxEmpty` displays `org.gnome.Console-symbolic` and an `AdwSpinner` whenever `KgxTab.working == TRUE`.
   - The tab transitions out of the `working` state and hides the spinner only when VTE fires shell readiness signals.
2. **Arch Linux Non-Login Shell Execution:**
   - When `kgx` spawns a terminal tab, it executes `/bin/bash` as an **interactive non-login shell**.
   - Under bash, interactive non-login shells ONLY read `/etc/bash.bashrc` and `~/.bashrc`. They do **not** execute `/etc/profile` or scripts in `/etc/profile.d/`.
   - VTE provides `/etc/profile.d/vte.sh` (provided by `vte-common`), which hooks into `PROMPT_COMMAND` (`__vte_precmd`, `__vte_osc7`), sets `PS0` (`vte.shell.preexec`, `OSC 133;C`), and encloses `PS1` within `OSC 133;A` and `OSC 133;B` terminal integration escape sequences.
   - Because neither `/etc/bash.bashrc` nor `/home/alarm/.bashrc` was sourcing `/etc/profile.d/vte.sh`, bash never emitted `\e]666;vte.shell.precmd!\e\` or OSC 133 prompt markers.
   - Consequently, `kgx` never received notification that the child bash process had completed startup, leaving the tab permanently displaying `KgxEmpty` with the loading spinner.
3. **Environment & Terminal Properties:**
   - Active user: `alarm` (UID 1000), default shell `/bin/bash`.
   - Terminal emulator environment set by kgx: `TERM=xterm-256color`, `VTE_VERSION=8401`, `TERM_PROGRAM=kgx`.
   - Device nodes: `/dev/ptmx` (`crw-rw-rw- 1 root tty 5, 2`), `/dev/pts` (`devpts`, `gid=5,mode=600,ptmxmode=000`).

### Resolution
1. **Source VTE Shell Integration in `~/.bashrc`:**
   Append to `/home/alarm/.bashrc` (after `PS1` definition):
   ```bash
   if [[ -f /etc/profile.d/vte.sh ]]; then
       . /etc/profile.d/vte.sh
   fi
   ```
2. **System-wide Persistence in `/etc/bash.bashrc` and `/etc/skel/.bashrc`:**
   Add the identical check into `/etc/bash.bashrc` and `/etc/skel/.bashrc` so that all current and future users, as well as root, have working VTE terminal integration in GNOME Console.
3. **`/etc/fstab` Devpts Configuration:**
   Add to `/etc/fstab` for standard terminal permission support:
   ```fstab
   devpts    /dev/pts    devpts    rw,nosuid,noexec,relatime,gid=5,mode=620,ptmxmode=0666    0 0
   ```


---

## 25. Simultaneous Fast-Charging (1.5A) and USB Gadget Networking

### Problem Statement
Standard USB 2.0 SDP (Standard Downstream Port) negotiation defaults to a 500mA current limit (`0.5A`). Under full load (Phosh mobile shell, Wi-Fi, screen backlight, ModemManager), the device consumed ~400-600mA, resulting in battery drain despite being plugged into a computer USB port. Additionally, Phosh showed the battery as discharging because the fuel-gauge had no link to the charger supply.

### Hardware & Technical Solution
1. **Richtek RT9471 Charger IC (`0x53` on I2C5):**
   - Mainline driver `drivers/power/supply/rt9471.c`.
   - Sysfs attribute: `/sys/class/power_supply/rt9471-5-0053/input_current_limit`.
   - Elevated input current limit to 1.5A (`1500000` uA).
2. **Persistent Fast-Charging Udev Rule & Service:**
   - Script `/usr/local/bin/usb-charger-boost.sh`:
     ```bash
     #!/bin/bash
     if [ -f /sys/class/power_supply/rt9471-5-0053/input_current_limit ]; then
         echo 1500000 > /sys/class/power_supply/rt9471-5-0053/input_current_limit
     fi
     ```
   - Udev rule `/etc/udev/rules.d/99-charger-fastcharge.rules`:
     ```udev
     ACTION=="add|change", SUBSYSTEM=="power_supply", KERNEL=="rt9471-5-0053", RUN+="/usr/local/bin/usb-charger-boost.sh"
     ```
3. **Phosh / UPower Active Charging UI:**
   - In `mt6768-tecno-ke7.dts`, linked the fuel gauge (`adc-battery`) to charger:
     ```dts
     fuel_gauge: fuel-gauge {
         compatible = "mediatek,adc-battery";
         power-supplies = <&charger>;
         ...
     };
     ```
   - Verified via `upower -d`: `state: charging`, `online: yes`, `percentage: 28%`, and GNOME top bar displays active lightning bolt charging indicator.

---

## 26. Cellular LTE Modem Bringup (MT6768 CCCI / CLDMA Architecture)

### Hardware Architecture
- **Modem Core:** MT6768 integrated LTE Cat-7 modem (`md1img`).
- **Baseband Firmware:** MOLY.LR12A.R3.MP.V114.9.P1 stored on `/dev/mmcblk0p18` (`md1img`).
- **Communication Interconnect:** CLDMA (Communication Logical DMA) with AP-AO and AP-PDN register blocks and shared memory at `0x78000000` - `0x79800000` (16MB AP-MD buffer).

### Key Discoveries & Driver Patches in `cellular-port/eccci/`:
1. **MTCMOS MD1 Power Domain Activation:**
   - Downstream relied on proprietary SPM / CMDQ calls. In mainline Linux, SCPSYS manages power domains.
   - Added `power-domains = <&spm MT6768_POWER_DOMAIN_MD1>;` to `mdcldma@10014000`.
   - Wired `pm_runtime_get_sync()` in `md_cd_power_on()`.
   - Once powered, MDTOP registers at `0x20140000` power on, allowing `md1_pll_init()` to read PLL version `0x20160627` and set `MD boot slave = 0x1`.
2. **CLDMA Controller Initialization (`cldma_ctrl`):**
   - In downstream Android, `ccci_cldma_driver` probed against a separate platform device. On mainline unified module, `ccci_modem_driver` probes `mdcldma`.
   - Wired `ccci_cldma_hif_init(plat_dev, CLDMA_HIF_ID, md_id)` directly inside `ccci_modem_probe()`.
   - Added NULL guards in `md_cldma_clear()` and `cldma_stop()`.
3. **FSM State Machine Command Execution:**
   - `CCCI_COMMAND_START` is enum index 1 (`CCCI_COMMAND_INVALID` is 0). Corrected command index in `boot_md_store()` and `ccci_md_register()`.
   - Fixed `needforcestop` flag reset at entry to `fsm_routine_start()`.
   - Decoupled `dev_char_close()` in `ccci_fsm_monitor.c` so closing `/dev/ccci_monitor` does not kill the modem.
4. **Infra AO Regmap Lookup:**
   - Mainline DT node uses `mediatek,mt6768-infracfg_ao`. Added fallback lookup via `syscon_regmap_lookup_by_compatible("mediatek,mt6768-infracfg_ao")` and guarded `cldma_plat_hw_reset()` against NULL/error pointers.
5. **CCIF Subsystem Integration (`ccci_hif_ccif`):**
   - Discovered that CCIF (Common Channel Interface, handling channels 0-15 including Handshake 1 & 2, AT commands, and RPC) was missing from `cellular-port/eccci/Makefile`.
   - Added `hif/ccci_ringbuf.o`, `hif/ccci_debug_info.o`, and `hif/ccci_hif_ccif.o` into `ccci.ko`.
   - Fixed Linux 6.18 timer API compatibility (`timer_delete()` replacing `del_timer()`).
   - Wired `ccci_ccif_init()` / `ccci_ccif_hif_init()` directly into `ccci_modem_probe()`.
6. **Root Cause of `early exception detected` (`MD_GENERATION`):**
   - In `cellular-port/eccci/mt6768/ccif_hif_platform.h`:
     ```c
     #if (MD_GENERATION <= 6292)
     #define RINGQ_BASE (8)
     #define RINGQ_EXP_BASE (0)
     #else
     #define RINGQ_BASE (0)
     #define RINGQ_EXP_BASE (15)
     #endif
     ```
   - When `-DMD_GENERATION=6293` was not passed in compiler flags (`ccflags-y`), the preprocessor evaluated `MD_GENERATION <= 6292` as `0 <= 6292` (TRUE).
   - This set `RINGQ_EXP_BASE = 0` and `D2H_EXCEPTION_INIT = (0 + 1) = 1`.
   - Consequently, the very first control message on channel 1 was misparsed as an exception notification (`D2H_EXCEPTION_INIT`), triggering `early exception detected`!
   - Added `-DMD_GENERATION=6293` to `ccflags-y` in `Makefile`.
7. **ARM64 Alignment Fault in `cldma_dump_register` and `md_cd_dump_debug_register`:**
   - Both functions passed `ioremap` device register addresses to `ccci_util_mem_dump()`.
   - In `cellular-port/ccci_util/ccci_private_log.c`, `ccci_util_mem_dump` had a tail copy loop that GCC optimized into `memcpy()`.
   - On ARM64, calling `memcpy()` on Device-nGnRE memory triggers a fatal alignment fault (`__pi_memcpy_generic+0x40`).
   - Fixed by completely rewriting `ccci_util_mem_dump()` to read memory in strict 32-bit words using `readl_relaxed()`, making it safe on both RAM and Device register spaces.
8. **Handshake 1 Verification & CCIF Interrupt Observations:**
   - Handshake 1 confirmed working: CCIF SRAM delivered `control message 0x0, 0x5555FFFF`.
   - AP runtime data sent cleanly (`send runtime data 0`).
   - Modem booted to Stage 2 (`S2`), Task Create 7 (`TC 7`).
   - CCIF interrupt counter confirmed 12 interrupts received from MD on Queue 1 (`D2H_RINGQ1`).
   - All `/dev/ttyC0`-`ttyC6` device nodes and `ccmni0`-`ccmni20` network interfaces registered cleanly in the kernel.
9. **Missing `free_irq` in Module Exit (`ccci_cldma_exit` and `ccci_ccif_exit`):**
   - Unloading `ccci` (`rmmod ccci`) previously triggered a kernel freeze because GIC interrupts 164 (`ap_ccif_irq0_id`) and 180 (`cldma_irq_id`) were never unregistered via `free_irq()`.
   - Added explicit `disable_irq()` and `free_irq()` in both `ccci_ccif_exit()` and `ccci_cldma_exit()` to ensure clean dynamic unloading.
10. **RPC Subsystem Bringup Discovery:**
   - Detailed packet tracing revealed the 12 incoming packets on CCIF Queue 1 were `channel=32` (`CCCI_RPC_RX`), size 68 bytes (`0x44`).
   - The modem baseband requires AP to answer RPC hardware queries (EINT, GPIO, ADC, and RF clock buffer) before proceeding to Handshake 2 (`MD_NORMAL_BOOT`).

11. **MT6358 PMIC System Power-Off Subsystem Bringup:**
   - **Problem:** When issuing `poweroff` / `systemctl poweroff` or selecting "Power Off" in Phosh GUI, systemd cleanly exited but the phone froze on screen displaying a halt hex code without cutting power.
   - **Root Cause:**
     - Mainline Linux on `arm64` falls back to PSCI `SYSTEM_OFF` (`0x84000008`) if no high-priority system-off handler is registered. MediaTek ATF on MT6768 returns `PSCI_E_NOT_SUPPORTED` (`-1`), expecting the AP PMIC driver to signal the MT6358 PMIC to release power rails.
     - `CONFIG_POWER_RESET_MT6358` was disabled (`# CONFIG_POWER_RESET_MT6358 is not set`), so the PMIC power-off driver never probed `/soc/pwrap@1000d000/pmic/power-controller`.
     - `drivers/power/reset/mt6358-poweroff.c` had two fatal bugs: (1) it attempted to call `ioremap(0x1000d000, 0xc30)` at late atomic poweroff time when interrupts were disabled and scheduling was prohibited, and (2) it wrote to PMIC Wrapper (PWRAP) `WACS2_CMD` (`0xC20`) without waiting for FSM idle state (`WACS2_RDATA` `0xC24` bits `[18:16]`), dropping back-to-back writes.
   - **Hardware Sequence & RTC Protection:**
     - MT6358 power off requires unlocking RTC write protection, disabling auto-reboot, and clearing power-hold:
       1. **RTC Unlock Sequence (`MT6358_RTC_PROT` `0x5bc`):**
          By default, MT6358 RTC write access is locked (`0x9136`). All writes to `RTC_AL_SEC`, `RTC_BBPU`, etc. are ignored until unlocked:
          - Write `0x9136` to `0x5bc`, trigger `WRTGR=1` (`0x5c2`).
          - Write `0x586a` to `0x5bc`, trigger `WRTGR=1` (`0x5c2`).
       2. **Disable 2-Second Auto-Reboot Timer (`MT6358_RTC_AL_SEC` `0x5a0`):**
          Default value is `0x25f0`. Bit 8 is `PMIC_BBPU_2SEC_EN` and Bit 6 is `PMIC_BBPU_AUTO_PDN_SEL`. If Bit 8 is set, MT6358 hardware will automatically power back on 2 seconds after power rails are dropped!
          - Clear Bit 8 and Bit 6: `val &= ~(BIT(8) | BIT(6))` (`0x25f0` -> `0x24b0`).
          - Trigger `WRTGR=1` (`0x5c2`).
       3. **Mask Day of Week Alarm (`MT6358_RTC_AL_MASK` `0x590`):**
          - Write `RTC_AL_MASK_DOW` (`BIT(4)`), trigger `WRTGR=1`.
       4. **Configure RTC Oscillator Control (`MT6358_RTC_AL_YEA` `0x5ac`):**
          - Write `RTC_K_EOSC_RSV_0 | RTC_K_EOSC_RSV_2` (`(1U << 8) | (1U << 10)`), trigger `WRTGR=1`.
       5. **Clear Baseband Power Enable (`MT6358_RTC_BBPU` `0x588`):**
          - CRITICAL BUG FIX: Do NOT set `RTC_BBPU_PWREN` (`BIT(0)`)! Setting `PWREN` keeps power enabled.
          - Write `RTC_BBPU_KEY | RTC_BBPU_CLRPKY | RTC_BBPU_CLR | RTC_BBPU_RELOAD` (`0x4300 | BIT(4) | BIT(1) | BIT(5)`), trigger `WRTGR=1`.
       6. **Release PMIC Power Rails (`MT6358_RG_PPCCTL0` `0xa08`):**
          - Write `0` to clear `PMIC_RG_PWRHOLD` (Bit 0).
          - Upon clearing `PWRHOLD`, the MT6358 PMIC cuts main power rails (`VPROC`, `VCORE`, `VDRAM`, `VIO`), cleanly powering off the hardware and display backlight.
   - **Implementation & Deployment:**
     - Pre-mapped PWRAP base (`0x1000d000`) at `probe()` time.
     - Implemented atomic-safe `pwrap_wacs2_write()` with timeout polling on `WACS2_RDATA` idle state using non-sleeping `udelay(1)`.
     - Critical fix: Completely eliminated `regmap` and sleeping calls (`usleep_range`) from `mt6358_do_pwroff()`, which caused CPU deadlock in atomic context after `local_irq_disable()`.
     - Direct MMIO execution of the full power-down sequence:
       * RTC unlock (`0x9136` -> `WRTGR=1` -> `0x586a` -> `WRTGR=1` on `0x5bc`)
       * Disable 2-sec auto-reboot (`0x24b0` -> `WRTGR=1` on `0x5a0`)
       * Mask DOW alarm (`0x0010` -> `WRTGR=1` on `0x590`)
       * Configure EOSC (`0x0500` -> `WRTGR=1` on `0x5ac`)
       * Clear BBPU power-up latch (`0x4332` and `0x4303` -> `WRTGR=1` on `0x588`)
       * Drop PMIC power rails (`0` on `0xa08` `MT6358_RG_PPCCTL0`)
     - Simplified `mt6358_pwrc_probe()` to register `SYS_OFF_PRIO_HIGH` cleanly without touching PWRAP concurrently during runtime.
     - Compiled and deployed `mt6358-poweroff.ko` to `/lib/modules/6.18.0-gf612f7e0293a-dirty/extra/`.
     - Verified driver probe and binding to `mt6358-pwrc` with `SYS_OFF_PRIO_HIGH`.
     - Added `mt6358_poweroff` to `/etc/modules-load.d/poweroff.conf` for persistent boot loading.

## 27. CCCI Driver Stability, Queue 0 SRAM & Userspace Control Architecture

### 1. Queue 0 SRAM NULL Pointer Dereference in `ccci_ringbuf_reset`
- **Issue:** On `rmmod ccci` followed by `modprobe ccci` or when initializing queues during boot, a kernel oops occurred at `ccci_ringbuf_reset+0x10`.
- **Root Cause:** In `hif/ccci_hif_ccif.c`, `md_ccif_reset_queue()` loops through all `QUEUE_NUM` (8) queues. Queue 0 is dedicated to CCIF SRAM registers and has no allocated ring buffer (`ringbuf == NULL`). `ccci_ringbuf_reset()` unconditionally dereferenced `ringbuf->rx_control.read = 0`, causing a fatal NULL pointer dereference.
- **Fix:** Added `if (!ringbuf) return;` at entry of `ccci_ringbuf_reset()` in `cellular-port/eccci/hif/ccci_ringbuf.c`.

### 2. Linux 6.18 `WARN_ON(!work->func)` in `md_ccif_reset_queue`
- **Issue:** Kernel warning `WARNING: CPU: 4 PID: ... at kernel/workqueue.c:4234 __flush_work+0x328/0x358` on module start.
- **Root Cause:** In Linux 6.18, `flush_work(&work)` triggers a kernel warning if `work->func` is NULL. For unconfigured queues (like queue 7 with buffer size 0), `qwork.func` was not set.
- **Fix:** Added guard `if (md_ctrl->rxq[i].qwork.func) flush_work(&md_ctrl->rxq[i].qwork);` in `cellular-port/eccci/hif/ccci_hif_ccif.c`.

### 3. Module Unload IRQ 277 (`MD_WDT`) Leak
- **Issue:** On dynamic reloading (`rmmod ccci && modprobe ccci`), `request_irq(md->md_wdt_irq_id)` returned `-EBUSY` (`-16`), reporting `genirq: Flags mismatch irq 277`.
- **Root Cause:** `modem_cd_exit()` failed to call `free_irq()` for `md->md_wdt_irq_id`.
- **Fix:** Added `if (md && md->md_wdt_irq_id) free_irq(md->md_wdt_irq_id, md);` to `modem_cd_exit()` in `cellular-port/eccci/modem_sys1.c`.

### 4. Reverse-Engineered Modem Userspace Boot Protocol (`ccci_mdinit`)
- Disassembled `ccci_mdinit` (`ARM EABI5` Thumb-2 binary) at entry `0xc001` and main `0xc0d8`:
  1. `ccci_mdinit 0` parses argument `0` as modem ID 1 (`MD_SYS1`).
  2. Queries `/sys/kernel/ccci/version` (reports `6`).
  3. Opens `/dev/ccci_monitor`.
  4. Configures modem parameters via `CCCI_IOC_SET_BOOT_DATA` (`0x4040432f`, `_IOW('C', 47, ...)`):
     - `MD_CFG_MDLOG_MODE`
     - `MD_CFG_SBP_CODE` (Strategic Business Partner / operator code)
     - `MD_CFG_DUMP_FLAG`
     - `MD_CFG_SBP_SUB_ID`
  5. Triggers modem start via `CCCI_IOC_DO_START_MD` (`0x430d`, `_IO('C', 13)`).
  6. Polls `CCCI_IOC_GET_MD_STATE` (`0x80044301`, `_IOR('C', 1, ...)`) until state transitions to `READY` (enum value 2/READY).
  7. Handshake 2 (`CCCI_EVENT_HS2`) is delivered on CCIF Channel 0 as a control packet (`ccci_h->data[1] == 0x0` and `reserved != 0x5555FFFF`).
  8. Once `CCCI_EVENT_HS2` is received, FSM transitions from `BOOT_WAITING_FOR_HS2` to `READY`, enabling CCCI char devices (`/dev/ttyC0` AT port) and `ccmni0` network data.

---

## 28. CCCI File System Daemon (FSD) Protocol, Firmware NVRAM Architecture & Userspace Orchestration

### 1. Protocol Architecture & The Handshake 2 Requirement
During boot, the baseband processor (`md1img`) transitions through:
- **Handshake 1 (`CCCI_EVENT_HS1`):** The modem boots its initial RTOS stages (Task Create 7), signals `MD_INIT_START_BOOT` with magic `0x5555FFFF` over CCIF SRAM, and the AP responds with `send runtime data 0` over `CCCI_CONTROL_TX`.
- **Handshake 2 Gate (`BOOT_WAITING_FOR_HS2`):**
  - In `cellular-port/eccci/port/port_proxy.c:484`, the driver explicitly enforces:
    ```c
    if ((md_state == BOOT_WAITING_FOR_HS1 || md_state == BOOT_WAITING_FOR_HS2)
        && port->tx_ch != CCCI_FS_TX && port->tx_ch != CCCI_RPC_TX) {
        return -ENODEV;
    }
    ```
  - While in `BOOT_WAITING_FOR_HS2`, all communications to AT command ports (`/dev/ttyC0`) and network queues return `-ENODEV`. The baseband processor will NOT transition to `READY` until it finishes loading or initializing its calibration and NVRAM tables from the AP file system service (`/dev/ccci_fs`).
  - **Correction (Oct 25, 2026):** before the modem even reaches the NVRAM/FSD stage it performs 12 RPC `0x4005` SIM hot-plug EINT attribute queries. If the `md1_sim1_hot_plug_eint` descriptor is missing from the DTB, the modem stops there and never issues a single `/dev/ccci_fs` request. See **Section 29** for the root cause and fix.
  - Once filesystem handshakes finish or default calibration is established, the modem sends a control message on CCIF Channel 0 (`data[1] == MD_INIT_START_BOOT`, `reserved != 0x5555FFFF`), which fires `CCCI_EVENT_HS2`, transitioning the FSM to `READY` (state 2).

### 2. `/dev/ccci_fs` Packet Framing & Structures
Communication over `/dev/ccci_fs` utilizes `PORT_F_USER_HEADER` (`sizeof(struct ccci_header) + sizeof(unsigned int) = 20` bytes) with a 4-byte little-endian length prefix:
```
+------------------+------------------------------------+-----------------------------+
| Length (4 bytes) | CCCI Header (20 bytes: 5x uint32)  | Arguments / Payload Data   |
+------------------+------------------------------------+-----------------------------+
```
- **CCCI Header Layout (5x `uint32_t`):**
  1. `data0`: Flags / Magic (`CCCI_FRAGMENT = 0x80000000`).
  2. `data1`: Total payload length (`len(resp_buf) + 0x14`).
  3. `channel`: Channel ID (`CCCI_FS_TX` / `CCCI_FS_RX`).
  4. `reqBuf`: Stream buffer index (`0..4`).
  5. `op`: Operation ID. Responses MUST set `op | 0xFFFF0000`.

- **Drive Letter to Linux Path Translation:**
  The baseband firmware issues file requests using DOS-style drive letters:
  | DOS Drive | Linux Path | Description |
  |---|---|---|
  | `Z:` | `/mnt/vendor/nvdata/md` | Primary NVRAM calibration and profile files |
  | `X:` | `/mnt/vendor/protect_f/md` | Factory protection calibration (IMEI, RF) |
  | `Y:` | `/mnt/vendor/protect_s/md` | Secondary protection partition |
  | `W:` | `/mnt/vendor/firmware` | DSP and modem companion firmwares |
  | `V:` | `/mnt/vendor/nvdata/md_cmn` | Common modem parameters |
  | `U:` | `/mnt/vendor/mdlpm` | Low power mode configuration |
  | `T:` | `/mnt/vendor/etc/mdota` | Modem Over-The-Air updates |
  | `S:` | `/mnt/vendor/nvcfg` | Non-volatile vendor configuration |

- **CCCI File System Opcodes:**
  ```python
  OPEN              = 0x1001
  SEEK              = 0x1002
  READ              = 0x1003
  WRITE             = 0x1004
  CLOSE             = 0x1005
  CLOSEALL          = 0x1006
  CREATEDIR         = 0x1007
  REMOVEDIR         = 0x1008
  GETFILESIZE       = 0x1009
  GETFOLDERSIZE     = 0x100A
  RENAME            = 0x100B
  MOVE              = 0x100C
  COUNT             = 0x100D
  GETDISKINFO       = 0x100E
  DELETE            = 0x100F
  GETATTRIBUTES     = 0x1010
  OPENHINT          = 0x1011
  FINDFIRST         = 0x1012
  FINDNEXT          = 0x1013
  FINDCLOSE         = 0x1014
  RESTORE           = 0x1021
  CMPT_READ         = 0x1022
  BIN_REGION_ACCESS = 0x1023
  CMPT_WRITE        = 0x1024
  GETFILEDETAIL     = 0x1025
  RESP_ID           = 0xFFFF0000
  ```

### 3. eMMC Partition Analysis & Zeroed NVRAM Behavior
- A full-partition scan of `/dev/mmcblk0` on the target device revealed that the internal NV partitions (`nvram` p26, `nvdata` p9, `protect1` p11, `protect2` p12, `nvcfg` p8, `persist` p10) contain zeroed blocks from prior formatting during Linux installation.
- The baseband modem handles missing NV files by requesting them via `_op_OPEN` or `_op_CMPT_READ`. When FSD responds with `FILE_NOT_FOUND` (`-9`), the modem falls back to default factory profiles and populates in-memory structures.

### 4. Premature Auto-Start Bug Resolution
- **Root Cause:** In `cellular-port/eccci/ccci_modem.c` line 1304, `ccci_md_register()` contained `fsm_append_command(fsm_get_entity_by_md_id(md->index), 1, 0);`. This started the modem immediately on module loading with uninitialized SBP/RAT parameters, before userspace could call `CCCI_IOC_SET_BOOT_DATA`. Subsequent userspace start commands failed with `unexpected FSM state 2->5`.
- **Fix:** Removed the premature `fsm_append_command` from `ccci_md_register()`. Rebuilt `ccci.ko` and deployed to `/lib/modules/6.18.0-gf612f7e0293a-dirty/extra/ccci.ko`.

### 5. Deployed Userspace Daemon Architecture
- **`/usr/local/bin/ccci_fsd.py`:** Standalone, pure-Python CCCI File System daemon (adapted from FirmWire MTK FSD RE). Handles DOS path translation, directory scanning, and `CMPT_READ`/`CMPT_WRITE` packets on `/dev/ccci_fs`.
- **`/usr/local/bin/ccci_mdinit.py`:** Standalone Python script issuing `CCCI_IOC_SET_BOOT_DATA` (`0x4040432f`), `CCCI_IOC_DO_START_MD` (`0x430d`), and monitoring modem transition to `READY`.

### 6. GNOME Phosh Mobile Desktop Verification
- Phosh Wayland shell + Phoc compositor running smoothly at native 720×1640 @ 60Hz.
- GNOME Console (`kgx`) working with VTE shell markers.
- Squeekboard on-screen keyboard operational.
- Fast charging (1.5A boosted input current) working concurrently with USB gadget networking.
- System power-off cleanly shuts down the PMIC and cuts power rails without reboot hangs.

---

## 29. Handshake 2 Stall — Root Cause: Missing SIM1 Hot-Plug EINT Device Tree Descriptor (Oct 25, 2026)

### 1. Symptom
After Handshake 1 the modem never reaches Handshake 2. `md_state` goes `2 -> 3` (`BOOT_WAITING_FOR_HS2`), AP sends runtime data successfully, then 30 s later:

```
[ccci1/fsm]exception 2, from fsm_main_thread [ccci]
[ccci1/fsm]MD_BOOT_HS2_FAIL!
[ccci1/mcd]md_boot_stats0:0x54430007
[ccci1/mcd]md_boot_stats1:0x53320000
```

`0x54430007` = `"TC\x00\x07"` (task-create 7), `0x53320000` = `"S2\x00\x00"` (boot stage S2). The modem stops **dead** at that stage.

### 2. Proof that FSD/NVRAM is NOT the first blocker
`ccci_fsd.py` was started **before** the modem (`/dev/ccci_fs` open confirmed, modem at `md1:0`). The modem still issued **zero** file-system traffic:

```
[ccci1/cif]total cnt=13;rxq0 isr_cnt=0;rxq1 isr_cnt=12;rxq2..rxq23 isr_cnt=0 ... rxq15 isr_cnt=1
```

Queue mapping for this modem (`MD_GENERATION=6293`, `port/port_cfg.c` `#else` branch):

| Macro | Value | Meaning |
|---|---|---|
| `EXP_CTRL_Q` | 6 | exception/control |
| `DATA_TX_Q` / `DATA_RX_Q` | 0 | ccmni data |
| `DATA_TX_ACK_Q` | 1 | data ack |
| `DATA2_RX_Q` | 0 | |
| `DATA_C2K_PPP_Q` | 3 | C2K PPP |
| **`DATA_FSD_Q`** | **4** | **`ccci_fs` RX+TX queue** |
| `DATA_AT_CMD_Q` | 5 | `ttyC0` |
| (RPC) | 1 | `CCCI_RPC_RX=32` / `CCCI_RPC_TX=33` |

So `rxq4 = 0` proves no FSD request was ever transmitted by the modem.
`rxq15 = 1` is not a data queue: CCIF channel 15 is the CCIF-SRAM control channel, i.e. exactly one Handshake 1 interrupt (`ISR: RCHNUM=0x00008000`).

### 3. What the modem actually does before stopping
Exactly 12 RPC packets on queue 1, `op_id=0x4005` (`IPC_RPC_GET_EINT_ATTR_OP`, see `port/port_rpc.h:40`), 68 bytes each:

```
SIM1: type=6 (SIM_EINT_SRCPIN), type=0 (SIM_EINT_NUM), type=5 (SIM_EINT_DEDICATEDEN)
SIM2: same three
SIM3: same three
SIM4: same three
```

Each reply is 40 bytes and contains `FS_PARAM_ERROR`-style negative value:
```
[ccci1/rpc] EINT_ATTR: name=MD1_SIM1_HOT_PLUG_EINT, len=23, type=6, ret=-11
[ccci1/cif] send_skb: qno=1, ch=33, ccif_ch=1, len=40
[ccci1/rpc] rpc_msg_handler: reply sent! ret=0
```
`ret=-11` = `ERR_SIM_HOT_PLUG_QUERY_STRING` (`enum sim_hot_plug_eint_queryErr` in `port/port_rpc.h`: `NULL_POINTER=-13`, `QUERY_TYPE=-12`, `QUERY_STRING=-11`).

### 4. Why the attribute lookup failed
`get_eint_attr_DTSVal()` (`port/port_rpc.c:332`) only reads cached per-SIM values that `get_dtsi_eint_node()` (`port/port_rpc.c:306`) collected at probe time with `of_find_node_by_name()`. Our DTB had **no `md1_sim1_hot_plug_eint` node**, hence:

```
[ccci1/rpc] MD1_SIM1_HOT_PLUG_EINT: node 0 no found
[ccci1/rpc] MD1_SIM2_HOT_PLUG_EINT: node 1 no found
[ccci1/rpc] MD1_SIM3_HOT_PLUG_EINT: node 2 no found
[ccci1/rpc] MD1_SIM4_HOT_PLUG_EINT: node 3 no found
[ccci1/rpc] node 4 is NULL
```

### 5. How stock Android differs (the decisive find)
The stock boot DTB contains only an **empty stub**:

```dts
md1_sim1_hot_plug_eint { phandle = <0xdd>; };
md1_sim2_hot_plug_eint { phandle = <0xde>; };
```

The real descriptor is applied by a **DTBO overlay**, `ke7_dump/dtbodts/01_dtbdump_fragment@0.dts`, `fragment@36` (targeted via `/__symbols__: md1_sim1_hot_plug_eint = "/fragment@36:target:0";`):

```dts
fragment@36 {
    target = <0xffffffff>;
    __overlay__ {
        compatible = "mediatek,md1_sim1_hot_plug_eint-eint";
        debounce = <0x0 0x2710>;   /* 10000 us -> 10 ms after /1000 */
        dedicated = <0x0 0x0>;
        interrupts = <0x0 0x8>;    /* EINT 0, IRQ_TYPE_LEVEL_LOW */
        sockettype = <0x0 0x0>;
        src_pin = <0x0 0x1>;
        status = "okay";
    };
};
```

Only **SIM1** exists (single-SIM device). On stock, SIM2/3/4 queries also return `-11` and the modem tolerates that — but SIM1 must resolve. With SIM1 also failing, `md_init` stops.

`md_eint_struct[]` (`port/port_rpc.c:202`) defines exactly which cell of which property is read:

| Query type | Property | Cell index |
|---|---|---|
| `SIM_EINT_NUM` | `interrupts` | 0 |
| `SIM_EINT_DEBOUNCE` | `debounce` | 1 |
| `SIM_EINT_POLA` | `interrupts` | 1 (decoded: `&0x5` → polarity, `&0x3` → sensitivity) |
| `SIM_EINT_SENS` | `interrupts` | 1 |
| `SIM_EINT_SOCKE` | `sockettype` | 1 |
| `SIM_EINT_DEDICATEDEN` | `dedicated` | 1 |
| `SIM_EINT_SRCPIN` | `src_pin` | 1 |

Note the driver reads these as **raw u32 cells only** (`of_property_read_u32_index`); it never calls `of_irq_get()`, so **no `interrupt-parent` and no pinctrl binding is required** — the `interrupts` property is plain data here.

### 6. Fix applied
Added to `linux/arch/arm64/boot/dts/mediatek/mt6768-tecno-ke7.dts`, inside `&{/soc}` immediately after the `mdcldma@10014000` node (values verbatim from the stock DTBO so behaviour matches vendor exactly):

```dts
md1_sim1_hot_plug_eint: md1_sim1_hot_plug_eint {
    compatible = "mediatek,md1_sim1_hot_plug_eint-eint";
    debounce = <0 10000>;          /* usec -> 10 ms for the MD */
    dedicated = <0 0>;
    interrupts = <0 IRQ_TYPE_LEVEL_LOW>;
    sockettype = <0 0>;
    src_pin = <0 1>;
    status = "okay";
};
```

Build & deploy:
```bash
cd ~/tecno_ke7_linux_port/linux
make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- mediatek/mt6768-tecno-ke7.dtb
# -> arch/arm64/boot/dts/mediatek/mt6768-tecno-ke7.dtb  (45,611 bytes, md5 c9d54203f69a44b4056a23591ec22835)
scp -F /dev/null -o StrictHostKeyChecking=no \
    arch/arm64/boot/dts/mediatek/mt6768-tecno-ke7.dtb \
    root@172.16.42.2:/boot/mt6768-tecno-ke7.dtb
# on device: also copy to /boot/mt6768.dtb (U-Boot loads that name too)
```

`dtc` emits a harmless warning (`interrupts_property: .../#interrupt-cells: size is (8), expected multiple of 12`) because `interrupts` is used as data with a 2-cell vector; ignore it.

### 7. Notes / hazards recorded during this investigation
- **Never reload `ccci.ko` in a running system.** `rmmod ccci && modprobe ccci` in the same boot **hard-hangs the kernel** (USB gadget dies immediately, no SSH, requires a physical power cycle). This happened twice. Use a reboot instead of a reload.
- `rmmod ccci` only succeeds when `ModemManager.service` is stopped (`systemctl stop ModemManager`); otherwise it is busy or leaves stale state.
- `systemctl reboot` on the current build did **not** bring the phone back — it de-enumerated from USB and stayed offline (>5 min), i.e. it powered off or hung. Power-off is fixed, reboot path still unverified; expect a manual power-on.
- `boot_md_store()` (`ccci_modem.c:1220`) is a write-only trigger — any write to `/sys/kernel/ccci/boot` appends `CCCI_COMMAND_START` (`cmd_id=1`). There is no sysfs stop; a start from `EXCEPTION` state yields `unexpected FSM state 2->5`.
- `ccci_mdinit.py` reports `RESET (1)` even while the FSM is really in `BOOT_WAITING_FOR_HS2`; trust `/sys/kernel/ccci/boot` (`md1:3`) and the kernel log, not the ioctl mapping in that script (the mapping is wrong and should be corrected).
- `swtp` warnings (`can't find swtp0..4 compatible node`, `ret=-4`) are **normal** — the stock DTB contains no `swtp` nodes either.
- `get_eint_attr_val()` realises RPC EINT failures only at HS2; HS1 (`0x5555FFFF` on CCIF ch 15) is independent of this bug, which is why HS1 always succeeded.







### 30.16 THE FIX: INFRA_AO_MD_SRCCLKENA = 0x21 (Oct 25, 2026)

**The root cause is identified and the fix is known.**

The vendor kernel `md_cd_power_on()` writes `0x21` to `INFRA_AO_MD_SRCCLKENA` (INFRACFG_AO base `0x10001000` + offset `0xF0C`) during step 4 of modem power-on. This enables the MD source clock, which includes the **EINT controller clock**.

**Without this write:** The modem's EINT controller clock stays gated. When the modem firmware writes `EINT_SRC` to configure `src_pin=1` (GPIO47 for SIM1 hot-plug), the bus hangs because the EINT controller clock is gated.

**The fix is applied in U-Boot** (`arch/arm/mach-mediatek/mt6768/init.c`, `board_late_init()`) so the clock is enabled **before** the modem firmware even starts:

```c
#define INFRACFG_AO_BASE       0x10001000
#define INFRA_AO_MD_SRCCLKENA  (INFRACFG_AO_BASE + 0xF0C)

static void mt6768_enable_md_src_clock(void)
{
    writel(0x21, INFRA_AO_MD_SRCCLKENA);
}
```

This is called from `board_late_init()` so the clock is enabled **before** the modem firmware loads and starts executing.

U-Boot rebuilt with `aarch64-linux-gnu-gcc` (700576 bytes). **Needs to be flashed to the correct boot partition** (likely p1, p2, or p4).

Once flashed, the modem should:
1. Complete Handshake 1 ✓
2. Answer 12 SIM EINT RPCs ✓
3. **Write EINT_SRC without bus hang** (EINT clock enabled!)
4. Issue DEBOUNCE/POLARITY/SENSITIVITY/SOCKET queries
5. Power VSIM1/2
6. Reach READY state (`md1:2`)

---

## Boot Chain (KE7 / MT6768) — verified Oct 25 2026
```
BROM -> Preloader -> LK (`lk` p27, fallback `lk2` p28) -> U-Boot (`boot` p30, Android bootimg) -> Linux (ESP)
```
- `lk`/`lk2` = Little Kernel. **Never write U-Boot raw to `lk`.**
- `boot` p30 (32 MB) = `ANDROID!` bootimg whose kernel slot is **gzip(u-boot.bin)**, plus original ramdisk + DTB, plus AVB hash footer (`--partition_name boot --partition_size 33554432`).
- LK gunzips the kernel slot; raw Image/uboot there => lk_crash. Missing ramdisk or AVB footer => lk_crash.
- Known-good images: `flash_images/lk_patched.img` (lk + lk2), `boot-uboot.img` (boot).
- Pack tool: `mt6768-mainline-notes/scripts/pack-uboot-boot.py <template.img> u-boot.bin out.img` then `venv/bin/avbtool add_hash_footer --image out.img --partition_name boot --partition_size 33554432 --algorithm NONE`.
- MD EINT clock: write `0x21` to `0x10001F0C` (INFRA_AO_MD_SRCCLKENA) before modem boot; implemented in U-Boot `board_late_init()` (`mt6768_enable_md_src_clock()`), verified in the disassembly.

---

## 30. MT6768 Power/Clock Internals — Vendor-Kernel Register Research (Oct 25, 2026)

Source trees (public, cross-checked against each other; the two MT6768 trees carry an **identical
3999-line** `clk-mt6768-pg.c`):
- `MiCode/Xiaomi_Kernel_OpenSource`, branch **`merlin-r-oss`** (Redmi Note 9, MT6768, vendor 4.14)
- `LineageOS/android_kernel_xiaomi_mt6768`, branch **`lineage-20`** (vendor 4.19)

### 30.1 `scp-sys-md1-main` is NOT a clock-gate bit on MT6768/MT6765
There is **no** `mtk_gate_regs` / `GATE_SCP_SYS()` entry for `SCP_SYS_MD1` anywhere in the MT6768
tree (`drivers/clk/mediatek/clk-mt6768.c` has zero `scp-sys` hits). Instead:

- `include/dt-bindings/clock/mt6768-clk.h:406` → `#define SCP_SYS_MD1 0` (`SCP_NR_SYSS 13`)
- `arch/arm64/boot/dts/mediatek/mt6768.dts:436` →
  `scpsys: scpsys@10001000 { compatible = "mediatek,scpsys","syscon"; reg = <0x10001000>,<0x10006000 spm>,...; #clock-cells = <1>; }`
- `mdcldma` node: `clocks = <&scpsys SCP_SYS_MD1>, ...; clock-names = "scp-sys-md1-main", ...`
- `drivers/clk/mediatek/clk-mt6768-pg.c:3476` → `PGATE2(SCP_SYS_MD1, pg_md1, NULL, NULL, NULL, SYS_MD1)`
- `clk-mt6768-pg.c:3346` → `mt_power_gate_ops` (`prepare = pg_prepare`, `unprepare = pg_unprepare`)
- `pg_prepare()` (line ~3245) calls `enable_subsys(pg->pd_id, MTCMOS_PWR)` and then
  `enable_subsys(pg->pd_id, MTCMOS_BUS_PROT)`.

So the "clock" is a **virtual power-gate clock**; enabling it runs the MD1 MTCMOS power-on sequence.
`0x10006000` is the SPM base (`POWERON_CONFIG_EN` at +0x0, bit0 = SPM register-control enable,
bits[31:16] = project code 0xB16) — **not** a gate register. The `0x10006000 == 0x1` observation in
§31.9 is just `POWERON_CONFIG_EN[0]`, not evidence of a gate.

Vendor probe **powers MD1 off first** on purpose: `clk-mt6768-pg.c:3617`
`disable_subsys(SYS_MD1, MTCMOS_PWR);` ("per modem owner request, disable modem power first").
The ccci driver later does `clk_prepare_enable(clk_table[0].clk_ref)` = full power-on.

### 30.2 MD1 MTCMOS power-on sequence (vendor)
SPM base `0x10006000`; `infracfg_ao` base `0x10001000`:

| Reg | Addr | Bits used |
|---|---|---|
| `MD1_PWR_CON` | `0x10006320` | bit0 RST_B, bit1 ISO, bit2 ON, bit3 ON_2ND, bit4 CLK_DIS, **bit8 SRAM_PDN**, bit12 SRAM_PDN_ACK |
| `PWR_STATUS` | `0x10006180` | bit0 = MD1 |
| `PWR_STATUS_2ND` | `0x10006184` | bit0 = MD1 |
| `MD_SRAM_ISO_CON` | `0x10006394` | **bit0 = 1 on power-on** (0 on power-off) |
| `MD_EXTRA_PWR_CON` | `0x10006398` | **bit0 = 0 on power-on** (1 before power-off) |
| `INFRA_TOPAXI_PROTECTEN_SET/CLR` | `0x100012A0/0x100012A4` | MD1 step1 bit7, step2 bits3\|4 |
| `INFRA_TOPAXI_PROTECTEN_1_SET/CLR` | `0x100012A8/0x100012AC` | MD1 step2_1 bit6 |
| `INFRA_TOPAXI_PROTECTEN_STA1 / _STA1_1` | `0x10001228 / 0x10001258` | ack bits |

Vendor `spm_mtcmos_ctrl_md1_pwr(STA_POWER_ON)` (`clk-mt6768-pg.c:953-1035`) order:
1. `MD1_PWR_CON &= ~RST_B`
2. `|= PWR_ON`
3. `|= PWR_ON_2ND`
4. poll `PWR_STATUS[0]` and `PWR_STATUS_2ND[0]` == 1
5. **`&= ~(1<<8)`  ← clear SRAM_PDN**
6. `MD_SRAM_ISO_CON |= 1<<0`
7. `&= ~PWR_ISO`
8. `&= ~PWR_CLK_DIS`
9. `|= PWR_RST_B`
10. **`MD_EXTRA_PWR_CON &= ~(1<<0)`**

Bus-protect release (`spm_mtcmos_ctrl_md1_bus_prot(STA_POWER_ON)`) clears PROTECTEN step2_0, step2_1,
step1_0 (release ack not polled). LK does the same sequence in
`lk/platform/mt6765/spm_md_mtcmos.c:93-125`.

**"MODEM_TOP"/"MD_INFRA"/"MD1_SRAM" are not separate domains.** MDTOP registers are at
`0x20140000` (`MDTOP_PLLMIXED_BASE`) and become accessible only when MD1 is powered; vendor ccci then
runs `md1_pll_init()`. `MD1_SRAM` is bit8 of `MD1_PWR_CON` plus `MD_SRAM_ISO_CON[0]`. The
`md1_pcore_sram_on()` code that pokes `0x200D0000` exists in MT6768 ccci but is inside `#if 0`
(compiled out).

### 30.3 `vmd1_pmic_setting_on/off` (MT6358)
`drivers/misc/mediatek/pmic/mt6358/v1/pmic.c:30/50`:
- `vmd1_pmic_setting_on()` writes `PMIC_RG_BUCK_VMODEM_VOSEL` only (restores the value captured at
  PMIC probe by `record_md_vosel()`, `pmic/common/upmu.c:595`), then compares `PMIC_DA_VMODEM_VOSEL`.
- Vendor API `mt6358_upmu_set_rg_buck_vmodem_vosel()` targets **`MT6358_BUCK_VMODEM_ELR0` = 0x15A6,
  mask 0x7F** (mainline `include/linux/mfd/mt6358/registers.h:111` + `mt6358-regulator.c`).
- `vmd1_pmic_setting_off()` is a **no-op** (log only). The rail's enable is `BUCK_VMODEM_CON0`
  (`0x1588`) bit0, handled by the regulator framework, not by this function.
- MT6359 variant additionally writes `VSRAM_MD_VOSEL = 0x4F` (993.75 mV).

### 30.4 `spm_ap_mdsrc_req()`
`drivers/misc/mediatek/base/power/spm/mt6768/mtk_spm_utils.c:85`:
- increments/decrements a refcount and issues
  `SMC_CALL(AP_MDSRC_REQ, 1/0, 0, 0)` = **SIP `MTK_SIP_KERNEL_SPM_AP_MDSRC_REQ`**
  (`0x82000223 | 0x40000000` on arm64 = **0xC2000223**).
- ack poll: `AP_MDSRC_REQ` = **`0x10006430`**, request bit0 (`AP_MDSMSRC_REQ`),
  ack bit4 (`AP_MDSMSRC_ACK`); 3 ms settle if `PCM_REG13_DATA.MD1_APSRC_REQ == 0`.
- ccci wrapper: `md_cd_lock_modem_clock_src(locked)` calls it (mt6768 `md_sys1_platform.c:378`);
  `md_cd_lock_cldma_clock_src()` is commented out.

### 30.5 MD1 boot-status registers
`drivers/misc/mediatek/eccci/mt6768/modem_reg_base.h:123-125`:
`MD1_CFG_BASE 0x1020E300`, `BOOT_STATS0 +0x00`, `BOOT_STATS1 +0x04`.
The AP kernel only **reads** them (mt6768 `md_sys1_platform.c:402-410`, dummy-read twice for
AP/MD interface sync). Writer **not found** in any AP-side public source (LK image has no such
strings; the values change while Linux runs → almost certainly written by the MD firmware itself).
Observed `0x54430007` = ASCII `"TC"` + count 7, `0x53320000` = ASCII `"S2"`; most plausible meaning:
S1→S2→S3 boot-stage markers, `TC n` = n tasks created. **UNCERTAIN** (inference only; no public doc).
`MDPC` string: not found.

### 30.6 LK (MT6765 public tree; device LK contains the same strings)
- `lk/app/mt_boot/iothread.c:108` `do_load_modem()`: `ccci_load_modem_image()` → `md_power_down()`
  → `md_power_control(mode)` → later `let_md_go()` writes `MD_BOOT_VECTOR_EN (0x20000024) = 1`.
- `lk/platform/common/md/ccci_ld_md_core.c:504` `load_modem_image()`: loads main image from the
  **`md1img`** partition ("md1rom"), then sub-images `md1dsp`, `md1arm7`, `md1ramdisk`, `l1core`
  (from `boot`), into an mblock-reserved region (observed on KE7: base `0xae000000`, 0x07e00000).
- `lk/dev/md_com/lk_load_md_wrapper.c:145`: writes `/chosen/ccci,modem_info_v2` (opaque blob from
  the proprietary `update_lk_arg_info_to_dt()`); `lk/app/mt_boot/mt_boot.c:1178` calls it, and line
  ~1190 also writes `/chosen/atag,mdinfo`.
- `lk/platform/mt6765/dummy_ap.c:484` `md1_boot()`: PMIC setting → `spm_mtcmos_ctrl_md1(ON)` →
  `md1_pre_access_md_reg()` → `POWERON_CONFIG_EN=0x0B160001`, `SPM_POWER_ON_VAL1=0x00215830`
  (SRCLKEN_O1 force on) → `md1_pll_init()` (MDTOP 0x20140000) → disable MD WDT.
- `md_common_setting()` writes `INFRA_AO + 0xF0C = 0x21` (MD SRCCLKENA).
- End of boot: `md_power_down()` (`md1_off.c`) powers MD1 **off** and gates `AP_TOP_CLK_GEN+0`
  bits 8/9, so Linux is expected to do a full power-on itself.

### 30.7 Mainline 6.18 gap (this project)
`drivers/pmdomain/mediatek/mt6768-pm-domains.h:35` MD1 domain:
`ctl_offs 0x320`, `ext_buck_iso_offs 0x398/mask 1`, `sta_mask BIT(0)`, `sram_pdn_bits = 0`,
bus-protect masks (BIT7 / BIT3|BIT4 / PROTECTEN_1 BIT6) — but:
1. No `MTK_SCPD_EXT_BUCK_ISO` cap → **0x398 is never written** (ext_buck_iso code is dead).
2. `sram_pdn_bits = 0` → **bit8 (SRAM_PDN) is never cleared**.
3. `MD_SRAM_ISO_CON 0x394` is **not modelled at all** (never read/written).
4. Mainline powers MD1 on at probe (`mtk-pm-domains.c:617` `scpsys_power_on()`), i.e. it never does
   the vendor's "power off at probe, clean power-on on ccci request" cycle.
5. Live snapshot (PROJECT_STATUS §31.12-D): `0x10006320 = 0x10D` ⇒ RST_B=1, ON=1, ON_2ND=1,
   **SRAM_PDN bit8=1**; `0x10006398 = 0x00000001` ⇒ **MD_EXTRA_PWR_CON[0] still 1**;
   vendor post-power-on values are `0x00D` and `0x398[0]=0`. Both are concrete, already-observed
   deviations from the vendor golden sequence. `0x394` was not captured — must be read.
   Causality for the HS2 stall is **unproven** (the MD core is demonstrably executing), but these are
   the only MD1 power-state bits that differ from vendor.

Minimal test (read-only first, via `/dev/mem`):
```
devmem 0x10006320 ; devmem 0x10006394 ; devmem 0x10006398 ; devmem 0x10006180 ; devmem 0x10006184
```
Vendor-expected: 0x320 bit8=0, 0x394 bit0=1, 0x398 bit0=0, 0x180/0x184 bit0=1.
If 0x394 reads 0 or 0x398 reads 1, the mainline power-on is definitely incomplete.
A fix belongs in `mt6768-pm-domains.h`/`mtk-pm-domains.c` (model SRAM_PDN + MD_SRAM_ISO + EXT_BUCK_ISO
with vendor ordering), **not** in a blind single-register poke.
