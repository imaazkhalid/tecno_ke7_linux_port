# Hardware matrix — component by component

The single table you need when writing drivers. Every row was confirmed on the
retail ROM (`KE7-H693HJKM-Q-GL-220729V478`) unless marked *unknown*.

**Legend:** ✅ works on mainline · 🚧 partially / driver exists upstream · ⬜ not started · ❓ missing data

---

## Core

| Component | Identity | Bus / pins | Mainline | Next action |
|---|---|---|---|---|
| SoC | MT6768 (Helio G70), `k68v1` | — | ✅ | — |
| CPU | 2× A75 + 6× A55 | — | ✅ | OPP/DVFS tuning |
| GPU | Mali-G52 MC2 `13040000` | — | 🚧 Panfrost | add `mali` node + OPP table |
| IOMMU | M4U `10205000` | — | 🚧 | DT node |
| eMMC | `11230000.mmc` | — | ✅ | — |
| USB | `11200000.usb0` | — | ✅ gadget; host TBD | OTG role switch |
| RTC / PMIC | MT6358 `1000d000` | — | ✅ | — |
| Thermal | MT6358 + zones | — | 🚧 | zone mapping |

## Display

| Item | Value |
|---|---|
| Panel | **Novatek NT36525B**, `nt36525b_hdp_dsi_vdo_txd_boe_ke7` |
| Mode | 720×1640, **DSI burst video**, 4 lanes, 228.5 MHz (`mm_dsi0`) |
| DSI host | `14014000.dsi0`, IRQ events `0x8d/0x8e/0x8f` |
| Reset | **GPIO 45** |
| Bias | **ENP GPIO 153 / ENN GPIO 152** |
| Backlight | **OCP2130** i2c LED driver (`led_mode = 5`), 0–255; PWM fallback `1100e000.disp_pwm` |
| Driver | ✅ `panel-novatek-nt36525b` written + binding + DT node (compiles, DTB builds) |
| Current state | ✅ SimpleFB (bootloader framebuffer); DRM path needs DSI/mmsys bring-up; timings DT-calibratable |

**Missing:** the porch/pixel-clock set (`HSA/HBP/HFP/VSA/VBP/VFP`). It is **not**
in the DTS or the dtbo — it lives in the stock LK panel driver. Options: disassemble
`lk.img` (string at `0x8cd55`), read the DSI timing registers at runtime, or measure.

## Touch

| Item | Value |
|---|---|
| Chip | Novatek NVT-ts (SPI) |
| Bus | **SPI2 CS0** (`spi2@11012000/touch@0`), 13.6 MHz |
| Driver | `NVT-ts` (vendor), mainline `novatek-nvt-ts` + our SPI shim |
| Firmware | `novatek_ts_fw.bin`, `novatek_ts_mp.bin` |
| State | ✅ working (`/dev/input/event3`) |

## Fingerprint (requested)

| Item | Value |
|---|---|
| Vendor / chip | **Sunwave** — HAL strings `ic_8202`, `ic_8231` (SW8202/SW8231 class) |
| Bus | **SPI0 CS0** (`spi0.0`), **8 MHz** (`spi-max-frequency = 0x7a1200`); SPI pins on **GPIO6** (pinctrl) |
| DT | `/odm/fingerprint`, driver compatible **`sunwave-fp`** (fallback `mediatek,mt6753-fingerprint`) |
| IRQ | **EINT GPIO 7** (`gpio7_eint` pinctrl node) |
| Reset | ❓ unknown — ODM DT fragment; **GPIO8 is the working hypothesis** (unclaimed, pull-up, next to EINT7) |
| HAL | `vendor.sw.swfingerprint@1.0`, `swfingerprint.default.so`, `fpsensor_fingerprint.default.so` |
| Char devices | `/dev/sunwave_fp`, `/dev/teei_fp` (Trustonic TEE) |
| **SPI path** | TEE trustlet, but **extractable**: the trustlets ship as plain ARM ELF in `/vendor/thh/ta/`. Sensor driver TA `7778…d4d4b` (`fpsensordriver.c`), core TA `7778…d4dc0` (`fp_tee_spi.c`, imports `ut_pf_spi_send_and_receive`), SPI bit-bang driver TA `93fe…4932` (`spi_gpio_api.c`, `drv_spi_api_transfer`) |
| Kernel ABI seen | `ioctl 0x7302` reset, `0x7305/0x7306` SPI clock on/off, `0x7307/0x7308` power, `0x7309` (`_IOWR('s',9,8)`) IRQ wait, `0x7320`, `0x7330` version |
| State | 🚧 **feasible** — the trustlets are unencrypted ELF, so the register/image protocol can be reversed and reimplemented in libfprint over spidev/gpiod |

