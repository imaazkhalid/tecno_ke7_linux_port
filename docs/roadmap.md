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

**Status:** driver, binding and DT node are written and compile:

- `patches/linux/0001-ke7-board-and-drivers.patch` now contains
  `panel-novatek-nt36525b.c`, its YAML binding, the panel node and the
  `display-timings` block.
- `make mediatek/mt6768-tecno-ke7.dtb` builds cleanly.
- Timings are DT-driven, so calibration needs **no driver rebuild**.

**Remaining:** flash the DTB, bring up `mtk_dsi` + mmsys/ovl/rdma, then tune
`display-timings` until the panel locks at 60 Hz (or extract the exact porches
from LK).

### 2.2 Fingerprint (Sunwave) — BLOCKED by TEE design

**Known:** SPI0 CS0 @ 8 MHz (SPI pins GPIO6), EINT GPIO7, reset GPIO8 (hypothesis),
`/dev/sunwave_fp`, `/dev/teei_fp`, HAL `swfingerprint.default.so`, chips SW8202/SW8231.

**Why it is blocked:** the HAL never touches SPI. It builds a framed message
(magic `0x100b`, 8-byte header with total/write/read lengths, then write payload,
then a read buffer) and hands it to **`sf_trustlet_client_exchange_message()`**.
The actual SPI transfer happens inside a signed Trustonic TEE trustlet in secure
world. The kernel driver only exposes reset/power/clock/IRQ ioctls
(`0x7302`, `0x7305/0x7306`, `0x7307/0x7308`, `0x7309`, `0x7320`, `0x7330`) — there is
**no bulk-transfer ioctl** a mainline driver could use.

**Consequences:**

| Option | Feasible? |
|---|---|
| libfprint over spidev | ❌ no SPI access, protocol unknown |
| New kernel SPI driver | ❌ sensor command set is inside the trustlet |
| Reuse vendor trustlet on mainline | ❌ Trustonic TEE not available upstream |
| Reverse the trustlet binary | ❌ encrypted/signed, not in the filesystem |

**Recommendation:** defer fingerprint. Revisit only if a Sunwave SW8202 datasheet
or a non-TEE firmware variant appears. Document the node (already in
`dts/fingerprint-sunwave-sw8202.dtsi`) so the hardware is described even while
unsupported.

### 2.3 Main camera sensor — CLOSED

**Identified:** **Samsung S5K3P9SX** (`s5k3p9sx_mipi_raw`, 16 MP) at i2c-2 `0x1a`,
from the vendor boot log. Full camera i2c map is in
[hardware-matrix.md](hardware-matrix.md#i2c-map-from-the-running-vendor-kernel).

**Next:** write the `s5k3p9` V4L2 subdev driver (no mainline driver exists yet;
`ov02a10`/`ov02c10` are good structural references).

### 2.4 Sensor i2c addresses

MXC6655 (accel), STK33562 (ALS/PS), MMC5603 (mag) sit behind the **SCP**.
**Status:** blocked on SCP firmware analysis. The AP has **no `/dev/i2c-*`**
(`CONFIG_I2C_CHARDEV` is off), and no sensor debugfs exists, so userspace scanning
is not possible on the stock build.

**Method:** disassemble `scp.img` (ARM Thumb-2) around the driver entry points
(`mxc6655`, `stk33562` strings are log text; the config tables are elsewhere) and
find the `i2c_master_*` calls whose address immediate is the chip address. A second
option is a small debug module built against the vendor kernel to read the SCP's
i2c client list.

### 2.5 Wi-Fi / Bluetooth (MT6631)

**Correction (from the MT6631 datasheet):** MT6631 is only the **RF front-end**;
the Wi-Fi MAC/baseband and the BT/GNSS logic are in the **MT6768 CONNSYS**. This
means the `mt76` family (standalone PCIe/USB/SDIO chips) is **not applicable**.

| Route | Pros | Cons |
|---|---|---|
| Port vendor `wlan_drv_gen4m` + `wmt_drv` to LTS | known to work, matches hardware | out-of-tree, large (5 MB+), not upstreamable as-is |
| New CONNSYS/WMT driver | only real long-term path | multi-month, needs firmware/HW docs |

**Recommendation:** port the vendor gen4m stack to the current LTS as a stopgap
(the same approach used for CCCI), and structure it as a separate module tree so
kernel bumps are contained. A clean upstream driver is a separate project.

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
