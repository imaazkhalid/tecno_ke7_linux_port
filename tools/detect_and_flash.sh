#!/bin/bash
FASTBOOT="$(cd "$(dirname "$0")/.." && pwd)/platform-tools/fastboot"
ADB="$(cd "$(dirname "$0")/.." && pwd)/platform-tools/adb"
VBMETA="$(cd "$(dirname "$0")/.." && pwd)/flash_images/vbmeta_disabled.img"

echo "[*] Watcher active: Waiting for phone connection..."
echo "[*] Please hold Volume Down on the phone now."

while true; do
    DEV=$($FASTBOOT devices 2>/dev/null | awk '{print $1}')
    if [ -n "$DEV" ]; then
        echo "[+] Fastboot device detected: $DEV"
        echo "[*] Flashing vbmeta_disabled..."
        $FASTBOOT --disable-verity --disable-verification flash vbmeta "$VBMETA"
        $FASTBOOT --disable-verity --disable-verification flash vbmeta_system "$VBMETA"
        $FASTBOOT --disable-verity --disable-verification flash vbmeta_vendor "$VBMETA"
        echo "[+] Successfully disabled AVB verification!"
        echo "[*] Rebooting into U-Boot..."
        $FASTBOOT reboot
        exit 0
    fi

    # Check for ADB recovery if volume up was pressed
    ADB_DEV=$($ADB devices 2>/dev/null | grep -v "List" | grep -E "recovery|device" | awk '{print $1}')
    if [ -n "$ADB_DEV" ]; then
        echo "[+] ADB device detected: $ADB_DEV"
        $ADB reboot bootloader
    fi

    sleep 0.5
done
