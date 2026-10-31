#!/bin/bash
# brom_recover.sh — wait for BROM, then clear the Android BCB flag and restore
# the stock recovery. Safe: misc is backed up first; recovery is restored from
# the retail image we already have.
set -u
REPO="/home/mk/Documents/tecno_ke7_linux_port"
PY="$REPO/mtk-venv/bin/python"
MTK="$REPO/mtkclient/mtk.py"
LOG="/tmp/opencode/brom_recover.log"
STOCK_REC="$REPO/firmware/stock_retail/KE7-H693HJKM-Q-GL-220729V478(MobiFirmware.com)/recovery.img"
mkdir -p "$REPO/backup"
: > "$LOG"

log() { echo "$(date +%H:%M:%S) $*" | tee -a "$LOG"; }

log "waiting for BROM 0e8d:0003 (up to 10 min)..."
found=0
for i in $(seq 1 600); do
  for d in /sys/bus/usb/devices/*/; do
    v=$(cat "$d/idVendor" 2>/dev/null)
    p=$(cat "$d/idProduct" 2>/dev/null)
    if [ "$v" = "0e8d" ] && [ "$p" = "0003" ]; then found=1; break 2; fi
  done
  sleep 1
done

if [ "$found" != "1" ]; then log "TIMEOUT: no BROM device seen"; exit 1; fi
log "BROM detected, connecting..."
sleep 2

cd "$REPO" || exit 1

log "dumping misc -> backup/misc_before_bcb_clear.bin"
"$PY" "$MTK" r misc "$REPO/backup/misc_before_bcb_clear.bin" >>"$LOG" 2>&1 || { log "misc dump failed"; exit 1; }

log "zeroing BCB (first 4096 bytes) and writing misc back"
"$PY" - <<'EOF' >>"$LOG" 2>&1
p='/home/mk/Documents/tecno_ke7_linux_port/backup/misc_before_bcb_clear.bin'
d=bytearray(open(p,'rb').read())
for i in range(min(4096,len(d))): d[i]=0
open('/tmp/opencode/misc_zeroed.bin','wb').write(d)
print("misc size",len(d),"zeroed 4096")
EOF
"$PY" "$MTK" w misc /tmp/opencode/misc_zeroed.bin >>"$LOG" 2>&1 || { log "misc write failed"; exit 1; }

log "restoring stock recovery"
"$PY" "$MTK" w recovery "$STOCK_REC" >>"$LOG" 2>&1 || { log "recovery write failed"; exit 1; }

log "resetting device"
"$PY" "$MTK" reset >>"$LOG" 2>&1 || true
log "DONE"
