#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENV="$DIR/venv/bin/python3"
MTK="$DIR/mtkclient/mtk.py"
IMG="$DIR/flash_images"

echo "=== Flashing Tecno Spark 6 KE7 Screen Bring-up Images ==="
echo "Partitions: lk, lk2, logo, dtbo, tee1, tee2, sspm_1, sspm_2, spmfw, scp1, scp2, boot, recovery, vbmeta"

PARTS="lk,lk2,logo,dtbo,tee1,tee2,sspm_1,sspm_2,spmfw,scp1,scp2,boot,recovery,vbmeta"
FILES="$IMG/lk.img,$IMG/lk.img,$IMG/logo.bin,$IMG/dtbo.img,$IMG/tee.img,$IMG/tee.img,$IMG/sspm.img,$IMG/sspm.img,$IMG/spmfw.img,$IMG/scp.img,$IMG/scp.img,$IMG/twrp.img,$IMG/twrp.img,$IMG/vbmeta.img"

cd "$DIR/mtkclient"
$VENV "$MTK" w "$PARTS" "$FILES"
echo "=== Flashing Complete! ==="
