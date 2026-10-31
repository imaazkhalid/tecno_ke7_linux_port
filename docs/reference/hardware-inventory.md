# TECNO Spark 6 (KE7) — Complete Hardware Inventory from Android

Extracted from the running Android 10 retail ROM (`KE7-H693HJKM-Q-GL-220729V478`) on
2026-10-27. Sources: vendor device tree (`vendor.dts`, decompiled from
`/sys/firmware/fdt`), kernel config (`kconfig.gz`), `/proc/interrupts`, sysfs, HAL
dumps and `/vendor/etc` configuration. Intended as the reference for the mainline
Linux port.

Raw dumps referenced below live in this directory.

---

## 1. Platform

| item | value |
|---|---|
| SoC | MediaTek **MT6768** (Helio G70), HW code 0x707, "k68v1" |
| CPU | 2 × Cortex-A75 (`arm,cortex-a75`) + 6 × Cortex-A55 (`arm,cortex-a55`) |
| GPU | **Mali-G52 MC2**, `13040000.mali`, GLES 3.2 (r20p0) |
| Kernel | **4.14.141** (MTK vendor), `kconfig.gz` |
| DT | `fdt.dtb` / `vendor.dts` (5,685 lines, 436 compatible strings) |
| RAM | 3,894,928 KB (4 GB class) |
| Storage | eMMC, `11230000.mmc` |

## 2. Display

| item | value |
|---|---|
| **LCM** | **`nt36525b_hdp_dsi_vdo_txd_boe_ke7`** (from `atag,videolfb`) |
| panel controller | **Novatek NT36525B** |
| panel vendor | **TXD**, glass **BOE** |
| type | **HD+ 720 × 1640**, **DSI *video* mode** (not command mode) |
| DSI host | `14014000.dsi0`, `compatible = "mediatek,dsi0"` |
| display engines | `1400b000.disp_ovl0`, `1400c000.disp_ovl0_2l` (overlay), `1400d000.disp_rdma0`, `1400e000.disp_wdma0`, `1400f000.disp_color0`, `14010000.disp_ccorr0`, `14011000.disp_aal0`, `14012000.disp_gamma0`, `14013000.disp_dither0`, `14001000.disp_mutex0`, `14015000.disp_rsz0` |
| reset gpio | `lcm_rst_out0_gpio` / `lcm_rst_out1_gpio` (pinctrl nodes, DTS lines 1216/1226) |
| **backlight** | **`/sys/class/leds/lcd-backlight`**, `max_brightness = 255`; PWM at **`1100e000.disp_pwm`** |
| bias | RT5081 (Richtek) referenced in the atag string |
| vsync / te | `dsi0_te` node; IRQ `dsi0_te_event = 0x8d`, `dsi0_irq_event = 0x8e`, `dsi0_done_event = 0x8f` |

**Mainline note:** DSI *video* mode + Novatek NT36525B. Needs a panel driver
(`panel-novatek-nt36525` style) with the KE7 timing set, plus `mtk_dsi` and the
`disp_pwm` backlight (or a PWM-backlight binding on `1100e000.disp_pwm`).

## 3. Touch

| item | value |
|---|---|
| controller | **Novatek NVT-ts-spi** (`focaltech,fts` as secondary compatible) |
| bus | **SPI**, `spi-max-frequency = 0xCF8500` = 13.6 MHz |
| DT node | `touch@0`, `novatek,swrst-n8-addr = 0x3F0FE`, `novatek,spi-rd-fast-addr = 0x3F310` |
| MP criteria | `novatek-mp-criteria-6232` |
| input device | `/dev/input/event3`, name **`mtk-tpd`**, `ABS=663800001000003` (multi-touch) |
| firmware | `novatek_ts_fw.bin` (see PROJECT_STATUS §34) |

## 4. Keys / power / headset

| item | value |
|---|---|
| keypad | **`mtk-kpd`** at **`10010000.kp`**, IRQ, input `event1`; KEY bitmask covers **power** + **volume up/down** |
| soft keys | `sf-keys`, input `event2` |
| headset detect | **`ACCDET`**, input `event0`, `SW=d4` (headset + hook), handles jack insert + mic |
| power key | via `mtk-kpd` (no separate PMIC pwrkey node exposed) |

## 5. PMIC / charger / battery

| item | value |
|---|---|
| PMIC | **MT6358** (`mediatek,mt6358-pmic`, `mt6358-regulator`, `mt635x-auxadc`), `1000d000.pwrap` |
| charger IC | **Richtek RT9471** switch charger, `richtek,swchg` @ **i2c 0x53**, `chg_name = "primary_chg"`, irq gpio 9, `led_ctl_gpio` gpio 0xA5 (165) |
| charger IRQs | `wdt, chg_mivr, vac_ov, otg_fault, chg_rdy, chg_done, aicc_done, pe_done, chg_tout, ieoc, rechg, chg_batov` |
| power supplies | `/sys/class/power_supply/{ac,battery,charger,usb}` |
| battery (live) | Li-ion, 4.228 V, 87 %, `CHARGE_FULL=2946000` µAh, `TEMP=286` (28.6 °C) |
| regulators | `regulators.txt` (full MT6358 regulator summary) |
| fuel gauge | MTK SW FG (`atag,fg_swocv_v/i`, `atag,boot_voltage`) |

