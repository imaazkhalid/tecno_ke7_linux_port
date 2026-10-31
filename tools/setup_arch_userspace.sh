#!/bin/bash
set -e
DIR="$(cd "$(dirname "$0")/.." && pwd)"
ADB="$DIR/platform-tools/adb"
FASTBOOT="$DIR/platform-tools/fastboot"
PUBKEY=$(cat ~/.ssh/id_ed25519.pub 2>/dev/null || true)

echo "[*] Waiting for TWRP (ADB) connection..."

while true; do
    ADB_DEV=$($ADB devices 2>/dev/null | grep -v "List" | grep "recovery" | awk '{print $1}')
    if [ -n "$ADB_DEV" ]; then
        echo "[+] Found TWRP ADB device: $ADB_DEV"
        break
    fi

    FB_DEV=$($FASTBOOT devices 2>/dev/null | awk '{print $1}')
    if [ -n "$FB_DEV" ]; then
        echo "[+] Found Fastboot device: $FB_DEV, rebooting to recovery..."
        $FASTBOOT reboot recovery
        sleep 4
    fi

    sleep 0.5
done

echo "[*] Mounting Arch Linux rootfs (/dev/block/mmcblk0p43) at /mnt/arch_root..."
$ADB shell "mkdir -p /mnt/arch_root && mount -t ext4 /dev/block/mmcblk0p43 /mnt/arch_root"

echo "[*] 1. Setting up Auto-Login on tty1..."
$ADB shell "mkdir -p /mnt/arch_root/etc/systemd/system/getty@tty1.service.d"
$ADB shell 'cat << "EOF" > /mnt/arch_root/etc/systemd/system/getty@tty1.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I $TERM
EOF'

echo "[*] 2. Setting up static USB gadget networking (172.16.42.2)..."
$ADB shell "mkdir -p /mnt/arch_root/etc/systemd/network"
$ADB shell 'cat << "EOF" > /mnt/arch_root/etc/systemd/network/20-wired.network
[Match]
Name=usb* eth* en*

[Network]
Address=172.16.42.2/24
Gateway=172.16.42.1
DNS=8.8.8.8
DNS=1.1.1.1
EOF'

$ADB shell "mkdir -p /mnt/arch_root/etc/systemd/system/multi-user.target.wants"
$ADB shell "ln -sf /usr/lib/systemd/system/systemd-networkd.service /mnt/arch_root/etc/systemd/system/multi-user.target.wants/"
$ADB shell "ln -sf /usr/lib/systemd/system/systemd-resolved.service /mnt/arch_root/etc/systemd/system/multi-user.target.wants/"
$ADB shell "echo 'nameserver 8.8.8.8' > /mnt/arch_root/etc/resolv.conf"

echo "[*] 3. Configuring SSH & Injecting Host Public Key..."
$ADB shell "mkdir -p /mnt/arch_root/root/.ssh && chmod 700 /mnt/arch_root/root/.ssh"
if [ -n "$PUBKEY" ]; then
    $ADB shell "echo '$PUBKEY' > /mnt/arch_root/root/.ssh/authorized_keys"
    $ADB shell "chmod 600 /mnt/arch_root/root/.ssh/authorized_keys"
fi

$ADB shell "mkdir -p /mnt/arch_root/etc/ssh"
$ADB shell "sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /mnt/arch_root/etc/ssh/sshd_config 2>/dev/null || true"
$ADB shell "sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /mnt/arch_root/etc/ssh/sshd_config 2>/dev/null || true"
$ADB shell "ln -sf /usr/lib/systemd/system/sshd.service /mnt/arch_root/etc/systemd/system/multi-user.target.wants/"

echo "[*] 4. Installing Novatek Touchscreen firmware..."
$ADB shell "mkdir -p /mnt/arch_root/usr/lib/firmware"
$ADB push "$DIR/ke7_dump/vendor/firmware/novatek_ts_fw.bin" /mnt/arch_root/usr/lib/firmware/novatek_ts_fw.bin
$ADB push "$DIR/ke7_dump/vendor/firmware/novatek_ts_mp.bin" /mnt/arch_root/usr/lib/firmware/novatek_ts_mp.bin 2>/dev/null || true

echo "[*] 5. Syncing and unmounting..."
$ADB shell "sync"
$ADB shell "umount /mnt/arch_root || true"

echo "[+] Configuration complete! Device will reboot into Arch Linux..."
$ADB reboot
echo "[+] Device rebooted!"
