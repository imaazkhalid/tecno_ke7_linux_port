# Firmware: what you need and how to verify it

> **No firmware is hosted in this repository.** Vendor images are copyrighted and
> redistributing them is not something we can do. What we *can* give you is the exact
> build identification, the file manifest with **SHA-256 checksums**, and a verifier —
> so the image you download is provably the one this project was built against.
>
> **Where to get it:** see [sources.md](sources.md) for mirrors and provenance.

---

## 1. Exact build

| Item | Value |
|---|---|
| Device | Tecno Spark 6 (KE7 / `KE7 JS1`) |
| Build | **`KE7-H693HJKM-Q-GL-220729V478`** |
| Region | GL (global) |
| Android | 10 |
| SoC | MT6768 / Helio G70 |

This is the **retail** build. Other KE7 variants (e.g. `H693GHIJKM`, different
regions) use different images — do not mix partitions between builds.

## 2. How to obtain it

The build is no longer distributed by Tecno. Public firmware mirrors still carry it;
search for the exact build string `KE7-H693HJKM-Q-GL-220729V478`, or for
`Tecno KE7 firmware`. The copy used here came from **MobiFirmware.com**.

Prefer archives that contain the **full scatter/partition set**, not just
`boot.img` — a bricked phone needs `super`, `md1img`, `lk` and the vbmeta set.

## 3. Manifest (SHA-256)

Verify your download before flashing:

```bash
./tools/verify_firmware.sh firmware/stock_retail/bin
```

| File | Bytes | SHA-256 | Target |
|---|---:|---|---|
| `boot.img` | 33,554,432 | `56220382e730e85a3cc49afec1c53ab768020ba71fc9f0deed7187749a4a36f4` | `boot` |
| `recovery.img` | 33,554,432 | `e35e38d0494be5c7674591ebe925202c7ffce6e01c63891910152e603cc60433` | `recovery` |
| `dtbo.img` | 71,728 | `1b4b7dbc59063621d7d4ddcda357de00846ff16af6b4bfe4ae276ae8600595e8` | `dtbo` |
| `lk.img` | 1,114,976 | `f977f6ef957960e9c19f08e889af1e5b9bf58366623ad7988ef37b8a1efedeed` | `lk` / `lk2` |
| `md1img.img` | 57,014,816 | `0ee98c40f275a66f193ee310f3e6695324f3e14d50e03965d620aaf5e3da872f` | `md1img` |
| `scp.img` | 556,304 | `35c84d2adb100b8149f9ac63ae9e660db035aa28ce6aedbd915211f676259a51` | `scp1` / `scp2` |
| `sspm.img` | 503,728 | `bfa5e6d9e92806646b283811c0b8e6964ef9e2c90b379a469b56f4accee88163` | `sspm_1` / `sspm_2` |
| `spmfw.img` | 37,984 | `739cb96753135aa9b09dcd26d4178615cad727909c16c553e37ffec61937cf29` | `spmfw` |
| `tee.img` | 2,276,064 | `aa7f4f77614d795d0922a4728431c442d6c12115029e9a1aa731bc8f93e42793` | `tee1` / `tee2` |
| `vbmeta.img` | 4,096 | `a712098cf1400073042e8fab38f03fc352522f9ca9dc9049e0e425b7532e601f` | `vbmeta` |
| `vbmeta_system.img` | 4,096 | `1d39329b8b8fe5e862bb186d73b704dae3b4dd7831467b33f99df4b0631776aa` | `vbmeta_system` |
| `vbmeta_vendor.img` | 4,096 | `3980ec5991e7e2f3077bd824fb9e132e8c6fa863aae72507f632c42047ea3f06` | `vbmeta_vendor` |
| `logo.bin` | 1,568,544 | `a3743b474d0f6808f4ae2ff1169c5d3964c0d9d1e458d7d25aa3f2d70aaf9db2` | `logo` |
| `cache.raw` | 314,572,800 | `021dbf8b3a14bbf1f0fed8ea110afceca8b73096faa858cf229509627239a489` | `cache` |
| `tranfs.raw` | 314,572,800 | `f8f7c35b804aad36c83a10c351985b05c2e99f276b89e46b3e31d6f031cce526` | `tranfs` |
| `zero4m.bin` | 4,194,304 | `bb9f8df61474d25e71fa00722318cd387396ca1736605e1248821cc0de3d3af8` | helper (zeros) |

A full flash also needs the **`super`** image (the dynamic-partition container with
`system`, `vendor`, `product`). It is large and comes as `super.img`/`super.raw` in
the same archive; its hash depends on the repack, so verify it against the archive
you downloaded rather than the table above.

## 4. What you must never flash

| Partition | Why |
|---|---|
| `boot0` / `boot1` (preloader) | only truly unrecoverable brick on MTK |
| `seccfg` | write once to unlock; never re-lock |
| `otp`, `flashinfo`, `tkv` | factory-unique, no way to regenerate |
| `nvram`, `nvdata`, `nvcfg`, `persist`, `protect1/2` | calibration + IMEI; restoring from another phone does not work |

[`../tools/flash_retail.sh`](../tools/flash_retail.sh) enforces this list.

## 5. If you are bricked with only BROM

You can recover **without** any special file beyond the firmware archive:

1. Enter BROM (`0e8d:0003`).
2. Back up what is left: [`../tools/backup-partitions.sh`](../tools/backup-partitions.sh).
3. Flash the retail set with [`../tools/flash_retail.sh`](../tools/flash_retail.sh).
4. Boot Android and check `*#06#`.
5. If the IMEI is empty, follow [imei-restore.md](imei-restore.md).

The GPT itself can be restored from a backup taken by `backup-partitions.sh`
(`pgpt` / `sgpt` images). Keep that backup — it is the only thing that can save a
device with a destroyed partition table.

## 6. If your build is different

Do **not** mix images from different builds. The safest path is:

- flash the *whole* set from one archive (same build string);
- keep your own `nvram`/`nvdata`/`persist` untouched;
- re-do the Linux port from your own DTS (`tools/extract-hardware.sh` produces it).

The port itself (U-Boot patch, kernel patch, mainline DTS) is build-independent: it
only depends on the SoC and the board wiring, which are the same across KE7
variants.
