#!/usr/bin/env bash
# Boot the phone into Linux (U-Boot -> systemd-boot -> SD rootfs).
#
# THE BOOT SET IS ATOMIC. Six partitions must always be written together.
# Writing any subset produces a preloader reset loop (black screen, 0e8d:2000
# every ~2 s) because LK validates `boot` against `vbmeta`.
#
#   lk p27 | lk2 p28 | boot p30 | vbmeta p34 | vbmeta_system p35 | vbmeta_vendor p36
#
# Usage:  ./tools/boot-to-linux.sh
# Then:   hold Volume Up, plug the cable, wait for "reset".
set -euo pipefail
cd "$(dirname "$0")/.."

B=backup/arch_state_20261025
PY=./mtk-venv/bin/python
MTK=mtkclient/mtk.py

need() { [ -f "$1" ] || { echo "MISSING: $1" >&2; exit 1; }; }
for f in mmcblk0p27.bin mmcblk0p28.bin mmcblk0p30.bin \
         mmcblk0p34.bin mmcblk0p35.bin mmcblk0p36.bin; do
  need "$B/$f"
done

echo "== Linux boot set =="
printf '  %-14s %s\n' lk vbmeta lk2 boot
sha256sum "$B"/mmcblk0p27.bin "$B"/mmcblk0p28.bin "$B"/mmcblk0p30.bin \
          "$B"/mmcblk0p34.bin "$B"/mmcblk0p35.bin "$B"/mmcblk0p36.bin

echo
echo "Refusing to continue unless the phone is in BROM (0e8d:0003)."
echo "Enter BROM: hold Volume Up, plug the cable."
read -r -p "Press Enter when ready, or Ctrl-C to abort. " _

# Only one USB poller may exist. This one is it.
"$PY" -u "$MTK" multi "\
w lk $B/mmcblk0p27.bin;\
w lk2 $B/mmcblk0p28.bin;\
w boot $B/mmcblk0p30.bin;\
w vbmeta $B/mmcblk0p34.bin;\
w vbmeta_system $B/mmcblk0p35.bin;\
w vbmeta_vendor $B/mmcblk0p36.bin;\
reset"

echo
echo "All six written. Unplug and replug to boot."
echo "Expect: 0e8d:2000 -> 1d6b:0104 (Linux gadget), then  ssh root@172.16.42.2"
