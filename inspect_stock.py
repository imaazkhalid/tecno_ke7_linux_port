#!/usr/bin/env python3
"""inspect_stock.py — unpack and audit a Tecno/MTK SP-Flash-Tool package.

Usage:
  inspect_stock.py firmware/KE7_stock_200617V060.zip [--out firmware/stock]

Prints, per scatter entry: partition name, image file, declared size, region
(EMMC_USER / EMMC_BOOT_1 / EMMC_BOOT_2), whether it is downloaded, and whether
flashing it would destroy something we must keep (unlock state, preloader hash,
RF calibration).
"""
import argparse
import os
import re
import sys
import zipfile

# partitions that must NOT be flashed when we want to keep unlock + calibration
KEEP = {
    "seccfg": "bootloader unlock state (orange state)",
    "nvram": "RF calibration / IMEI",
    "nvdata": "RF calibration / IMEI",
    "protect1": "DRM / attestation keys",
    "protect2": "DRM / attestation keys",
    "persist": "sensor / wifi calibration",
    "otp": "one-time programmable",
    "flashinfo": "factory flash info",
    "proinfo": "product info",
    "boot_para": "boot parameters",
    "para": "boot parameters",
    "frp": "factory reset protection",
    "md_udc": "modem unique data",
    "tkv": "TEE key vault",
    "sec1": "security",
}
# a preloader always lives in an eMMC boot region
BOOT_REGIONS = ("EMMC_BOOT_1", "EMMC_BOOT_2", "BOOT_1", "BOOT_2")


def parse_scatter(path):
    entries, cur = [], {}
    for line in open(path, encoding="utf-8", errors="replace"):
        line = line.strip()
        m = re.match(r"-\s*([A-Za-z_0-9]+)\s*:\s*(.*)$", line)
        if not m:
            continue
        k, v = m.group(1), m.group(2).strip()
        if k == "partition_index":
            if cur:
                entries.append(cur)
            cur = {}
        cur[k] = v
    if cur:
        entries.append(cur)
    return entries


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("zipfile")
    ap.add_argument("--out", default="firmware/stock")
    args = ap.parse_args()

    z = zipfile.ZipFile(args.zipfile)
    names = z.namelist()
    # find scatter
    sc = [n for n in names if n.lower().endswith("scatter.txt")]
    print(f"archive entries: {len(names)}")
    if sc:
        print("scatter files:", sc)
    else:
        print("!! no scatter file in the archive; listing top-level files:")
        for n in names[:60]:
            print("   ", n, z.getinfo(n).file_size)
        return 0

    os.makedirs(args.out, exist_ok=True)
    print(f"\nextracting to {args.out} ...")
    z.extractall(args.out)

    print(f"\n{'partition':<18}{'region':<14}{'size':>12}  {'file':<28} flags")
    print("-" * 96)
    for e in parse_scatter(os.path.join(args.out, sc[0])):
        name = e.get("partition_name", "?")
        fn = e.get("file_name", "")
        region = e.get("region", "?")
        try:
            size = int(e.get("partition_size", "0"), 0)
        except ValueError:
            size = 0
        dl = e.get("is_download", "").lower() == "true"
        flags = []
        if not dl:
            flags.append("not-downloaded")
        if name in KEEP:
            flags.append("KEEP: " + KEEP[name])
        if region in BOOT_REGIONS and name != "preloader":
            flags.append("boot-region")
        if name == "preloader":
            flags.append("KEEP: preloader (device AND_SECRO hash)")
        fpath = os.path.join(args.out, os.path.dirname(sc[0]), fn) if fn else ""
        exists = "ok" if fpath and os.path.exists(fpath) else ("-" if not fn else "MISSING")
        print(f"{name:<18}{region:<14}{size:>12,}  {fn:<28} {exists} {' '.join(flags)}")

    print("\nfiles actually present:")
    tot = 0
    for root, _, files in os.walk(args.out):
        for f in sorted(files):
            p = os.path.join(root, f)
            tot += os.path.getsize(p)
            print(f"  {os.path.getsize(p):>12,}  {os.path.relpath(p, args.out)}")
    print(f"  total {tot:,} bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
