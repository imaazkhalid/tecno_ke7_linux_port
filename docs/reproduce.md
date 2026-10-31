# Reproduce the port — from any device state

This is the master guide. It assumes **no prior work** and covers three starting
points:

- **A.** the phone still boots stock Android;
- **B.** the phone is bricked (bootloop, black screen, no fastboot);
- **C.** the NVRAM/factory partitions are wiped (no IMEI, no calibration).

Work through the sections in order. Every checkpoint tells you what you should see
before continuing.

---

## 0. Before you start

### Risks you accept

- Unlocking wipes the device and voids the warranty.
- Writing the wrong partition can brick the phone **permanently**.
- MTK devices have one truly fatal failure: a bad **preloader**. This guide never
  touches it.
- Restoring an IMEI is legal only for a device you own, and is regulated in some
  countries — see [legal.md](legal.md).

### What you need

| Item | Notes |
|---|---|
| A Linux host | Arch/Debian both fine; Windows works only through WSL for mtkclient |
| `python3` + `pip` | for mtkclient |
| `mtkclient` | `git clone https://github.com/bkerler/mtkclient` |
| `adb` / `fastboot` | Android platform-tools |
| `aarch64-linux-gnu-` toolchain | kernel + U-Boot cross compiler |
| `dtc` | device-tree compiler |
| A USB **data** cable | many cables are charge-only |
| Patience | the first flash takes ~30 minutes |

### Clone this repository

```bash
git clone https://github.com/<you>/tecno-spark-6-linux
cd tecno-spark-6-linux
```

Lay out the working tree the scripts expect:

```
tecno-spark-6-linux/
├── linux/            # mainline kernel tree (you clone it)
├── u-boot/           # U-Boot tree (you clone it)
├── mtkclient/        # mtkclient (you clone it)
├── firmware/         # your stock firmware (never committed)
├── flash_images/     # images you build/flash (never committed)
└── backup/           # your partition dumps (never committed)
```

---

## 1. Identify the state of your phone

| Symptom | State | Start at |
|---|---|---|
| Boots Android normally | A | §3 |
| Bootloop / black screen, but USB shows `0e8d:0003` | B | §2 |
| Boots but `*#06#` is empty, Wi-Fi MAC changes every boot | C | §2 → §5 |
| Already has a custom bootloader / Linux | — | §6 |

Check what the USB port sees:

```bash
lsusb | grep -i mediatek
# 0e8d:0003  BootROM      -> recoverable, always
# 0e8d:2000  preloader    -> recovery window (~2 s)
# 0e8d:202d  META         -> modem tool mode
# 0e8d:201c  Android/adb  -> normal boot
```

---

## 2. Recover from any state

### 2.1 Enter BROM

1. Power the phone off (hold Power ~10 s).
2. Hold **Volume Up** (on the current retail bootloader; older builds used
   Volume Up + Volume Down).
3. Plug the USB cable.
4. Release when `lsusb` shows `0e8d:0003`.

If this never works, the preloader may be dead — a test-point short is the last
resort (out of scope here).

### 2.2 Back up everything first

> **Project rule:** run [`../tools/save-state.sh`](../tools/save-state.sh) before
> **every** write operation (flash, `dd`, fastboot). It snapshots boot, recovery,
> both vbmetas, misc, seccfg, boot_para, proinfo and the NV partitions with a
> SHA-256 manifest. Rolling back then costs one `dd`, instead of reflashing stock
> and losing root/Magisk modules/IMEI provisioning.

```bash
mkdir -p backup
python3 mtkclient/mtk.py printgpt | tee backup/gpt_before.txt

# the partitions you must never lose
for p in boot_para proinfo nvram nvdata nvcfg persist protect1 protect2 \
         seccfg otp flashinfo tkv lk lk2 md1img; do
  python3 mtkclient/mtk.py r "$p" "backup/$p.bin"
done
```

Verify the GPT lists `userdata`, `super`, `nvram`, `otp` and `flashinfo`.

### 2.3 Unlock the bootloader (once)

```bash
./tools/unlock_device.sh        # writes seccfg + disabled vbmeta
```

The phone now shows **"orange state"** at every boot. That is expected and correct.

> Never re-lock. Re-locking with modified partitions is the classic permanent brick.

### 2.4 Flash the stock ROM (state B, or to start clean)

