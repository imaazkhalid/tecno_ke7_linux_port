#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENV="$DIR/venv/bin/python3"
MTK="$DIR/mtkclient/mtk.py"
IMG="$DIR/flash_images"

echo "=========================================================="
echo " Tecno Spark 6 (KE7) - Flashing AVB-Disabled Boot & VBMeta"
echo "=========================================================="
echo "[*] Partitions: boot, recovery, vbmeta, vbmeta_system, vbmeta_vendor"
echo "[*] Waiting for device in BROM mode (Hold Vol-Down + plug USB)..."

PARTS="boot,recovery,vbmeta,vbmeta_system,vbmeta_vendor"
FILES="$IMG/boot_signed.img,$IMG/boot_signed.img,$IMG/vbmeta_final.img,$IMG/vbmeta_final.img,$IMG/vbmeta_final.img"

cd "$DIR/mtkclient"
$VENV "$MTK" w "$PARTS" "$FILES"

echo ""
echo "[+] SUCCESS: AVB-disabled Boot and VBMeta successfully written!"
echo "[+] All verification disabled across boot, recovery, system, and vendor."
echo "[+] Disconnect USB and power on the phone."