## 6. Audio

| item | value |
|---|---|
| SoC audio | `11220000.audio`, `11220000.mt6768-afe-pcm`, `11221000.audio_sram` |
| codec | **MT6358** (`mediatek,mt6358-sound`) |
| sound card | `sound` = **`mediatek,mt6768-mt6358-sound`** |
| **external speaker amp** | **`tran_audio,audio`** — `extamp_gpio = <gpio 0x27 = 39>`, `extamp_mode = 2`, `extamp_speech_mode = 2`, `real_2in1_receiver_mode = 6` (Transsion custom) |
| config | `cfg/audio_policy_configuration.xml`, `cfg/audio_device.xml`, `cfg/audio_param/*` (1.2 MB of tuning XML) |
| IRQs | `Afe_ISR_Handle`, `BTCVSD_ISR_Handle`, `accdet` |

**Mainline note:** MT6358 codec + MT6768 AFE is the classic `mt6358`/`mt6768` machine
driver pair (already partially upstream). The **speaker amp enable is GPIO 39** —
that is what makes sound come out of the loudspeaker; without it only the earpiece
works. Also `extamp_mode` tells the amp is a 2-state GPIO-controlled type.

## 7. Camera

| item | value |
|---|---|
| camsys | `1a000000.camsys` (+ `smi_larb3 @1a002000`) |
| sensor IF | `1a003000.cam1`, `1a004000.cam2`, `cam2`, `cam3`, `camsv1..camsv4`, `ccu` |
| sub-sensors (DT) | **`gc02m1_mipi_raw`** (GalaxyCore GC02M1, 2 MP) and **`ov02b10_mipi_raw`** (OmniVision OV02B10, 2 MP) — macro + depth |
| main sensor | not in DT (MTK `kd_imgsensor` runtime table); see `camera.txt` for the live sensor list |
| flash | via PMIC/GPIO (MTK `flashlight` node) |

## 8. Sensors (all via MTK SCP sensor hub)

| sensor | type | notes |
|---|---|---|
| ACCELEROMETER | android.sensor.accelerometer | 5–200 Hz, FIFO 3000 events, non-wakeup |
| LIGHT | android.sensor.light | |
| PROXIMITY | android.sensor.proximity | wakeup |
| STEP_DETECTOR / STEP_COUNTER | | hardware step counting |
| STEP_DETECTOR_WAKEUP | | |
| TILT_DETECTOR, WAKE_GESTURE, STATIONARY_DETECT, MOTION_DETECT | | SCP-side features |

All report vendor **"MTK"** — the physical chips sit behind the **SCP**
(`10500000.scp`, `10001000.scpsys`), so their i2c addresses are in the SCP firmware,
not the AP device tree. Full list: `sensors.txt`.

## 9. Connectivity

| item | value |
|---|---|
| WiFi | `mediatek,wifi` @ **`18000000`**, IRQ 0x11D (MTK connsys, MT7663-class) |
| BT | MTK BTIF (`BTIF_WAKEUP_IRQ` in `/proc/interrupts`), `/dev/stpbt` family |
| GNSS | MTK (`mtk_agpsd`, `lppe`, `gnssdebugreport`) |
| FM | `com.transsion.fmradio` + `FM_FunBase` (uses the same connsys) |

## 10. Storage / USB / video

| item | value |
|---|---|
| eMMC | `11230000.mmc` (`mediatek,msdc`) |
| USB | `11200000.usb0`, `11210000.usb1p_sif` |
| video decode | `16000000.vdec_gcon` |
| video encode | `17000000.venc_gcon` |
| M4U (IOMMU) | `10205000.m4u` |

## 11. Thermal

Zones (`dump_thermal`/sysfs): `mtktscpu`, `mtktsAP`, `mtktsbattery`, `battery`,
`mtktspmic`, `mtktscharger`, `mtktspa`, `mtktswmt`, `mtktsdctm`, `mtktsbtsmdpa`,
`mt6358tsbuck1..3`, `tzimgs0..6`.
Policy files: **`cfg/tp/thermal.conf`**, `.thermal_policy_00/03/05/08`, `.ht120.mtc`,
`thermal.off.conf`.

## 12. Misc

