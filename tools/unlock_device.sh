#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENV="$DIR/venv/bin/python3"
MTK="$DIR/mtkclient/mtk.py"
IMG="$DIR/flash_images"

echo "=========================================================="
echo " Tecno Spark 6 (KE7) - Bootloader Unlock & AVB Disable"
echo "=========================================================="
echo "[*] Waiting for device in BROM mode (Hold Vol-Down + plug USB)..."

cd "$DIR/mtkclient"
$VENV "$MTK" w seccfg,vbmeta "$IMG/seccfg_unlocked.bin,$IMG/vbmeta_disabled.img"

echo ""
echo "[+] SUCCESS: Bootloader unlocked (seccfg) and AVB disabled (vbmeta)!"
echo "[+] Disconnect USB and power on the device."
echo "[+] It should now show 'Orange State' and boot normally!"
