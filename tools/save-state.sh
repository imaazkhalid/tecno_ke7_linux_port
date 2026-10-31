#!/bin/bash
# save-state.sh — snapshot the phone's current working state to the laptop.
#
# Run this BEFORE every write/flash operation. Restoring is then a matter of
# writing the saved images back, instead of reflashing stock and losing root,
# Magisk modules, debloat state, IMEI-provisioned NV data, etc.
#
# Usage: ./tools/save-state.sh [label]
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
ADB="${ADB:-adb}"
LABEL="${1:-state}"
OUT="$REPO/backup/${LABEL}-$(date +%Y%m%d-%H%M%S)"
TMP="/sdcard/ke7backup"
mkdir -p "$OUT"

say() { printf "\n== %s\n" "$*"; }

say "device"
"$ADB" devices | sed -n '2p'
"$ADB" shell "su -c id" 2>/dev/null | grep -q uid=0 || { echo "!! root required"; exit 1; }

# partitions that define the current working state
PARTS="boot recovery vbmeta vbmeta_system vbmeta_vendor misc seccfg boot_para proinfo nvram nvdata nvcfg persist protect1 protect2"

"$ADB" shell "su -c 'rm -rf $TMP; mkdir -p $TMP'"
for p in $PARTS; do
  if "$ADB" shell "su -c 'test -e /dev/block/by-name/$p'" 2>/dev/null; then
    printf "   %-16s " "$p"
    "$ADB" shell "su -c 'dd if=/dev/block/by-name/$p of=$TMP/$p.img bs=1M 2>/dev/null'" >/dev/null 2>&1
    sz=$("$ADB" shell "su -c 'stat -c %s $TMP/$p.img'" 2>/dev/null | tr -d '\r')
    echo "$sz bytes"
  else
    echo "   $p (missing, skipped)"
  fi
done

"$ADB" shell "su -c 'sgdisk -p /dev/block/mmcblk0 > $TMP/gpt.txt 2>/dev/null; getprop > $TMP/getprop.txt'"

say "pulling to $OUT"
"$ADB" pull "$TMP/." "$OUT/" 2>&1 | tail -1
"$ADB" shell "su -c 'rm -rf $TMP'"

say "manifest"
( cd "$OUT" && sha256sum * > MANIFEST.sha256 )
ls -lh "$OUT" | tail -20
echo
echo "saved: $OUT"