| item | value |
|---|---|
| fingerprint | **`sunwave-fp`** on **SPI** (8 MHz), plus `mediatek,mt6753-fingerprint` node, irq gpio 7 |
| vibrator | `mediatek,vibrator` — `vib_timer=25`, `vib_limit=9`, `vib_vol=11`; `/sys/class/leds/vibrator` (max 255) |
| notification LED | `/sys/class/leds/blue` (max 255) |
| MCDC/CCCI | `mediatek,ccci`, `apcldmain/out/misc`, `mdcldmamisc` (modem link — not needed for the port) |
| secure | `trustonic,mobicore`, `microtrust,utos`, `mediatek,masp` |

## 13. I2C / SPI map

- I2C controllers: `i2c0..i2c8` at `11007000, 11008000, 11009000, 1100f000, 11011000,
  11016000, 1100d000, 11004000, 11005000`
- SPI controllers: `spi0..spi5` at `1100a000, 11010000, 11012000, 11013000, 11014000,
  11015000` (touch + fingerprint)
- i2c devices present: `0-0014, 2-000c, 2-0011, 2-0018, 2-001a, 2-0050, 2-0060, 3-0008,
  4-0010, 4-0012, 4-002d, 4-0052, 5-0034, 5-004e, 5-0053, 6-003e, 6-0063, 7-0016, 7-004b`
  (the charger RT9471 is `? -0053`)

## 14. Mainline porting checklist (derived)

| subsystem | what is needed | status hint |
|---|---|---|
| display | `mtk_drm` + DSI + **NT36525B panel driver** + PWM backlight | **main gap** |
| touch | `novatek-nvt-ts` on SPI (already upstream, needs DT node) | easy |
| keys | `mtk-kpd`/`mtk-pmic-keys` (power/volume) | easy |
| charger | **RT9471** driver (upstream `rt9471` exists) + MT6358 regulator | medium |
| battery | MT6358 auxadc + SW fuel gauge | medium |
| audio | `mt6768-mt6358` sound card + **GPIO 39 speaker-amp** | medium |
| camera | CAMSYS + GC02M1 / OV02B10 (both have mainline drivers) | hard (main sensor unknown) |
| sensors | SCP is closed; direct i2c drivers required (chips unknown) | hard |
| WiFi/BT | MT7663 connsys (`mt76` has MT7663 support) | medium |
| GPU | Panfrost (worked in the previous Linux install) | done |
| thermal | MT6358 thermal + zone mapping | easy |

---

### Files in this directory
```
fdt.dtb  vendor.dts            vendor device tree (raw + decompiled)
kconfig.gz                     kernel 4.14.141 config
input_devices.txt              /proc/bus/input/devices (keys, touch, accdet)
interrupts.txt                 /proc/interrupts (driver/IRQ names)
platform.txt                   /sys/bus/platform/devices
regulators.txt                 MT6358 regulator summary
gpio.txt                       debugfs gpio
i2c_names.txt                  i2c device list
sensors.txt                    dumpsys sensorservice
camera.txt                     dumpsys media.camera
lshal.txt                      all HALs
thermal.txt  power.txt  leds.txt
cfg.tar / ext/cfg/             audio policy, audio_param, thermal policies, media profiles
```

---

## 15. Completeness pass — what else is there (and what is NOT)

### Present but previously missed
| hardware | evidence |
|---|---|
| **NFC** | `nfc@08` = `mediatek,nfc` on **i2c-3 addr 0x08** (matches the `3-0008` i2c device); `nfc-gpio-v2`: `gpio-rst = 159`, `gpio-irq = 9`; IRQ node `irq_nfc` |
| **flash LED** | `mediatek,flashlight_core` + **`flashlights_aw36515`** (AW36515 i2c flash driver), HWEN pin `pinmux 0xa900` = **GPIO 169** |
| **smart PA** | `smart_pa` node exists (empty - configured at runtime by the audio HAL) |
| **headset jack** | ACCDET (`event0`, `SW=d4`) |

### NOT present on this device (checked in vendor DTS + sensor list)
- **no hall sensor** (no magnetic flip cover detect)
- **no IR blaster**
- **no gyroscope**
- **no magnetometer / compass**
- **no barometer**
- **no SAR sensor** (no proximity-based SAR backoff node)
- no ambient light *sensor IC* in DT (LIGHT is reported through the SCP)

Sensor set is therefore exactly: **accelerometer, light, proximity, step counter,
step detector, tilt, wake gesture, stationary/motion detect** — all via SCP.
That is consistent with the Spark 6 being a budget device.

### Other buses/devices confirmed
- i2c-0 `0x14`, i2c-2 `0x0c,0x11,0x18,0x1a,0x50,0x60`, i2c-3 `0x08` (**NFC**),
  i2c-4 `0x10,0x12,0x2d,0x52`, i2c-5 `0x34,0x4e,0x53` (**RT9471 charger**),
  i2c-6 `0x3e,0x63`, i2c-7 `0x16,0x4b`; i2c-1 and i2c-8 unpopulated.
- SPI0..5 present; touch + fingerprint on SPI.
