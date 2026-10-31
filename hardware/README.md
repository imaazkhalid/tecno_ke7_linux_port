# Hardware dumps and how to regenerate them

The files here are measurements taken from a **rooted stock Android** on a KE7.
They contain no device-unique data (no IMEI, serial or MAC) and no proprietary code.

You do not have to trust our dumps — **generate your own** in one command:

```bash
./tools/extract-hardware.sh            # needs adb + root (Magisk)
```

It writes the same set of files into `hardware/dumps/`.

## What each file tells you

| File | Contents | Used for |
|---|---|---|
| `cmdline.txt` | kernel command line from LK | memory reservations, `ccci` ATAGs, AVB state |
| `interrupts.txt` | `/proc/interrupts` | IRQ numbers for every driver (CCCI, DSI, SPI, charger) |
| `input_devices.txt` | `/proc/bus/input/devices` | touch, keypad, headset event numbers |
| `platform.txt` | `/sys/bus/platform/devices` | register bases (`14014000.dsi0`, `11230000.mmc`, …) |
| `gpio.txt` | debugfs GPIO table | pin ownership and directions |
| `regulators.txt` | MT6358 regulator summary | rail names and voltages |
| `power.txt` | `power_supply` uevents | charger, battery, fuel gauge |
| `thermal.txt` | thermal zones and temperatures | zone names and typical values |
| `leds.txt` | LED class devices | backlight, vibrator, notification LED |
| `i2c_names.txt` | i2c device list | peripheral addresses |
| `sensors.txt` | `dumpsys sensorservice` | SCP-backed sensor set |
| `camera.txt` | `dumpsys media.camera` | sensor identification |
| `lshal.txt` | `lshal` | HAL inventory |
| `boot_dmesg.txt` | kernel log | driver probe order and errors |
| `vendor.dts` | decompiled vendor device tree | the source of truth for wiring |
| `fdt.dtb` | raw `/sys/firmware/fdt` | binary vendor DT (reference) |

## The most useful file: `vendor.dts`

It is the vendor's own device tree, decompiled. Every GPIO, regulator, bus and
panel parameter the stock kernel uses is in there. When in doubt, search it:

```bash
grep -n "lcm_rst\|extamp\|rt9471\|nt36525\|touch@" hardware/dumps/vendor.dts
```

Build a smaller, mainline-oriented tree from it — see
[`../dts/`](../dts) and [`../docs/porting-notes.md`](../docs/porting-notes.md).

## Related reference

- Full annotated inventory: [`../docs/reference/hardware-inventory.md`](../docs/reference/hardware-inventory.md)
- Board map with addresses and IRQs: [`../docs/hardware.md`](../docs/hardware.md)
- Partition table: [`gpt_table.txt`](gpt_table.txt)
