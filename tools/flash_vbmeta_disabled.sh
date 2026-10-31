#!/bin/bash
DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENV="$DIR/venv/bin/python3"
MTK="$DIR/mtkclient/mtk.py"
IMG="$DIR/flash_images/vbmeta_disabled.img"

echo "=========================================================="
echo " Tecno Spark 6 (KE7) - Flashing AVB-Disabled VBMeta"
echo "=========================================================="
echo "[*] Waiting for device in BROM mode..."
echo "[*] Unplug USB cable, hold Volume Down (or Vol Down + Vol Up), and plug in USB cable."

cd "$DIR/mtkclient"
$VENV "$MTK" w vbmeta,vbmeta_system,vbmeta_vendor "$IMG,$IMG,$IMG"

echo ""
echo "[+] SUCCESS: AVB disabled completely on all vbmeta partitions!"
