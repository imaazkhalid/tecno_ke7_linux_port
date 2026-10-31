#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENV="$DIR/venv/bin/python3"
MTK="$DIR/mtkclient/mtk.py"
IMG="$DIR/flash_images"

echo "=========================================================="
echo " Tecno Spark 6 (KE7) - Restoring Working Display & Boot"
echo "=========================================================="
echo "[*] Writing matching display DTBO, boot, and vbmeta..."
echo "[*] Note: seccfg is ALREADY hardware-unlocked via HACC!"
echo "[*] Waiting for device in BROM mode (Hold Vol-Down + plug USB)..."

PARTS="dtbo,boot,recovery,vbmeta"
FILES="$IMG/dtbo.img,$IMG/boot_signed.img,$IMG/boot_signed.img,$IMG/vbmeta_final.img"

cd "$DIR/mtkclient"
$VENV "$MTK" w "$PARTS" "$FILES"

echo ""
echo "[+] SUCCESS: Display DTBO and Boot written!"
echo "[+] Disconnect USB cable now."
echo "[+] Press and hold Power button to boot."
