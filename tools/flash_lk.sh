#!/usr/bin/env bash
# flash_lk.sh — write the RETAIL lk + lk2 bootloader (matched with the 220729V478
# images we just flashed). Must be launched BEFORE plugging the phone in, because
# BROM is only exposed for ~1 s; mtkclient's handshake() polls every 0.3 s.
#
# Reversible: old lk is saved in backup/lk.bin and
# backup/arch_state_20261025/mmcblk0p27.bin
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
B="$REPO/firmware/stock_retail/bin"
M=(mtk-venv/bin/python mtkclient/mtk.py)
cd "$REPO"

for f in lk.img; do
    [ -e "$B/$f" ] || { echo "missing $B/$f"; exit 1; }
done

echo "== pre-armed: waiting for BROM (plug in with Vol Up + Vol Down) =="
"${M[@]}" multi "w lk $B/lk.img;w lk2 $B/lk.img;reset"
echo "== flash_lk exit $? =="
