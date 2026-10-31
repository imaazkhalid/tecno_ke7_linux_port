> **See also:** [hardware-matrix.md](hardware-matrix.md) — the consolidated, component-by-component driver status table (newer than this page).

# KE7 mainline port — subsystem plan (from Android evidence)

Derived from `hardware-dump/`. Everything marked **known** was read out of the
running retail ROM (vendor DTB, sysfs, HALs, debugfs, LK strings).

---

## 1. Display — the critical path

| item | value | status |
|---|---|---|
| panel | Novatek **NT36525B**, `nt36525b_hdp_dsi_vdo_txd_boe_ke7` | **known** |
| resolution | 720 × 1640 @ 60 Hz | **known** |
| DSI mode | **BURST video**, high speed, non-continuous clock | **known** |
| burst clock | **228.5 MHz** (`mm_dsi0` in clk_summary) | **known** |
| reset GPIO | **45** | **known** |
| bias ENP / ENN | **153 / 152** | **known** |
| backlight | **OCP2130** i2c LED driver (`led_mode = 5`), 0..255 | **known** |
| porches / pixel clock | from LK LCM driver | **MISSING** |

**Files:** `porting/panel-nt36525b-ke7.dtsi`

### How to get the missing timings
1. **Disassemble `lk.img`** — the LCM driver string is at `0x8CDEE`
   (`nt36525b_hdp_dsi_vdo_txd_boe_ke7`). The driver fills an `LCM_PARAMS` struct
   with `HSA/HBP/HFP/VSA/VBP/VFP`, `DATA_RATE`, `LANE_NUM`. LK is Thumb-2 at a
   fixed base, so the stores are easy to spot once you find the driver function
   (the string is referenced from the LCM driver table).
2. Or read the **DSI timing registers** at `0x14014000` while the panel is up
   (vendor `mtk_dsi` keeps them programmed).
3. Or measure: set the panel up with a conservative timing and adjust until the
   picture is stable and the refresh measures 60 Hz.

Also note the vendor reports **BURST video mode** — mainline `mtk_dsi` supports
video mode; burst is the panel's preferred pacing, not a hard requirement for a
first light.

---

## 2. Backlight — OCP2130

- LK contains `ocp2130_i2c_write_byte`, and the DT LED node is
  `mediatek,lcd-backlight` with `led_mode = 5` (i2c backlight).
- `/sys/class/leds/lcd-backlight`, `max_brightness = 255`.
- **Needs a small i2c LED driver** (register map is the standard OCP2130:
  brightness register + enable). Address must be confirmed by scanning i2c-1 /
  i2c-8 (both were empty in the AP's device list, so the LK/kernel talks to it
  without instantiating an i2c client).
- Fallback: the PWM node `1100e000.disp_pwm` still exists, so if the OCP2130 is
  only an enable/bias helper, PWM dimming may work.

---

## 3. Touch — Novatek NVT-ts-spi

| item | value |
|---|---|
| bus | SPI, **13.6 MHz** (`spi-max-frequency = 0xCF8500`) |
| node | `touch@0`, `"novatek,NVT-ts-spi"`, fallback `"focaltech,fts"` |
| swrst addr | `0x3F0FE` |
| fast-read addr | `0x3F310` |

Mainline has `novatek-nvt-ts` (i2c) — the SPI variant needs the SPI transport but
the protocol is the same. DT: `porting/` (add a `spi` node with the two addresses
above and an interrupt).

---

## 4. Keys / power

```dts
keypad: kp@10010000 {
        compatible = "mediatek,kp";
        reg = <0 0x10010000 0 0x1000>;
        interrupts = <0 0x49 2>;
        mediatek,kpd-key-debounce = <0x400>;
        mediatek,kpd-sw-pwrkey     = <0x74>;   /* KEY_POWER */
        mediatek,kpd-hw-pwrkey     = <0x08>;
        mediatek,kpd-hw-map-num    = <0x48>;
};
```
Power + volume both go through `mtk-kpd`; headset jack through **ACCDET**
(`mediatek,accdet`, input device `event0`, `SW=d4`).

For suspend/resume, the power key is the wakeup source (no PMIC pwrkey node).

---

## 5. Audio — MT6358 + GPIO 39 amp

| item | value |
|---|---|
| card | `mediatek,mt6768-mt6358-sound` |
| codec | MT6358 |
| AFE | `11220000.mt6768-afe-pcm` |
| **speaker amp** | **GPIO 39**, `extamp_mode = 2` |

**File:** `porting/audio-amp-gpio39.dtsi`
Quick hardware check: `gpioset … 39=1` then play something — if the speaker
comes alive, the pin/polarity are confirmed.

---

## 6. Charger / PMIC / battery

| item | value |
|---|---|
| PMIC | **MT6358** |
| charger | **Richtek RT9471**, i2c bus **5**, addr **0x53** (confirmed via dmesg `rt9471 5-0053`) |
| fuel gauge | MTK SW FG (no dedicated gauge IC) |
| supplies | `ac`, `usb`, `charger`, `battery` |

Upstream `rt9471` charger driver exists; MT6358 regulator + `mt6358-auxadc` are
upstream. This subsystem is the most "already done" part.

---

## 7. Camera

- CAMSYS `1a000000`, seninf `1a003000.cam1` / `1a004000.cam2`, CAMSV1..4, CCU.
- DT sub-sensors: **GC02M1** (2 MP macro) and **OV02B10** (2 MP depth) — both have
  mainline drivers.
- Main sensor is only in MTK's `kd_imgsensor` table (not in DT) — identify it from
  `hardware-dump/camera.txt` (cameraserver enumerates the sensor names).

---

## 8. Sensors — the hard one

