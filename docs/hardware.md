# Hardware reference

Everything here was measured on a retail **Tecno Spark 6 (KE7)**, `KE7-H693HJKM-Q-GL`,
running the stock Android 10 ROM. Sources: the vendor device tree (decompiled from
`/sys/firmware/fdt`), `/proc/interrupts`, sysfs, HAL dumps and `dmesg`.

Raw dumps: [`reference/hardware-inventory.md`](reference/hardware-inventory.md) and
[`../hardware/dumps/`](../hardware/dumps).

---

## Platform

| Item | Value |
|---|---|
| SoC | MediaTek **MT6768** (Helio G70), HW code `0x707`, platform string `k68v1` |
| CPU | 2× Cortex-A75 + 6× Cortex-A55 (ARMv8.2-A, 64-bit) |
| GPU | **Mali-G52 MC2** at `0x13040000` (Panfrost-compatible) |
| RAM | 4 GB LPDDR4X, physical base `0x40000000` |
| Storage | 64 GB eMMC 5.1 (`11230000.mmc`), 0x0747c000 sectors |
| PMIC | **MT6358** (`1000d000.pwrap`) |
| Charger | **Richtek RT9471** at i2c-5 `0x53` |
| Display | 6.8″ 720×1640, Novatek **NT36525B** DSI |
| Touch | Novatek NVT-ts over SPI @ 13.6 MHz |
| Modem | integrated LTE (MT6768), CCCI/CLDMA |
| Connectivity | MT6631 CONNSYS (Wi-Fi/BT/FM/GNSS) + NFC (PN5xx class) |

---

## Display

| Item | Value |
|---|---|
| LCM string | `nt36525b_hdp_dsi_vdo_txd_boe_ke7` |
| Controller | Novatek **NT36525B** |
| Glass | BOE, module vendor TXD |
| Mode | **DSI BURST video**, 720×1640 @ 60 Hz |
| DSI host | `14014000.dsi0` |
| Burst clock | 228.5 MHz (`mm_dsi0`) |
| Reset | **GPIO 45** |
| Bias enable | **ENP GPIO 153 / ENN GPIO 152** |
| Backlight | **OCP2130** i2c LED driver (`led_mode = 5`), 0–255 |
| PWM (fallback) | `1100e000.disp_pwm` |
| TE | `dsi0_te` (`IRQ 0x8d`) |

Display engine blocks: `disp_ovl0` `1400b000`, `ovl0_2l` `1400c000`, `rdma0`
`1400d000`, `wdma0` `1400e000`, `color0` `1400f000`, `ccorr0` `14010000`, `aal0`
`14011000`, `gamma0` `14012000`, `dither0` `14013000`, `mutex0` `14001000`, `rsz0`
`14015000`.

