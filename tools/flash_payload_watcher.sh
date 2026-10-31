#!/bin/bash
DIR="$(cd "$(dirname "$0")/.." && pwd)"
FASTBOOT="$DIR/platform-tools/fastboot"
ADB="$DIR/platform-tools/adb"
IMG="$DIR/u-boot-payload.img"
VENV="$DIR/venv/bin/python3"
MTK="$DIR/mtkclient/mtk.py"

echo "[*] Watcher active: Waiting for device connection (Fastboot, BROM, or ADB)..."
echo "[*] Hold Power + Volume Down now to reset into Fastboot mode."

while true; do
    # 1. Check Fastboot
    DEV=$($FASTBOOT devices 2>/dev/null | awk '{print $1}')
    if [ -n "$DEV" ]; then
        echo "[+] Fastboot device detected: $DEV"
        echo "[*] Flashing u-boot-payload.img (27.5 MB)..."
        $FASTBOOT flash boot "$IMG"
        echo "[+] Flash successful! Rebooting into U-Boot -> Arch Linux..."
        $FASTBOOT reboot
        exit 0
    fi

    # 2. Check ADB
    ADB_DEV=$($ADB devices 2>/dev/null | grep -v "List" | grep -E "recovery|device" | awk '{print $1}')
    if [ -n "$ADB_DEV" ]; then
        echo "[+] ADB device detected: $ADB_DEV, rebooting to bootloader..."
        $ADB reboot bootloader
        sleep 2
    fi

    # 3. Check for BROM / Preloader on USB
    if grep -q "0e8d" /sys/bus/usb/devices/*/idVendor 2>/dev/null; then
        echo "[+] MediaTek USB detected! Trying fastboot first..."
        DEV=$($FASTBOOT devices 2>/dev/null | awk '{print $1}')
        if [ -n "$DEV" ]; then
            echo "[+] Fastboot device detected: $DEV"
            $FASTBOOT flash boot "$IMG"
            $FASTBOOT reboot
            exit 0
        fi
    fi

    sleep 0.5
done