**What is needed:** reset GPIO number (extract the ODM DT or the vendor
`spi-sunwave-fp` driver), and the SPI register protocol (reverse the HAL's
`ioctl`/`read`/`write` paths). The TEE path (`/dev/teei_fp`) is opaque; a mainline
driver must talk SPI directly and expose the image to userspace (libfprint).

## Sensors (all via SCP)

| Sensor | Chip | Notes |
|---|---|---|
| Accelerometer | **MEMSIC MXC6655** | revealed by `/dev/sensorlist` |
| Light / Proximity | **Sensortek STK33562** (`stk33562_l`, `stk33562_p`) | |
| Magnetometer (unused?) | **MEMSIC MMC5603** | present in SCP firmware |
| Step counter / tilt / gesture | SCP firmware | no separate chip |

Framework: MTK `m_acc_misc`, `m_als_misc`, `m_ps_misc` char devices + nanohub.
**Mainline path:** either direct i2c drivers (mxc6655, stk33562, mmc5603) or an SCP
driver. i2c addresses must be recovered from the SCP firmware.

## Audio

| Item | Value |
|---|---|
| Codec | MT6358 (`mediatek,mt6358-sound`) |
| AFE | `11220000.mt6768-afe-pcm` |
| Card | `mt6768-mt6358` (already exposed by vendor kernel) |
| Speaker amp | **GPIO 39**, `extamp_mode = 2` |
| Jack | ACCDET (headset + hook) |
| State | ⬜ machine driver + amp node needed |

## I²C map (from the running vendor kernel)

| Bus | Address | Device |
|---|---|---|
| i2c-0 | `0x14` | `cap_touch` |
| i2c-2 | `0x0c` | `camera_main_af` |
| i2c-2 | `0x11` | `ccu_sensor_i2c_2_hw` |
| i2c-2 | `0x18` | `camera_main_three` |
| i2c-2 | `0x1a` | **`camera_main` (S5K3P9SX)** |
| i2c-2 | `0x50` | `camera_main_eeprom` |
| i2c-3 | `0x08` | `nfc` (not fitted) |
| i2c-4 | `0x10` | `camera_main_two` |
| i2c-4 | `0x12` | `ccu_sensor_i2c_4_hw` |
| i2c-4 | `0x2d` | `camera_sub` |
| i2c-4 | `0x52` | `camera_sub_eeprom` |
| i2c-5 | `0x34` | `subpmic_pmu` |
| i2c-5 | `0x4e` | `usb_type_c` |
| i2c-5 | `0x53` | **RT9471 charger (`swchg`)** |
| i2c-6 | `0x3e` | **`i2c_lcd_bias`** (backlight/bias IC) |
| i2c-6 | `0x63` | `strobe_main` (AW36515 flash) |
| i2c-7 | `0x16` | `camera_sub_two` |
| i2c-7 | `0x4b` | `slave_charger` |

## Power / charging

| Item | Value |
|---|---|
| PMIC | MT6358 (regulators, auxadc, RTC) |
| Charger | **Richtek RT9471**, i2c-5 `0x53`, IRQ GPIO 9, LED GPIO 165 |
| Fuel gauge | MTK SW FG (no dedicated IC) |
| State | 🚧 upstream `rt9471` + `mt6358` cover most of it |

## Connectivity