```bash
# put the retail firmware files in firmware/stock_retail/bin/ first
./tools/flash_retail.sh
```

The script writes only Android partitions and refuses to touch the preloader,
`seccfg`, NV partitions and factory data. It also snapshots the GPT first.

Checkpoint: the phone boots Android, shows the Tecno logo, and `adb devices` lists it.

### 2.5 Restore IMEI and calibration (state C)

Only if `*#06#` is empty. Full procedure: [imei-restore.md](imei-restore.md).

Short version:

1. `python3 tools/meta_handshake.py 300`, then plug the powered-off phone.
2. Confirm `0e8d:202d`.
3. Run the vendor IMEI tool in a Windows VM with
   [`tools/SN_Setup.patched.ini`](../tools/SN_Setup.patched.ini) and the one-byte TEE
   bypass.
4. Verify with `adb shell "su -c 'service call iphonesubinfo 1'"`.

Checkpoint: the SIM registers (`IN_SERVICE`) and `*#06#` shows both IMEIs.

---

## 3. Prepare the phone for Linux

### 3.1 Choose your layout

The reference layout repurposes the Android `userdata` area:

| Partition | Size | Use |
|---|---|---|
| `p40` | 512 MB | ESP (vfat), systemd-boot + kernel + DTB |
| `p41` | rest | Arch Linux ARM rootfs (ext4) |

Partition numbers **depend on your GPT**. Always confirm with:

```bash
python3 mtkclient/mtk.py printgpt
```

### 3.2 Back up the current Android state

```bash
python3 mtkclient/mtk.py r boot backup/boot_android.img
python3 mtkclient/mtk.py r super backup/super_android.img   # large
```

### 3.3 Create the partitions

Use `parted`/`sgdisk` from a Linux live environment, from Android with root, or from
TWRP. The rule is simple: **do not touch anything before `userdata`** except the
partitions you intend to replace (`boot` for U-Boot).

```bash
# example, from a root shell on the device or TWRP
sgdisk --new=40:0:+512M --change-name=40:esp   /dev/mmcblk0
sgdisk --new=41:0:0     --change-name=41:rootfs /dev/mmcblk0
mkfs.vfat -n ESP /dev/mmcblk0p40
mkfs.ext4 -L root /dev/mmcblk0p41
```

Checkpoint: `blkid` shows `ESP` (vfat) and `root` (ext4).

---

## 4. Install Arch Linux ARM

Download the **aarch64** rootfs tarball from `archlinuxarm.org` and extract it onto
the rootfs partition:

```bash
mount /dev/mmcblk0p41 /mnt
tar -xpf ArchLinuxARM-aarch64-latest.tar.gz -C /mnt
mount /dev/mmcblk0p40 /mnt/boot/efi
```

The ESP must contain:

```
/EFI/systemd/systemd-bootaa64.efi
/EFI/BOOT/BOOTAA64.EFI          (copy of the above)
/loader/loader.conf
/loader/entries/arch.conf
/vmlinuz-linux
/mt6768-tecno-ke7.dtb
/mt6768.dtb                     (same file, second name U-Boot looks for)
```

---

## 5. Build and flash U-Boot

```bash
git clone https://source.denx.de/u-boot/u-boot.git
cd u-boot
make ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- mt6768_ke7_defconfig
make ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc)
```

The KE7-specific hooks live in
`arch/arm/mach-mediatek/mt6768/init.c`:

- copy LK's `/chosen/ccci,*` properties into the Linux DTB;
- write `0x21` to `INFRA_AO_MD_SRCCLKENA` (`0x10001000 + 0xF0C`) **before** the modem
  starts (this is the HS2 fix).

Pack the result as an Android boot image with an AVB footer and flash it to `boot`
(p30). Helper: [`../tools/flash_lk.sh`](../tools/flash_lk.sh).

Checkpoint: the phone boots to a U-Boot prompt / EFI boot menu with the display on.

> If U-Boot does not start, restore the stock `boot` image from
> `backup/boot_android.img` and re-check the packing.

---

## 6. Build the kernel and DTB

```bash
git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
cd linux
# apply the KE7 DT (or copy the DTS from this repo and adapt)
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) Image dtbs
```

