# Tecno Spark 6 (KE7) — Long-Term Linux Porting Guide & Upstream Roadmap (Linux 6.x to Linux 7.x+)

> **Author:** Antigravity AI Engineering & Pairing Assistant  
> **Target Device:** Tecno Spark 6 (`KE7` / `KE7 JS1`)  
> **Platform / SoC:** MediaTek Helio G70 (`MT6769V` / platform `MT6768`, HW Code `0x707`, architecture `k68v1`)  
> **Current Milestone Achieved:** Pure 64-bit Mainline Linux 6.18 with SimpleDRM, Panfrost Mali-G52 GPU, MT6358 PMIC, and eMMC booting into Arch Linux ARM userspace (`/dev/mmcblk0p43`).  
> **Strategic Objective:** Maintain a reliable, fully reproducible pipeline to forward-port future mainline kernel trees (Linux 6.19, 6.20, and Linux 7.x+) to this device with minimal manual intervention.

---

## Table of Contents
1. [Boot Chain Architecture & Contract](#1-boot-chain-architecture--contract)
2. [Hardware Quirks & Critical Fixes](#2-hardware-quirks--critical-fixes)
   - [2.1 Hardware Watchdog Auto-Reboot (TopRGU)](#21-hardware-watchdog-auto-reboot-toprgu)
   - [2.2 PMIC Interrupts & Regulator Cascades (MT6358 MFD)](#22-pmic-interrupts--regulator-cascades-mt6358-mfd)
   - [2.3 eMMC High-Speed Pinmux & Clocks (mtk-sd)](#23-emmc-high-speed-pinmux--clocks-mtk-sd)
   - [2.4 SimpleDRM vs. mediatek-drm Screen Blanking](#24-simpledrm-vs-mediatek-drm-screen-blanking)
   - [2.5 MMSYS Multimedia Sync_State Hang](#25-mmsys-multimedia-sync_state-hang)
3. [Patch Series Repository (Ordered 0001–0009)](#3-patch-series-repository-ordered-00010009)
4. [Device Tree Specification (mt6768-tecno-ke7.dts)](#4-device-tree-specification-mt6768-tecno-ke7dts)
5. [Kernel Configuration Best Practices (.config / tecno_ke7_defconfig)](#5-kernel-configuration-best-practices-config--tecno_ke7_defconfig)
6. [Forward-Porting to Linux 7.x: Step-by-Step Procedure](#6-forward-porting-to-linux-7x-step-by-step-procedure)
7. [Input & Console Strategy (TTY, SSH, On-Screen Keyboard)](#7-input--console-strategy-tty-ssh-on-screen-keyboard)

---

## 1. Boot Chain Architecture & Contract

The boot process follows an open, PC-like boot chain designed to decouple Linux from Android proprietary mechanisms:

```
+-------------------------------------------------------------+
| BootROM (BROM) @ 0x00000000 (Helio G70 silicon)            |
+-------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------+
| Little Kernel (LK) (Partition 27: `lk`, 28: `lk2`)           |
| - Patched to silence Orange State warning                  |
| - Initializes Clocks, EMI DRAM (4 GB), PMIC, MIPI DSI FB    |
| - Exposes SimpleFB framebuffer at 0x7E9F0000 (720x1640)     |
+-------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------+
| U-Boot 2026.01 UEFI BIOS (Partition 30: `boot`)             |
| - Packed inside Android boot.img header with AVB footer     |
| - Reads FAT32 EFI System Partition (p40: mmc 0:28)          |
| - Disarms hardware watchdog via memory write               |
| - Loads /mt6768-tecno-ke7.dtb -> 0x60000000                 |
| - Loads /Image.mainline       -> 0x45000000                 |
| - Executes `booti 0x45000000 - 0x60000000`                  |
+-------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------+
| Mainline Linux 6.x / 7.x Kernel                             |
| - SimpleDRM binds to 0x7E9F0000 (fbcon console active)      |
| - MT6358 PMIC powers CPU, GPU, and eMMC rails               |
| - mtk-sd probes mmc0 -> /dev/mmcblk0                        |
| - Mounts /dev/mmcblk0p43 (Ext4) as root filesystem         |
| - Executes /sbin/init (systemd) -> tty1 login console       |
+-------------------------------------------------------------+
```

---

## 2. Hardware Quirks & Critical Fixes

### 2.1 Hardware Watchdog Auto-Reboot (TopRGU)
* **Problem:** MediaTek's hardware watchdog (`0x10007000`) is armed by LK with a strict 15-second timeout. If the kernel takes more than 15s or does not ping the watchdog immediately, the SoC hard-reboots.
* **Fix:** Prior to calling `booti`, U-Boot disarms the watchdog:
  ```uboot
  mw.l 0x10007000 0x22000000
  ```
  Magic word `0x22000000` clears the watchdog restart key and stops the countdown timer permanently.

### 2.2 PMIC Interrupts & Regulator Cascades (MT6358 MFD)
* **Problem:** The MT6358 PMIC core driver (`drivers/mfd/mt6397-core.c`) requires an interrupt to be registered before calling `devm_mfd_add_devices()`. In upstream Linux, `mt6358.dtsi` does not include an interrupt binding because the GPIO pin is board-dependent. Without this binding:
  - `platform_get_irq(pdev, 0)` returns `-ENXIO`.
  - The driver aborts probe immediately.
  - No PMIC child devices (`mt6358-regulator`, `mt6358-rtc`, `mt6358-keys`) are ever registered.
  - `cpu0` DVFS fails: `-ENODEV: cpu0: failed to get proc regulator`.
  - `panfrost` GPU fails: `_opp_set_regulators: no regulator (mali) found`.
  - `mmc0` eMMC controller hangs in permanent probe-defer waiting for `mt6358_vemc_reg` (`ldo_vemc`).
* **Fix:** In `mt6768-tecno-ke7.dts`, bind the board EINT GPIO 144 to `&pmic`:
  ```dts
  &pmic {
      interrupts-extended = <&pio 144 IRQ_TYPE_LEVEL_HIGH>;
  };
  ```

### 2.3 eMMC High-Speed Pinmux & Clocks (mtk-sd)
* **Problem:** The `mtk-sd.c` driver requires both `default` and `state_uhs` pinctrl states. If either is missing, probe returns `-ENODEV: Cannot find pinctrl`.
* **Fix:** Define both pinmux states under `&pio` and reference both in `&mmc0`:
  ```dts
  &mmc0 {
      status = "okay";
      pinctrl-names = "default", "state_uhs";
      pinctrl-0 = <&mmc0_default_pins>;
      pinctrl-1 = <&mmc0_uhs_pins>;
      vmmc-supply = <&mt6358_vemc_reg>;
      vqmmc-supply = <&mt6358_vio18_reg>;
  };
  ```

### 2.4 SimpleDRM vs. mediatek-drm Screen Blanking
* **Problem:** Upstream `mediatek-drm` lacks complete DSI panel initialization for the NT36672A panel variant on KE7. When `mediatek-drm` attempts to take over from `simpledrm`, the display blanks completely and never turns back on.
* **Fix:**
  - Enable `CONFIG_DRM_SIMPLEDRM=y`.
  - Disable `CONFIG_DRM_MEDIATEK=n` (or compile as module `=m` but leave unprobed).
  - Declare `framebuffer0: framebuffer@7e9f0000` matching LK's allocated display buffer (width=720, height=1640, stride=2944, format="a8r8g8b8").
  - This guarantees rock-solid, persistent screen rendering with 8 Tux penguins and text console.

### 2.5 MMSYS Multimedia Sync_State Hang
* **Problem:** `mt6768.dtsi` enables multimedia blocks (`ovl0`, `ovl_2l0`, `rdma0`, `color0`, `ccorr0`, `aal0`, `gamma0`). If `mediatek-drm` is disabled, the Linux driver core holds `mtk-power-controller` in `sync_state()` pending forever for these unprobed consumers, creating kernel warnings and delay.
* **Fix:** Disable all unused MMSYS nodes in `mt6768-tecno-ke7.dts`:
  ```dts
  &ovl0 { status = "disabled"; };
  &ovl_2l0 { status = "disabled"; };
  &rdma0 { status = "disabled"; };
  &wdma0 { status = "disabled"; };
  &color0 { status = "disabled"; };
  &ccorr0 { status = "disabled"; };
  &aal0 { status = "disabled"; };
  &gamma0 { status = "disabled"; };
  &dither0 { status = "disabled"; };
  &mutex { status = "disabled"; };
  ```

---

## 3. Patch Series Repository (Ordered 0001–0009)

The patch series is stored at `kernel-patches/ke7-mainline/`:

| Patch # | Patch File | Subsystem | Description |
|---|---|---|---|
| **0001** | `0001-iio-adc-mt6359-auxadc-Mask-out-the-data-ready-bit-of.patch` | IIO / ADC | Masks out data ready bit of the IMP channel on MT6358 auxadc. |
| **0002** | `0002-iio-adc-mt6359-auxadc-Take-the-ADC-resolution-into-a.patch` | IIO / ADC | Adjusts scale calculation to match 12-bit MT6358 ADC resolution. |
| **0003** | `0003-iio-adc-mt6359-auxadc-Fix-the-MT6358-VBAT-resistor-r.patch` | IIO / ADC | Fixes resistor divider ratio on the battery voltage sensor channel. |
| **0004** | `0004-power-supply-generic-adc-battery-Do-not-report-charg.patch` | Power / Battery | Prevents reporting phantom charging when unplugged. |
| **0005** | `0005-power-supply-generic-adc-battery-Report-capacity-fro.patch` | Power / Battery | Computes accurate state-of-charge percentage from Open Circuit Voltage (OCV). |
| **0006** | `0006-arm64-dts-mediatek-Add-battery-and-fuel-gauge-to-Xia.patch` | DTS | Standard battery & fuel gauge node reference. |
| **0007** | `0007-mfd-mt6358-Fix-the-AUD-and-MISC-top-level-interrupt-.patch` | MFD / IRQ | Fixes register offset arithmetic for audio & misc PMIC IRQs. |
| **0008** | `0008-mfd-mt6358-Do-not-let-unserviced-interrupts-storm.patch` | MFD / IRQ | Masks unhandled top-level PMIC IRQ events to prevent CPU IRQ storm freeze. |
| **0009** | `0009-arm64-dts-mediatek-Add-Tecno-Spark-6-KE7-board-suppo.patch` | DTS | Full board device tree source and Makefile integration for Tecno KE7. |

---

## 4. Kernel Configuration Best Practices

A clean, reproducible defconfig is saved at `kernel-patches/ke7-mainline/tecno_ke7_defconfig`.

### Essential Configuration Flags
```ini
# Console & Display
CONFIG_VT=y
CONFIG_FRAMEBUFFER_CONSOLE=y
CONFIG_DRM_SIMPLEDRM=y
CONFIG_DRM_PANFROST=y
# CONFIG_DRM_MEDIATEK is not set

# Storage
CONFIG_MMC=y
CONFIG_MMC_BLOCK=y
CONFIG_MMC_MTK=y

# Power & PMIC
CONFIG_MTK_PMIC_WRAP=y
CONFIG_REGULATOR_MT6358=y
CONFIG_MFD_MT6397=y

# USB Gadget (Zero-OTG Host Communications)
CONFIG_USB_GADGET=y
CONFIG_USB_ETH=y
CONFIG_USB_ETH_RNDIS=y
CONFIG_USB_G_SERIAL=y
CONFIG_USB_CONFIGFS=y

# Device Filesystem
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y
```

---

## 5. Forward-Porting to Linux 7.x: Step-by-Step Procedure

When Linux 7.x (or any future kernel release `X.Y`) is released:

1. **Clone the Upstream Tree:**
   ```bash
   git clone --branch v7.0 https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git linux-7.0
   cd linux-7.0
   ```
2. **Apply the KE7 Patch Series:**
   ```bash
   git am ~/tecno_ke7_linux_port/kernel-patches/ke7-mainline/*.patch
   ```
   *(If any conflicts occur, inspect the PMIC IRQ or ADC scale functions; upstream may have merged similar fixes).*
3. **Load the KE7 Defconfig:**
   ```bash
   cp ~/tecno_ke7_linux_port/kernel-patches/ke7-mainline/tecno_ke7_defconfig arch/arm64/configs/tecno_ke7_defconfig
   make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- tecno_ke7_defconfig
   ```
4. **Compile Kernel & Device Tree:**
   ```bash
   make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Image mediatek/mt6768-tecno-ke7.dtb
   ```
5. **Deploy to EFI System Partition:**
   - Mount ESP (`/dev/block/mmcblk0p40 /mnt/esp`).
   - Copy `arch/arm64/boot/Image` -> `/mnt/esp/Image.mainline`.
   - Copy `arch/arm64/boot/dts/mediatek/mt6768-tecno-ke7.dtb` -> `/mnt/esp/mt6768-tecno-ke7.dtb`.
   - Sync and reboot. U-Boot loads the new kernel immediately.

---

## 6. Input & Console Strategy (TTY, SSH, On-Screen Keyboard)

### Why the Device Pauses at `login:`
Stock Arch Linux ARM starts `systemd` and spawns `getty@tty1.service` on the primary console. Because there is no physical keyboard and the Novatek touch driver is not yet active, the console waits for input.

### Recommended Input Methods:

#### Method A: Remote Interactive Shell over USB Cable (Zero-Hardware)
The phone is connected to the laptop via USB and exposes a USB Gadget Ethernet/Serial device.
1. Configure `/mnt/arch_root/etc/systemd/network/20-wired.network` on the phone with static IP `172.16.42.2/24` and enable `systemd-networkd` + `sshd`.
2. Connect from host:
   ```bash
   ssh root@172.16.42.2
   ```
   This gives an immediate root bash shell using your laptop keyboard.

#### Method B: Touchscreen On-Screen Keyboard in TTY
1. Enable `CONFIG_TOUCHSCREEN_NOVATEK_NVT_TS_SPI=y` in the kernel and add the `&spi2` touch node to `mt6768-tecno-ke7.dts`.
2. Install **`osk-sdl`** (On-Screen Keyboard SDL) or launch **GNOME Phosh** with **`squeekboard`**:
   - `osk-sdl` renders directly to the framebuffer (`/dev/fb0` / DRM KMS) and reads touch coordinates from `/dev/input/event*`, injecting virtual keystrokes into `/dev/uinput`.
   - This displays a working graphical on-screen keyboard on the phone display in pure TTY.
