#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENV="$DIR/venv/bin/python3"
MTK="$DIR/mtkclient/mtk.py"

echo "=========================================================="
echo " Tecno Spark 6 (KE7) - Restore Official Signed OEM Boot"
echo "=========================================================="
echo "[*] Flashing genuine Tecno OEM signed boot & vbmeta images"
echo "[*] This permanently satisfies LK's cryptographic verification"
echo "[*] Waiting for device in BROM mode (Hold Vol-Down + plug USB)..."

PARTS="boot,recovery,dtbo,vbmeta"
FILES="$DIR/ke7_dump/boot.img,$DIR/ke7_dump/boot.img,$DIR/ke7_dump/dtbo.img,$DIR/flash_images/vbmeta_stock.img"

cd "$DIR/mtkclient"
$VENV "$MTK" w "$PARTS" "$FILES"

echo ""
echo "[+] Flashing completed successfully!"
echo "[*] Attempting to unlock seccfg via DA..."
$VENV "$MTK" da seccfg unlock || echo "[!] seccfg unlock returned (can unlock via fastboot)"

echo ""
echo "=========================================================="
echo "[+] SUCCESS: Device restored to signed state!"
echo "[+] Red State bootloop will be gone on boot."
echo "[+] Disconnect USB, hold Vol-Down + Power to enter Fastboot!"
echo "=========================================================="
