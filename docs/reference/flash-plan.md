# FLASH PLAN — return to stock Android, keep the orange state

**Goal:** flash genuine Tecno KE7 stock Android 10 (`KE7-H693GHIJKM-Q-GL-200617V060`),
bootloader stays **unlocked**, then root and mine the working system.

**Source image:** `firmware/KE7_stock_200617V060.zip` (2,636,943,405 B, MediaFire / mobileguru4).

**Current-state backup (authoritative):** `backup/arch_state_20261025/`
* `gpt_primary.bin`, `gpt_backup.bin`
* `mmcblk0p01..p36, p40, p41, p42` raw
* `mmcblk0boot0.bin`, `mmcblk0boot1.bin` (preloader + AND_ROMINFO/AND_SECCTRL/AND_SECRO), md5 `a7e48ea8…`
* `rootfs.tar.zst`, `esp.tar.zst`

---

## 1. Partitions we must NOT flash

| Partition | Why |
|---|---|
| **`seccfg` (p16)** | holds the **unlock state** ("orange state"). Flashing the stock one re-locks the bootloader. |
| **preloader (eMMC `boot0`/`boot1`)** | contains the device-unique `AND_SECRO` hash (`1A52A367CB12C458…`). Flashing another unit's preloader can break boot and is never needed here. |
| `nvram` / `nvdata` / `protect1/2` / `persist` | RF calibration + IMEI live here. Keep the device's own (even if partly erased, ours is the only one tied to this unit). Flash only if the ROM forces it. |
| `otp`, `flashinfo` | one-time-programmable / factory info. Never flash. |

Everything else (boot, recovery, dtbo, super, vbmeta*, md1img, scp, sspm, spmfw, tee, gz, lk/lk2,
logo, misc, metadata, cache, tranfs, userdata) can come from the stock package.

> If the stock `PGPT` is flashed it will recreate the original `userdata` layout and **destroy our
> `esp`/`rootfs` partitions** — that is expected; both are backed up.

## 2. BROM entry (Kamakiri)

1. Phone **powered off** (not rebooted — power off, then wait 5 s).
2. Hold **Volume Down** (if that fails, try **Volume Up**, and both).
3. Plug the USB cable into the laptop while holding the key.
4. Verify enumeration:
   ```bash
   lsusb | grep -i 0e8d        # expect 0e8d:0003 (BROM) — 0e8d:2000 means preloader, not BROM
   ```
5. Run mtkclient from the venv:
   ```bash
   cd ~/tecno_ke7_linux_port
   mtk-venv/bin/python mtkclient/mtk.py printgpt
   ```
   Kamakiri runs automatically for MT6768; `--stock` is **not** used (we bypass the vendor DA).

## 3. Flash sequence

```bash
cd ~/tecno_ke7_linux_port
M="mtk-venv/bin/python mtkclient/mtk.py"

# 0) sanity: current GPT from the device, before touching anything
$M printgpt > firmware/device_gpt_before_stock.txt

# 1) optional: stock partition table (creates the original userdata layout)
$M w pgpt   firmware/stock/PGPT.bin
$M w pgpt_backup firmware/stock/PGPT.bin      # only if the package provides one

# 2) main images (names per the scatter file)
for p in boot recovery dtbo super vbmeta vbmeta_system vbmeta_vendor \
         md1img scp spmfw sspm tee gz1 gz2 lk lk2 logo misc metadata cache tranfs; do
  [ -f firmware/stock/$p.img ] && $M w $p firmware/stock/$p.img
done

# 3) NEVER: seccfg, preloader/boot0/boot1, nvram, nvdata, protect1/2, persist, otp, flashinfo

$M reset
```

Notes:
* `mtkclient` names may differ per package (`vbmeta.img`, `vbmeta_system.img`, `md1img.img`, …).
  Always list the extracted directory first and map by the **scatter file**, not by guesswork.
* If a write fails with an auth/SLA error, retry with `--auth` / a matching DA — but Kamakiri
  should bypass it on this SoC.
* Writing `lk`/`lk2`/`boot` normally needs BROM on a locked unit; this is exactly why we use it.

## 4. First boot

* Expect the **orange state** warning (still unlocked) — that is the desired state.
* Let Android boot fully once (it will format `userdata` and rebuild `/data`).
* If it bootloops: capture `adb logcat` / `adb shell dmesg`, or re-enter BROM and inspect.

## 5. Root

1. Enable Developer options → USB debugging.
2. Get the stock `boot.img` (from the package) and patch it with Magisk (same version as the app).
3. `fastboot flash boot magisk_patched.img`
4. Disable verification (choose one):
   * `fastboot --disable-verity --disable-verification flash vbmeta vbmeta_disabled.img`, or
   * flash the patched vbmeta provided by the ROM.
5. Reboot, confirm `adb shell su -c id` → uid=0.

## 6. What to harvest from the rooted stock system

* `dmesg` from a **cold boot** with the modem working (the single most valuable artefact).
* `logcat -b all -d` (radio/system/main) for CCCI/MD bring-up.
* `/sys/kernel/debug/ccci/*`, `/proc/ccci*`, `/dev/ccci*`.
* `getprop | grep -i -E "radio|md|modem|rat"`.
* NVRAM: `AT+EGMR=0,7` (IMEI), `AT+EGMR=0,5`, and the NVDATA/NVRAM partition contents.
* MD/DSP power sequencing: any `md_cd_power_on`-equivalent log lines, `dmesg | grep -i -E "md1|md32|usip|dsp|topsm|srcclken"`.
* `/proc/device-tree/chosen/*` (LK's tags) — compare with ours byte-for-byte.
* Full `dmesg` + `logcat` + `/proc/config.gz` + `uname -a` + kernel cmdline.

## 7. Return to mainline later

1. BROM → restore `backup/arch_state_20261025/gpt_primary.bin` to the PGPT area.
2. `dd` back `p1..p36, p40, p41, p42`, `boot0`, `boot1`.
3. Untar `rootfs.tar.zst` to p43 and `esp.tar.zst` to p40.
4. Verify with the md5 table in `PROJECT_STATUS.md` §33.2.