| Item | Value |
|---|---|
| Combo | **MT6631** CONNSYS (`wifi@18000000`, IRQ `0x11D`) |
| Wi-Fi firmware | `WIFI_RAM_CODE_soc1_0_1a_1.bin`, `soc1_0_ram_wifi_1a_1_hdr.bin` |
| BT firmware | `soc1_0_ram_bt_1a_1_hdr.bin`, `BT_FW.cfg` |
| FM firmware | `mt6631_fm_v1_patch.bin`, `mt6631_fm_v1_coeff.bin` |
| Vendor modules | `wlan_drv_gen4m.ko`, `wmt_drv.ko`, `wmt_chrdev_wifi.ko`, `bt_drv.ko`, `gps_drv.ko`, `fmradio_drv.ko` |
| Architecture | **MT6631 is the RF front-end only** — the Wi-Fi MAC/baseband lives in the MT6768 CONNSYS. `mt76` (standalone PCIe/USB/SDIO chips) does **not** apply. |
| State | 🚧 needs a CONNSYS/WMT driver port (vendor `wlan_drv_gen4m` is the reference) |

## Camera

| Item | Value |
|---|---|
| CAMSYS | `1a000000.camsys`, SENINF, CAMSV1–4, CCU |
| **Main sensor** | **Samsung S5K3P9SX** (16 MP), `s5k3p9sx_mipi_raw`, **i2c-2 `0x1a`** — confirmed from the vendor boot log |
| 2nd main | i2c-4 `0x10` (`camera_main_two`) |
| 3rd main | i2c-2 `0x18` (`camera_main_three`) |
| Sub sensor | i2c-4 `0x2d` (`camera_sub`) |
| Sub sensor 2 | i2c-7 `0x16` (`camera_sub_two`) |
| EEPROMs | main `0x50` (i2c-2), sub `0x52` (i2c-4) |
| Flash | **AW36515** at **i2c-6 `0x63`** (`strobe_main`), HWEN GPIO 169 |
| Mainline | ❌ no `s5k3p9` driver; `gc02m1`/`ov02b10` not upstream either (nearest: `ov02a10`, `ov02c10`) |
| State | ⬜ drivers needed; start with the main sensor (16 MP is the one users care about) |

## NFC

| Item | Value |
|---|---|
| Node | `nfc@08` on **i2c-3**, `mediatek,nfc` |
| Pins | reset GPIO 159, IRQ GPIO 9 |
| Chip | **not fitted on this unit** — no NFC feature, no NFC libs, no `dumpsys nfc` service |
| State | ✅ nothing to support (DT node is a leftover) |

## Modem

| Item | Value |
|---|---|
| Link | CCCI / CLDMA, MD `md1img` |
| Driver | [`../cellular-port/`](../cellular-port), ported to 6.18 |
| Blocker | MD EINT clock gating — U-Boot fix built, **not flashed** |
| State | 🚧 |

---

## Data we still need (and how to get it)

| Missing item | How to obtain |
|---|---|
| Panel porches | disassemble LK (`lk.img`) LCM driver, or read DSI timing registers |
| Fingerprint reset GPIO | ODM DT fragment (`/odm` node) or vendor `spi-sunwave-fp` driver |
| Fingerprint protocol | reverse `swfingerprint.default.so` SPI reads/writes |
| Main camera sensor | `kd_imgsensor` table in the vendor kernel / camera HAL logs |
| Sensor i2c addresses | SCP firmware disassembly (`scp.img`), or i2c scan with SCP halted |
| NFC chip | `libnfc-nci` / HAL strings |
| OCP2130 i2c address | i2c scan while display is on, or LK strings |

## Where the raw data lives

The collector writes to `hardware-dump/collect-<timestamp>/` (gitignored):

```
getprop, kernel config, lsmod, module params, clk_summary, pm_genpd,
regulator_summary, pinctrl, gpio, interrupts, iomem, dmesg,
platform/i2c/spi devices, drm, power_supply, thermal, leds,
fdt.dtb + vendor.dts, dtbo, vendor firmware + modules,
dumpsys audio/camera/sensors, lshal, vendor configs
```

Run it yourself:

```bash
ADB=path/to/adb ./tools/collect-device.sh --all
```
