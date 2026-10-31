# Roadmap — closing the remaining gaps

Status of every missing piece, with the exact method to obtain it. Ordered by what
unblocks the most.

---

## Phase 1 — hardware data (done)

`tools/collect-device.sh` captured kernel internals, HAL dumps, firmware and the
live DT. See [`hardware-matrix.md`](hardware-matrix.md) and
[`reference/device-collection.md`](reference/device-collection.md).

## Phase 2 — missing hardware facts

### 2.1 Panel timings (blocks DRM)

**What is missing:** `HSA/HBP/HFP/VSA/VBP/VFP`, pixel clock and lane rate for
`nt36525b_hdp_dsi_vdo_txd_boe_ke7`.

**What we know:**
- burst clock `mm_dsi0` = **228.5 MHz**, 4 lanes, 720×1640.
- LK contains the panel name at offset **`0x8cd55`**.
- We found the LK **panel-name comparison chain**: it compares the DT `lcmname`
  against a list and returns an index — our panel is **index 8**, loaded from the
driver pointer table at `0xffffff8008f7a6c0` (zero in the image: the table is
  populated at runtime by KASLR relocation). That chain is the
  key to the driver table: the caller indexes a `LCM_DRIVER[]` array of structs
  containing `{name, set_util_funcs, init, get_params, ...}`.

**Method (in order):**
1. Disassemble LK around the caller of the compare chain; recover the driver struct
   array base (ARM literal pool gives the LK load base).
2. In the `lcm_get_params` function pointer target, read the immediate stores into
   `LCM_PARAMS`: the struct layout is
   `type, ctrl, width, height, dsi{lane_num, data_rate, HSA, HBP, HFP, VSA, VBP, VFP}`.
3. Cross-check with the DSI timing registers at `0x14014000` (vendor kernel keeps
   them programmed); `devmem` exists on the device but `/dev/mem` is not exposed, so
   this needs a small debug module or the vendor's `DISP` debugfs.
4. Last resort: conservative values (800×1750 total, 84 MHz pixel clock) and adjust
   until the panel locks at 60 Hz.

**Deliverable:** `dts/panel-nt36525b-ke7.dtsi` with real values + a
`panel-novatek-nt36525b` driver compatible with `panel-simple` style.

### 2.2 Fingerprint (Sunwave)

**Known:** SPI0 CS0 @ 8 MHz, **SPI pins on GPIO6**, EINT **GPIO7**, `/dev/sunwave_fp`,
TEE `/dev/teei_fp`, HAL `swfingerprint.default.so`, chips `ic_8202`/`ic_8231`.
**Missing:** reset GPIO, protocol.

**Method:**
1. Reset GPIO: the ODM DT node is not in the main FDT or dtbo. Extract it from the
   vendor boot image (the ODM DTB is built into the kernel image; search for the
   `sunwave-fp` property block near its strings) or from the vendor
   `spi-sunwave-fp` driver source. GPIO8 is the current hypothesis (unclaimed,
   pull-up, adjacent to the EINT).
2. Protocol: reverse `swfingerprint.default.so` — the SPI read/write wrappers and
   the `ioctl` numbers are visible in strings/symbols; the image format is the
   vendor's `Csunwave-image`.
3. Driver: SPI driver exposing `/dev/sunwave_fp` with the same ioctl ABI, or better
   a **libfprint** backend that talks SPI directly from userspace (no kernel ABI
   needed) — recommended for upstream.

**Deliverable:** `dts` node + libfprint driver + firmware extraction note.

### 2.3 Main camera sensor

**Known:** GC02M1 (macro) and OV02B10 (depth) in DT; main sensor only in MTK's
`kd_imgsensor` table.
**Method:** open the camera with `logcat -b all` running and grep for
`imgsensor`/`kd_imgsensor`/`SENSOR_ID`; the HAL logs the detected sensor. If the
log is silent, read the sensor ID register over i2c from the vendor kernel's
`/proc/driver/camera`.

### 2.4 Sensor i2c addresses

MXC6655 (accel), STK33562 (ALS/PS), MMC5603 (mag) sit behind the **SCP**.
**Method:** disassemble `scp.img` (ARM Thumb-2) around the driver strings; the i2c
client addresses are passed to `i2c_master_send`-style helpers as immediates.
Alternative: halt the SCP and scan i2c-0..8 with a scope-free bus scan (risky).

### 2.5 Wi-Fi / Bluetooth (MT6631)

No upstream driver exists for MT6631. Two routes:

| Route | Pros | Cons |
|---|---|---|
| Extend `mt76` | upstreamable, maintained | MT6631 is a different core; large reverse-engineering effort |
| Port vendor `wlan_drv_gen4m` | known to work | out-of-tree, breaks every kernel, not upstreamable |

**Recommendation:** keep the vendor port as a *diagnostic* tool, but do not ship it
as the long-term solution. The realistic upstream path is a `mtk-conninfra` +
`mt76` glue driver, which is a multi-month project.

### 2.6 NFC

Identify the chip from `libnfc-nci.so` strings; if PN5xx, the upstream `nxp-nci`
driver covers it with a small DT node (i2c-3 `0x08`, reset GPIO 159, IRQ GPIO 9).

## Phase 3 — upstreaming

See [`upstream-strategy.md`](upstream-strategy.md). Order:

1. DT for already-supported blocks
2. touch SPI
3. panel + backlight
4. audio
5. sensors
6. CCCI modem
7. connectivity
8. fingerprint / camera

## Phase 4 — long-term maintenance

| Task | Cadence |
|---|---|
| Build against `linux-next` | every merge window |
| `make dtbs_check W=1` | every kernel bump |
| Rebuild U-Boot + kernel + DTB from source | every release |
| Tag `v<kernel>-ke7.<n>` | every tested combination |
| Update `compatibility.md` | every release |

## Definition of done

- Device boots mainline **LTS** and **linux-next** with the same DTS.
- Every supported block has a DT binding and a driver upstream or in submission.
- No vendor kernel module is required for boot, display, touch, storage, USB, power.
- Missing firmware degrades gracefully.
- A new contributor can build and flash from this repo alone.
