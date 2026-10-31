#!/usr/bin/env bash
# restore_retail_md1img.sh — put the retail (V118) modem image back over BROM.
# Pre-arm BEFORE plugging in: BROM is only exposed for ~1 s.
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
B="$REPO/firmware/stock_retail/bin"
M=(mtk-venv/bin/python mtkclient/mtk.py)
cd "$REPO"
[ -e "$B/md1img.img" ] || { echo "missing $B/md1img.img"; exit 1; }
echo "== pre-armed: waiting for BROM (Vol Up + Vol Down while plugging in) =="
"${M[@]}" multi "w md1img $B/md1img.img;reset"
echo "== exit $? =="
