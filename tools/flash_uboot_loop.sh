#!/bin/bash
DIR="$(cd "$(dirname "$0")/.." && pwd)"
FASTBOOT="$DIR/platform-tools/fastboot"
ADB="$DIR/platform-tools/adb"
IMG="$DIR/boot-uboot.img"
LK="$DIR/flash_images/lk_patched.img"

echo "[*] Monitoring for TWRP (ADB) or Fastboot..."

while true; do
    # 1. Check ADB (TWRP)
    ADB_DEV=$($ADB devices 2>/dev/null | grep -v "List" | grep "recovery" | awk '{print $1}')
    if [ -n "$ADB_DEV" ]; then
        echo "[+] TWRP ADB detected: $ADB_DEV"

        echo "[*] Mounting ESP (/dev/block/mmcblk0p40)..."
        $ADB shell "mkdir -p /mnt/esp && mount -t vfat /dev/block/mmcblk0p40 /mnt/esp"

        echo "[*] Pushing updated mainline Linux 6.18 kernel & DTB..."
        $ADB push "$DIR/linux/arch/arm64/boot/Image" /mnt/esp/Image.mainline
        $ADB push "$DIR/linux/arch/arm64/boot/dts/mediatek/mt6768-tecno-ke7.dtb" /mnt/esp/mt6768-tecno-ke7.dtb
        $ADB shell "cp /mnt/esp/mt6768-tecno-ke7.dtb /mnt/esp/mt6768.dtb; cp /mnt/esp/Image.mainline /mnt/esp/Image; sync"

        echo "[*] Flashing boot-uboot.img to /dev/block/by-name/boot..."
        $ADB push "$IMG" /tmp/boot-uboot.img
        $ADB shell "dd if=/tmp/boot-uboot.img of=/dev/block/by-name/boot bs=1M && sync"

        echo "[+] Update complete! Rebooting device into Mainline Linux..."
        $ADB reboot
        echo "[+] Device rebooted! Done."
        exit 0
    fi

    # 2. Check Fastboot
    FB_DEV=$($FASTBOOT devices 2>/dev/null | awk '{print $1}')
    if [ -n "$FB_DEV" ]; then
        echo "[+] Fastboot device detected: $FB_DEV"
        echo "[*] Flashing lk and boot..."
        $FASTBOOT flash lk "$LK" 2>/dev/null
        $FASTBOOT flash lk2 "$LK" 2>/dev/null
        $FASTBOOT flash boot "$IMG"
        echo "[*] Rebooting to recovery for ESP sync..."
        $FASTBOOT reboot recovery
        sleep 3
    fi

    sleep 0.5
done