**Porting note:** the panel is video-mode; mainline `mtk_dsi` supports video mode.
The missing piece is the porch/pixel-clock timing set, which lives inside the LK
panel driver (see [linux-bringup.md](linux-bringup.md#display)).

---

## Touchscreen

| Item | Value |
|---|---|
| Controller | Novatek **NVT-ts-spi** (fallback compatible `focaltech,fts`) |
| Bus | SPI, 13.6 MHz (`spi-max-frequency = 0xCF8500`) |
| Node | `touch@0`, swrst `0x3F0FE`, fast-read `0x3F310` |
| MP criteria | `novatek-mp-criteria-6232` |
| Input device | `/dev/input/event3`, name `mtk-tpd`, multi-touch |

Mainline `novatek-nvt-ts` is i2c-only; the SPI transport is a small addition, the
protocol is identical.

---

## Keys, headset and haptics

| Item | Value |
|---|---|
| Keypad | `mtk-kpd` at `10010000.kp`, input `event1` (power, vol+/vol−) |
| Soft keys | `sf-keys`, input `event2` |
| Headset | **ACCDET**, input `event0`, `SW=d4` (jack + hook + mic) |
| Vibrator | `mediatek,vibrator`, `/sys/class/leds/vibrator` (0–255) |
| Notification LED | `/sys/class/leds/blue` (0–255) |

---

## Power, charger and battery

| Item | Value |
|---|---|
| PMIC | MT6358: regulators, auxadc, RTC, thermal |
| Charger | **RT9471** switch charger, i2c-5 `0x53`, IRQ GPIO 9, `led_ctl` GPIO 165 |
| Charger IRQs | wdt, chg_mivr, vac_ov, otg_fault, chg_rdy, chg_done, aicc_done, pe_done, chg_tout, ieoc, rechg, chg_batov |
| Supplies | `ac`, `usb`, `charger`, `battery` |
| Fuel gauge | MTK SW FG (no dedicated gauge IC) |
| Cell | Li-ion, 4.2 V, vendor-rated 5000 mAh |
| Suspend | `freeze mem` |
| Wakeup sources | `event0` (headset), `event1` (keypad), `event3` (touch), charger IRQ |

**Known calibration issue:** after the NVRAM wipe the learned `charge_full` reports
**2946 mAh** instead of the rated 5000 mAh. This is a lost battery profile, not wear.
On Linux the same gauge will mis-report until a battery profile is supplied.

Measured fast-charge: **1.5 A** while USB gadget data is active (RT9471
`input_current_limit`). See [linux-bringup.md](linux-bringup.md#charging).

---

## Audio

| Item | Value |
|---|---|
| Codec | MT6358 (`mediatek,mt6358-sound`) |
| AFE | `11220000.mt6768-afe-pcm`, SRAM `11221000` |
| Sound card | `mediatek,mt6768-mt6358-sound` |
| **Speaker amp** | **GPIO 39**, `extamp_mode = 2` (Transsion custom node) |
| Jack | ACCDET (headset detect + hook) |

Without GPIO 39 the loudspeaker stays silent (earpiece only). Quick test on a
booted system: drive GPIO 39 high and play audio.

---

## Camera

| Item | Value |
|---|---|
| CAMSYS | `1a000000.camsys`, SMI LARB3 `1a002000` |
| Sensor IF | `cam1` `1a003000`, `cam2` `1a004000`, `camsv1..4`, `ccu` |
| Sub-sensors (DT) | **GC02M1** (2 MP macro), **OV02B10** (2 MP depth) |
| Main sensor | not in DT — only in MTK's `kd_imgsensor` runtime table |
| Flash | **AW36515** i2c flash driver, HWEN GPIO 169 |

Both sub-sensors have mainline drivers; the main sensor must be identified from
`hardware/dumps/camera.txt`.

---

## Sensors (behind the SCP)

All sensors report vendor `"MTK"` and are proxied by the **SCP**
(`10500000.scp`, `10001000.scpsys`): accelerometer, light, proximity, step
counter/detector, tilt, wake gesture, stationary/motion detect.

Their i2c addresses live in the **SCP firmware**, not the AP device tree. Direct
mainline drivers require finding the chips first (i2c scan with the SCP halted, or
extracting the SCP firmware).

**Not present:** gyroscope, magnetometer, barometer, hall sensor, IR blaster, SAR.

---

## Connectivity

| Item | Value |
|---|---|
| Wi-Fi | `wifi@18000000`, IRQ `0x11D`, MT6631-class CONNSYS |
| Bluetooth | MTK BTIF, `/dev/stpbt*` |
| GNSS | MTK (`mtk_agpsd`, `lppe`) |
| FM | `com.transsion.fmradio`, same CONNSYS |
| NFC | `nfc@08` on i2c-3, `gpio-rst` 159, IRQ GPIO 9 |

---

## Buses

**I2C** controllers at `11007000`, `11008000`, `11009000`, `1100f000`, `11011000`,
`11016000`, `1100d000`, `11004000`, `11005000`.

| Bus | Devices |
|---|---|
| i2c-0 | `0x14` |
| i2c-2 | `0x0c, 0x11, 0x18, 0x1a, 0x50, 0x60` |
| i2c-3 | `0x08` (NFC) |
| i2c-4 | `0x10, 0x12, 0x2d, 0x52` |
| i2c-5 | `0x34, 0x4e, **0x53 (RT9471)**` |
| i2c-6 | `0x3e, 0x63` |
| i2c-7 | `0x16, 0x4b` |
| i2c-1, i2c-8 | unpopulated at AP level (backlight may live here) |

**SPI** controllers at `1100a000`, `11010000`, `11012000`, `11013000`, `11014000`,
`11015000` — touch and fingerprint.

---

## Storage, USB, multimedia

| Block | Address |
|---|---|
| eMMC | `11230000.mmc` |
| USB 2.0 | `11200000.usb0`, `11210000.usb1p_sif` |
| IOMMU (M4U) | `10205000.m4u` |
| Video decode | `16000000.vdec_gcon` |
| Video encode | `17000000.venc_gcon` |
| Audio | `11220000.audio` |

---

## Thermal zones

`mtktscpu`, `mtktsAP`, `mtktsbattery`, `battery`, `mtktspmic`, `mtktscharger`,
`mtktspa`, `mtktswmt`, `mtktsdctm`, `mtktsbtsmdpa`, `mt6358tsbuck1..3`, `tzimgs0..6`.

Typical idle/charging values: CPU 61 °C, PMIC 34 °C, battery 27 °C. Several zones
report `-127 °C` (unavailable) — normal on this board.

---

## Partition layout

The full GPT is in [`../hardware/gpt_table.txt`](../hardware/gpt_table.txt). Key
entries:

| Partition | Offset | Size | Role after the port |
|---|---|---|---|
| `boot_para` | `0x8000` | 26 MB | bootloader scratch (untouched) |
| `nvdata` | `0x08922000` | 64 MB | modem NVRAM filesystem |
| `nvram` | `0x1e900000` | 64 MB | RF calibration / IMEI |
| `lk` / `lk2` | `0x22900000` | 2 MB each | Little Kernel (stock) |
| `boot` | `0x23500000` | 32 MB | **U-Boot payload** after the port |
| `super` | `0x28000000` | ~4.9 GB | Android dynamic partitions (stock) |
| `userdata` | `0x186000000` | ~52 GB | repurposed: ESP + rootfs |
| `otp` | `0xe8bcf8000` | 43 MB | factory OTP (never touch) |
| `flashinfo` | `0xe8e7f8000` | 16 MB | factory flash info (never touch) |

> After repartitioning, the ESP is `p40` and the Arch rootfs is `p41` in the custom
> GPT used by this project. Always verify with `printgpt` before writing.
