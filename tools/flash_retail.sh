#!/usr/bin/env bash
# flash_retail.sh — flash the RETAIL Tecno KE7 (H693HJKM) Android 10 firmware
# KE7-H693HJKM-Q-GL-220729V478 over BROM/Kamakiri.
#
# Keeps (never written): preloader (boot0/boot1), seccfg (orange state),
# nvram, nvdata, persist, protect1/2, otp, flashinfo, tkv, lk/lk2, md_udc,
# boot_para, proinfo, para, expdb, frp, metadata, nvcfg, gz1, gz2, sec1.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
B="$REPO/firmware/stock_retail/bin"
M=(mtk-venv/bin/python mtkclient/mtk.py)

cd "$REPO"
for f in super.raw boot.img recovery.img md1img.img dtbo.img logo.bin tee.img \
         scp.img sspm.img spmfw.img vbmeta.img vbmeta_system.img \
         vbmeta_vendor.img cache.raw tranfs.raw zero4m.bin; do
    [ -e "$B/$f" ] || { echo "missing $B/$f"; exit 1; }
done

echo "== pre-flight: BROM + GPT =="
ok=0
for t in 1 2 3 4 5 6 7 8; do
    if "${M[@]}" printgpt > firmware/device_gpt_before_retail.txt 2>&1; then ok=1; break; fi
    echo "   pre-flight retry $t"; sleep 2
done
[ "$ok" = "1" ] || { echo "!! BROM not reachable"; exit 1; }
grep -qi "userdata" firmware/device_gpt_before_retail.txt || {
    echo "!! no userdata partition"; exit 1; }

echo "== writing retail 220729V478 =="
CMD="w super $B/super.raw"
CMD="$CMD;w boot $B/boot.img"
CMD="$CMD;w recovery $B/recovery.img"
CMD="$CMD;w md1img $B/md1img.img"
CMD="$CMD;w dtbo $B/dtbo.img"
CMD="$CMD;w logo $B/logo.bin"
CMD="$CMD;w tee1 $B/tee.img"
CMD="$CMD;w tee2 $B/tee.img"
CMD="$CMD;w scp1 $B/scp.img"
CMD="$CMD;w scp2 $B/scp.img"
CMD="$CMD;w sspm_1 $B/sspm.img"
CMD="$CMD;w sspm_2 $B/sspm.img"
CMD="$CMD;w spmfw $B/spmfw.img"
CMD="$CMD;w vbmeta $B/vbmeta.img"
CMD="$CMD;w vbmeta_system $B/vbmeta_system.img"
CMD="$CMD;w vbmeta_vendor $B/vbmeta_vendor.img"
CMD="$CMD;w cache $B/cache.raw"
CMD="$CMD;w tranfs $B/tranfs.raw"
CMD="$CMD;w userdata $B/zero4m.bin"
CMD="$CMD;w misc $B/zero4m.bin"
CMD="$CMD;reset"

"${M[@]}" multi "$CMD"
echo "== done =="