All sensors are behind the **SCP** (`10500000.scp`, `10001000.scpsys`):
accelerometer, light, proximity, step counter/detector, tilt, wake gesture,
motion/stationary. Their i2c addresses live in the **SCP firmware**, not the AP
DT, so no sensor chip names are exposed.

Options:
- Find the chips by scanning i2c buses while the SCP is halted (risky), or
- Extract the sensor list from the SCP firmware partition, or
- Accept no sensors initially (Phosh works without them).

## 9. Connectivity / GPU / video (already known-good)

- WiFi `18000000`, IRQ 0x11D — MT7663-class, `mt76` supports it.
- BT: MTK BTIF (`/dev/stpbt*`).
- GPU: Mali-G52 MC2 @ `13040000` — Panfrost worked in the previous install.
- vdec `16000000`, venc `17000000`.
- eMMC `11230000`, USB `11200000`.

---

## Suggested bring-up order

1. **Display** (NT36525B + timings) and **backlight** — without it nothing else is
   verifiable.
2. **Touch** (SPI Novatek) — makes the device usable.
3. **Keys + charger + fuel gauge** — power management and suspend.
4. **Audio** (MT6358 + GPIO 39).
5. **WiFi/BT**, then camera, then sensors.

---

# 10. Battery / charging / power (measured 2026-10-28)

| item | value |
|---|---|
| battery type | Li-ion, `POWER_SUPPLY_TECHNOLOGY=Li-ion`, health **Good** |
| **charge_full (learned)** | **2,946,000 µAh = 2946 mAh** |
| charge_counter | 2,356,800 µAh (80 %) |
| voltage_now | 4.123 V |
| current_now | ~ -0.8 A while charging / -10 mA near full |
| temp | 27.2–28 °C |
| cycle_count | 0 (not maintained) |
| supplies | `ac`, `usb`, `charger`, `battery` |
| usb limits | `CURRENT_MAX=500000` µA, `VOLTAGE_MAX=5000000` µV |
| charger | RT9471 @ i2c-5 0x53, `POWER_SUPPLY_ONLINE=1` |
| suspend states | **`freeze mem`** |
| wakeup sources | `event0` (ACCDET), `event1` (kpd), `event2` (sf-keys), `event3` (touch), `KeyEvents`, `radio-interface`, `WLAN*`, `PowerManagerService.*` |

**NOTE:** the Spark 6 ships a **5000 mAh** cell, but the gauge reports **2946 mAh**
learned capacity. Since `nvram`/`proinfo` were wiped, the fuel gauge lost its
calibration data — this is very likely a **mis-calibrated gauge**, not real wear.
Relevant for the Linux port: the gauge needs the battery profile (MTK SW FG) or it
will report similarly wrong numbers.

# 11. Modem / CCCI (for bringing the modem up on Linux)

The modem **hardware works** on this device (it boots, AT answers, RF measures
`CSQ ≈ 24`) — it just has no IMEI, so the network rejects it. Everything needed to
start it:

| item | value |
|---|---|
| DT nodes | `mediatek,ccci`, `apcldmain`, `apcldmaout`, `apcldmamisc`, `apcldmamisc_ao`, `mdcldmamisc` |
| memory (ATAG) | `ccci,modem_info_v2 = <0xff9f 0x00 0xd0000 0x00 0x3000000 0x1d000000 0x1000000 ...>` |
| | `atag,mdinfo = <0x3000000 0x6080041 0x00>` (MD base 0x3000000, size 0x1d000000?) |
| IRQs | `CCIF0_AP`, `CCIF_AP_DATA`, `CLDMA_AP`, `MD1_*`, `md_ccif` (see `interrupts.txt`) |
| char devices | `/dev/ccci_ioctl0..4`, `/dev/ccci_fs`, `/dev/ccci_ipc_*`, `/dev/ccci_md1_sta`, `/dev/ccci_ccb_meta`, `/dev/ccci_ccb_dhl`, `/dev/ccci_raw_mdm`, `/dev/ttyC0`, `/dev/ttyC1` |
| AP daemons | `ccci_mdinit`, `ccci_fsd`, `ccci_rpcd`, `mtkfusionrild`, `gsm0710muxd` |
| firmware | `md1img` partition (57 MB retail / 57.8 MB test build), `md_udc` (23.7 MB) |
| AT path | `atcid` -> `/dev/socket/adb_atci_socket` (a small C client works; see tools/atci_cli.c) |

The modem-side failure is **not** hardware: `AT+EGMR=0,7` returns `""` (empty IMEI)
and attach is rejected with cause 6 `Illegal ME`. On Linux the same chain
(CCCI -> `ccci_mdinit`-equivalent -> MD boot) is what the existing `cellular-port`
work targets.

# 12. Thermal (live values, idle + charging)

```
mtktscpu   61.2 C     mtktspmic  33.7 C     mtktsbattery 27.2 C
mtktsAP    33.0 C     mt6358tsbuck1..3 33.7-34.3 C
mtktsbtsmdpa 31.0 C   mtktsdctm  28.9 C     battery      28.1 C
mtktswmt   25.0 C     mtktscharger / mtktspa / tzimgs* = -127 C (unavailable)
```
Policies: `cfg/tp/thermal.conf`, `.thermal_policy_00/03/05/08`, `.ht120.mtc`.

# 13. Suspend / wakeup (what must work for "screen off on idle")

`/sys/power/state` = **`freeze mem`** (Android uses `mem` suspend).
Wakeup sources observed: `event0` (headset), `event1` (power/volume keypad),
`event3` (touch), `KeyEvents`, `radio-interface`, `WLAN*`, plus framework locks.
For the Linux port, the power key (via `mtk-kpd`) and touch must be wakeup-capable,
and the RT9471 charger IRQ must be able to wake for charging events.
