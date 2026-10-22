#!/usr/bin/env python3
import os
import sys
import time
import subprocess

print("[*] Real-time USB Monitor started. Waiting for device connection...", flush=True)

# Read initial USB devices
def get_usb_devs():
    devs = {}
    base = "/sys/bus/usb/devices"
    if not os.path.isdir(base):
        return devs
    for entry in os.listdir(base):
        dpath = os.path.join(base, entry)
        id_vendor = os.path.join(dpath, "idVendor")
        id_product = os.path.join(dpath, "idProduct")
        if os.path.isfile(id_vendor) and os.path.isfile(id_product):
            try:
                with open(id_vendor, 'r') as f:
                    vid = f.read().strip()
                with open(id_product, 'r') as f:
                    pid = f.read().strip()
                
                mfg = ""
                prod = ""
                mfg_file = os.path.join(dpath, "manufacturer")
                prod_file = os.path.join(dpath, "product")
                if os.path.isfile(mfg_file):
                    try:
                        with open(mfg_file, 'r') as f:
                            mfg = f.read().strip()
                    except Exception:
                        pass
                if os.path.isfile(prod_file):
                    try:
                        with open(prod_file, 'r') as f:
                            prod = f.read().strip()
                    except Exception:
                        pass
                
                devs[entry] = {"vid": vid, "pid": pid, "mfg": mfg, "prod": prod, "path": dpath}
            except Exception:
                pass
    return devs

known = get_usb_devs()
print(f"[*] Currently connected USB devices: {len(known)}", flush=True)
for k, v in known.items():
    print(f"    - [{k}] {v['vid']}:{v['pid']} | {v['mfg']} {v['prod']}", flush=True)

print("\n[READY] Please connect your Tecno Spark 6 (KE7) now!", flush=True)

last_check = time.time()
while True:
    time.sleep(0.2)
    current = get_usb_devs()
    # Check for newly added devices
    for k in current:
        if k not in known:
            v = current[k]
            print(f"\n[+] NEW DEVICE DETECTED!", flush=True)
            print(f"    Port/Bus: {k}", flush=True)
            print(f"    VID:PID : {v['vid']}:{v['pid']}", flush=True)
            print(f"    Vendor  : {v['mfg']}", flush=True)
            print(f"    Product : {v['prod']}", flush=True)
            
            # Check for MediaTek signatures
            if v['vid'].lower() == "0e8d":
                if v['pid'].lower() in ["0003", "2000"]:
                    print(f"    >>> DETECTED MEDIATEK BROM/PRELOADER (VID=0e8d, PID={v['pid']})! <<<", flush=True)
                else:
                    print(f"    >>> MediaTek Device detected (PID={v['pid']}) <<<", flush=True)
    # Check for removed devices
    for k in known:
        if k not in current:
            v = known[k]
            print(f"\n[-] Device disconnected: [{k}] {v['vid']}:{v['pid']} ({v['prod']})", flush=True)
            
    known = current
