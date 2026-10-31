#!/usr/bin/env bash
# Boot the phone into rooted Android.
#
# THIS DESTROYS THE LINUX BOOT SET. It overwrites vbmeta with the stock AVB
# image, which is what LK needs to accept the Android boot image -- and exactly
# what the port-era LK/U-Boot cannot survive. To go back to Linux, run
# ./tools/boot-to-linux.sh (all six partitions again).
#
# Writes: boot, recovery, vbmeta, vbmeta_system, vbmeta_vendor, misc (zeroed).
# super and userdata are NOT touched, so apps/settings survive.
#
# Usage:  ./tools/boot-to-android.sh [backup-dir]
set -euo pipefail
cd "$(dirname "$0")/.."

K="${1:-backup/known-good-rooted-20261031-124522}"
PY=./mtk-venv/bin/python
MTK=mtkclient/mtk.py

need() { [ -f "$1" ] || { echo "MISSING: $1" >&2; exit 1; }; }
for f in boot.img recovery.img vbmeta.img vbmeta_system.img vbmeta_vendor.img; do
  need "$K/$f"
done

ZERO=$(mktemp)
trap 'rm -f "$ZERO"' EXIT
head -c 6152192 /dev/zero > "$ZERO"   # misc size, zeroed

echo "== Android boot set from $K =="
sha256sum "$K"/boot.img "$K"/recovery.img "$K"/vbmeta.img \
          "$K"/vbmeta_system.img "$K"/vbmeta_vendor.img

echo
echo "WARNING: this replaces the Linux boot set (vbmeta goes back to stock AVB)."
echo "Enter BROM: hold Volume Up, plug the cable."
read -r -p "Press Enter when ready, or Ctrl-C to abort. " _

"$PY" -u "$MTK" multi "\
w boot $K/boot.img;\
w recovery $K/recovery.img;\
w vbmeta $K/vbmeta.img;\
w vbmeta_system $K/vbmeta_system.img;\
w vbmeta_vendor $K/vbmeta_vendor.img;\
w misc $ZERO;\
reset"

echo
echo "Done. Unplug and replug. Android should boot rooted (Magisk)."
echo "To return to Linux: ./tools/boot-to-linux.sh"