The board DTS is based on [`../dts/ke7_mt6768.dts`](../dts/ke7_mt6768.dts) with the
porting fragments in [`../dts/`](../dts). Deploy:

```bash
scp arch/arm64/boot/Image root@172.16.42.2:/boot/vmlinuz-linux
scp arch/arm64/boot/dts/mediatek/mt6768-tecno-ke7.dtb root@172.16.42.2:/boot/mt6768-tecno-ke7.dtb
ssh root@172.16.42.2 'cp /boot/mt6768-tecno-ke7.dtb /boot/mt6768.dtb'
```

Boot entry (`/boot/efi/loader/entries/arch.conf`):

```ini
title   Arch Linux ARM
linux   /vmlinuz-linux
devicetree /mt6768-tecno-ke7.dtb
options root=PARTUUID=<rootfs-partuuid> rw console=tty0
```

Checkpoint: the kernel boots, the console appears on the panel, and the rootfs mounts.

---

## 7. First boot and userspace

### 7.1 USB gadget networking

```bash
ip link set usb0 up
ip addr add 172.16.42.2/24 dev usb0
# host side
sudo ip addr add 172.16.42.1/24 dev enp0s20f0u3
```

On the host, `ssh root@172.16.42.2` should work.

### 7.2 Internet through the laptop

```bash
python3 tools/fast_proxy.py          # host, port 8080
# on the phone
export http_proxy=http://172.16.42.1:8080 https_proxy=http://172.16.42.1:8080
```

### 7.3 Charging at 1.5 A

```bash
echo 1500000 > /sys/class/power_supply/charger/input_current_limit
```

Persist it with a udev rule (see [linux-bringup.md](linux-bringup.md#charging)).

### 7.4 Phosh

```bash
pacman -S phosh phoc gnome-console
systemctl enable --now phosh
```

If GNOME Console shows an infinite spinner, source `/etc/profile.d/vte.sh` at the
end of `~/.bashrc` and `/etc/bash.bashrc`.

---

## 8. Modem

Only after the system is stable:

1. Build the driver: `cd cellular-port && make -C ../linux M=$PWD ... modules`
2. `systemctl stop ModemManager && modprobe ccci`
3. Run `tools/ccci_mdinit.py` and watch `/sys/kernel/ccci/boot` for `md1:2`.
4. Start `tools/ccci_fsd.py` for the modem filesystem.

Details and the HS2 bug: [modem.md](modem.md).

---

## 9. Verification checklist

| Check | Command | Expected |
|---|---|---|
| Boot chain | — | U-Boot splash → systemd-boot → kernel log |
| Display | — | 720×1640 console / Phosh |
| Touch | `cat /proc/bus/input/devices` | `mtk-tpd` present |
| USB net | `ip addr show usb0` | `172.16.42.2/24` |
| Charging | `cat /sys/class/power_supply/charger/online` | `1` |
| Battery | `upower -i ...` or sysfs | sane voltage/percent |
| Modem | `cat /sys/kernel/ccci/boot` | `md1:2` |
| Panel ID | `dmesg | grep -i nt36525` | panel probed (after DRM driver) |

---

## 10. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Nothing on USB, no `0e8d` | dead battery / charge-only cable | charge 30 min, try another cable |
| `0e8d:0003` but mtkclient fails | another process holds the port | close ModemManager/browser, replug |
| Bootloop after flashing U-Boot | bad AVB footer or wrong partition | restore `backup/boot_android.img` |
| Black screen, kernel alive over USB | SimpleFB not handed over | check U-Boot GOP / LK handover |
| No touch | SPI node or reset GPIO wrong | verify IRQ and `reset-gpios` |
| Modem stuck at `md1:3` | EINT clock gated | apply the U-Boot SRCCLKENA fix |
| `Illegal ME` on network | IMEI missing/invalid | [imei-restore.md](imei-restore.md) |
| Wi-Fi MAC changes each boot | MAC file missing | [android.md](android.md#3-wi-fi-mac) |
| USB net dies after reboot | gadget does not re-attach | unplug/replug the cable |

---

## 11. What to read next

- Every experiment behind this guide: [`reference/project-log.md`](reference/project-log.md)
- Register-level details: [`reference/hardware-research.md`](reference/hardware-research.md)
- Board map: [hardware.md](hardware.md)
- Legal boundaries: [legal.md](legal.md)
