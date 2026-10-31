# Android: recovery, root, debloat and bring-up

The device is a Linux machine first, but stock Android was essential to the project:
it provided the vendor device tree, HALs, calibration data and the META path for the
IMEI restore. This page covers getting Android back to a healthy, usable state.

---

## 1. Which firmware

| Item | Value |
|---|---|
| Model | Tecno Spark 6 (KE7 / `KE7 JS1`) |
| Build | `KE7-H693HJKM-Q-GL-220729V478` (retail GL, Android 10) |
| SoC | MT6768 / Helio G70 |
| Flashing tool | `mtkclient` over BROM (`0e8d:0003`) |

The retail build is the correct one for this unit (GL variant). Vendor firmware for
this model is no longer distributed officially; the image used here was obtained from
a public mirror. **No firmware is included in this repository.**

### What the flash script preserves

[`../tools/flash_retail.sh`](../tools/flash_retail.sh) writes only the Android
partitions (`super`, `boot`, `recovery`, `md1img`, `dtbo`, `logo`, `tee1/2`, `scp1/2`,
`sspm`, `spmfw`, `vbmeta*`, `cache`, `tranfs`) and explicitly **never writes**:

```
preloader (boot0/boot1)  seccfg   nvram   nvdata   persist
protect1/2   otp   flashinfo   tkv   lk/lk2   md_udc
boot_para   proinfo   para   expdb   frp   metadata   nvcfg   gz1/2   sec1
```

It also snapshots the GPT before writing and refuses to run if the partition table
does not look like a KE7.

---

## 2. Root

Root was needed to read vendor partitions and to toggle the modem AT channel.

- **Magisk 27** patched `boot.img`, flashed to `boot`.
- Verified with `su -c id` → `uid=0(root) ... context=u:r:magisk:s0`.
- The Magisk app is hidden/renamed to survive the debloat.

---

## 3. Wi-Fi MAC

After the NVRAM wipe the Wi-Fi MAC was random on every boot. The Transsion
connectivity daemon reads a MAC from a file:

```bash
printf '02:00:00:00:00:01' > /data/vendor/macwifi   # locally administered
chmod 644 /data/vendor/macwifi
```

The daemon logs `[WLAN-ASSISTANT] MAC ADDR = ...` and `wlan0` keeps the address
across reboots. Use any **locally administered** address (`02:` prefix) — do not
clone someone else's MAC.

---

## 4. Debloat

The retail ROM ships **265 packages**. We removed **75** per user, leaving **190**,
using the reversible form:

```bash
pm uninstall --user 0 <package>     # reversible
pm install-existing --user 0 <package>
```

`--user 0` removes the app for the current user without touching the system image, so
a factory reset (or `install-existing`) brings it back.

### What was removed

Transsion bloat (app store, themes, game center, "phone master", cloud, feedback,
duplicate galleries/music), Google apps that duplicated functionality, and unused
system services. The full list is in
[`reference/project-log.md`](reference/project-log.md) §42–45.

### What was kept

- **Play Store** (user requirement)
- **Gboard**
- Contacts, Phone/Telecom, Camera, Files, Settings
- Fossify Messages (replaces the stock SMS app)

### Things that broke and had to be restored

| Package | Symptom | Fix |
|---|---|---|
| `com.hoffnung` | system UI instability | `pm install-existing --user 0 com.hoffnung` |
| `com.transapplock` | app-lock service crash loop | restore |

Lesson: Transsion ROMs have hidden dependencies between "obvious bloat" and system
UI. Remove in small batches and reboot between batches.

---

## 5. Dialer

The retail ROM's dialer was **absent from `/system`** (not merely disabled): no
package owned `android.intent.action.DIAL`, while `com.android.incallui`,
`com.android.server.telecom` and `com.android.phone` were present.

Installed **Fossify Phone** (FOSS, ~9 MB):

```bash
adb install -r -g fossify_phone.apk
adb shell cmd role add-role-holder android.app.role.DIALER org.fossify.phone
```

Verify:

```bash
adb shell dumpsys telecom | grep -i incall      # User 0: org.fossify.phone
adb shell cmd package query-activities -a android.intent.action.DIAL
```

> `cmd telecom get-default-dialer` and `cmd role get-role-holders` are not
> implemented on this build — use `dumpsys telecom` instead.

---

## 6. Performance notes

- Replacing the HiOS launcher with **ap15** and trimming GApps cut idle RAM
  noticeably; the 4 GB device is comfortable with the reduced package set.
- Disabling the HiOS launcher (`com.transsion.hilauncher`) is safe once another
  launcher is the default.
- The vendor HWC cannot be replaced by a generic one on this ROM (answered
  definitively in [`reference/project-log.md`](reference/project-log.md) §47).

---

## 7. What Android gave the Linux port

| Artifact | Use |
|---|---|
| `/sys/firmware/fdt` | decompiled vendor device tree (`dts/vendor-stock.dts`) |
| `dmesg`, `/proc/interrupts` | driver names, IRQ numbers, register bases |
| HAL dumps | sensor/camera/audio inventory |
| `md1img` + NV files | modem protocol and IMEI layout research |
| META path | the IMEI restore itself |

Once the IMEI was restored and the hardware map complete, the phone was re-flashed
with U-Boot and Linux.
