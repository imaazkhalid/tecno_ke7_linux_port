#!/usr/bin/env bash
# flash_stock.sh — restore genuine Tecno KE7 Android 10 stock firmware over BROM/Kamakiri.
#
# Keeps: bootloader unlock (seccfg), device preloader (AND_SECRO hash),
#        LK/LK2 (current, proven to boot with orange state), TEE key vault (tkv),
#        NVRAM/NVDATA/PERSIST/PROTECT1-2/OTP/FLASHINFO/MD_UDC (device-unique).
#
# Prereq: phone powered OFF, Volume Down held, USB plugged -> lsusb shows 0e8d:0003
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
S="$REPO/firmware/stock/Tecno Spark 6 (KE7-H693GHIJKM-Q-GL-200617V060)_MobileGuru4.com"
M=(mtk-venv/bin/python mtkclient/mtk.py)

cd "$REPO"
[ -f "$S/boot.img" ]      || { echo "missing stock images in $S"; exit 1; }
[ -f "$REPO/firmware/stock/super.raw" ] || { echo "missing super.raw"; exit 1; }

echo "== checking BROM"
"${M[@]}" printgpt > firmware/device_gpt_before_flash.txt 2>&1 || {
  echo "!! could not talk to BROM. Power off, hold Vol Down, plug USB, retry."; exit 1; }
grep -qi "userdata" firmware/device_gpt_before_flash.txt || {
  echo "!! GPT has no userdata partition -- fix before flashing"; exit 1; }

echo "== flashing (this takes ~10-15 min for super)"
# biggest first so a failure shows up early
"${M[@]}" w super          "$REPO/firmware/stock/super.raw"
"${M[@]}" w boot           "$S/boot.img"
"${M[@]}" w recovery       "$S/recovery.img"
"${M[@]}" w md1img         "$S/md1img.img"
"${M[@]}" w dtbo           "$S/dtbo.img"
"${M[@]}" w logo           "$S/logo.bin"
"${M[@]}" w tee1           "$S/tee.img"
"${M[@]}" w tee2           "$S/tee.img"
"${M[@]}" w scp1           "$S/scp.img"
"${M[@]}" w scp2           "$S/scp.img"
"${M[@]}" w sspm_1         "$S/sspm.img"
"${M[@]}" w sspm_2         "$S/sspm.img"
"${M[@]}" w spmfw          "$S/spmfw.img"
"${M[@]}" w vbmeta         "$S/vbmeta.img"
"${M[@]}" w vbmeta_system  "$S/vbmeta_system.img"
"${M[@]}" w vbmeta_vendor  "$S/vbmeta_vendor.img"
"${M[@]}" w cache          "$REPO/firmware/stock/cache.raw"
"${M[@]}" w tranfs         "$REPO/firmware/stock/tranfs.raw"

echo "== wiping the first 4 MiB of userdata so Android formats it as f2fs"
"${M[@]}" w userdata "$REPO/firmware/stock/zero4m.bin"

echo "== wiping misc (stale boot commands)"
"${M[@]}" w misc "$REPO/firmware/stock/zero4m.bin"

echo "== reset"
"${M[@]}" reset

echo
echo "Done. First boot will take several minutes (formatting /data)."
echo "Expected: ORANGE STATE warning (unlocked) -> Tecno boot logo -> Android setup."
