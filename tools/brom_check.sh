#!/usr/bin/env bash
# brom_check.sh — READ-ONLY diagnostic once the device is in BROM.
# Confirms the preloader/DA still work and captures the current lk/lk2/seccfg
# so we can decide whether the boot chain needs the retail lk.
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
M=(mtk-venv/bin/python mtkclient/mtk.py)
OUT="$REPO/firmware/brom_check_$(date +%H%M%S)"
mkdir -p "$OUT"
cd "$REPO"

echo "== printgpt =="
ok=0
for t in 1 2 3 4 5 6 7 8; do
    if "${M[@]}" printgpt > "$OUT/gpt.txt" 2>&1; then ok=1; break; fi
    echo "   retry $t"; sleep 2
done
[ "$ok" = 1 ] || { echo "!! DA not reachable"; exit 1; }
grep -cE "^0x" "$OUT/gpt.txt" | sed 's/^/   gpt entries: /'

echo "== dumping lk, lk2, seccfg (read-only) =="
for p in lk lk2 seccfg; do
    if "${M[@]}" r "$p" "$OUT/$p.bin" > "$OUT/r_$p.log" 2>&1; then
        sz=$(stat -c%s "$OUT/$p.bin" 2>/dev/null || echo 0)
        echo "   $p: $sz bytes md5=$(md5sum "$OUT/$p.bin" 2>/dev/null | cut -d' ' -f1)"
    else
        echo "   $p: READ FAILED"
    fi
done
echo "== lk first bytes =="
xxd -l 64 "$OUT/lk.bin" 2>/dev/null
echo "OUTDIR=$OUT"
