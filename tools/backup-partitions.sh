#!/usr/bin/env bash
# backup-partitions.sh — full safety backup of an MTK device over BROM.
#
# Dumps:
#   * both GPT copies (pgpt/sgpt)
#   * every "never lose this" partition
#   * optionally the whole eMMC (--all)
#
# Usage:
#   ./tools/backup-partitions.sh              # critical partitions
#   ./tools/backup-partitions.sh --all        # every partition (large!)
#   OUT=backup/2026-10-31 ./tools/backup-partitions.sh
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
PY="${REPO}/mtk-venv/bin/python"
[ -x "$PY" ] || PY=python3
MTK="$REPO/mtkclient/mtk.py"
OUT="${OUT:-$REPO/backup/$(date +%Y-%m-%d_%H%M%S)}"

# partitions that contain factory-unique data or are needed for recovery
CRITICAL=(
  boot recovery lk lk2 md1img md_udc
  boot_para proinfo para expdb frp metadata
  nvram nvdata nvcfg persist protect1 protect2
  seccfg otp flashinfo tkv
  scp1 scp2 sspm_1 sspm_2 spmfw tee1 tee2
  logo dtbo vbmeta vbmeta_system vbmeta_vendor
)

mkdir -p "$OUT"
echo "== output: $OUT"

echo "== reading GPT (BROM required: powered off, Vol- + Vol+ while plugging)"
"$PY" "$MTK" printgpt | tee "$OUT/gpt.txt"

echo "== GPT copies"
"$PY" "$MTK" r pgpt  "$OUT/pgpt.bin"  || true
"$PY" "$MTK" r sgpt  "$OUT/sgpt.bin"  || true

for p in "${CRITICAL[@]}"; do
  if grep -qi "^$p:" "$OUT/gpt.txt"; then
    echo "== dumping $p"
    "$PY" "$MTK" r "$p" "$OUT/$p.bin" || echo "   !! failed: $p"
  else
    echo "== skip $p (not in GPT)"
  fi
done

if [ "${1:-}" = "--all" ]; then
  echo "== dumping every partition (this can take hours and ~60 GB)"
  for p in $(grep -oE '^[a-zA-Z0-9_]+:' "$OUT/gpt.txt" | tr -d ':'); do
    [ -e "$OUT/$p.bin" ] && continue
    echo "   $p"
    "$PY" "$MTK" r "$p" "$OUT/$p.bin" || echo "   !! failed: $p"
  done
fi

echo
echo "== done. Keep this directory safe; it is your only way back."
echo "   GPT:        $OUT/pgpt.bin / sgpt.bin"
echo "   partitions: $OUT/*.bin"
echo
echo "   restore GPT:   python3 mtkclient/mtk.py w pgpt  $OUT/pgpt.bin"
echo "   restore part:  python3 mtkclient/mtk.py w <name> $OUT/<name>.bin"
