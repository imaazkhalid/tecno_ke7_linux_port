#!/bin/bash
# brom_listen.sh — wait for BROM and clear the Android BCB, with connection retries.
set -u
REPO="/home/mk/Documents/tecno_ke7_linux_port"
PY="$REPO/mtk-venv/bin/python"
MTK="$REPO/mtkclient/mtk.py"
LOG="/tmp/opencode/brom_listen.log"
STOCK_REC="$REPO/firmware/stock_retail/KE7-H693HJKM-Q-GL-220729V478(MobiFirmware.com)/recovery.img"
mkdir -p "$REPO/backup"
: > "$LOG"
log() { echo "$(date +%H:%M:%S) $*" | tee -a "$LOG"; }

wait_brom() {
  local t=${1:-600}
  for i in $(seq 1 "$t"); do
    for d in /sys/bus/usb/devices/*/; do
      v=$(cat "$d/idVendor" 2>/dev/null); p=$(cat "$d/idProduct" 2>/dev/null)
      if [ "$v" = "0e8d" ] && [ "$p" = "0003" ]; then return 0; fi
    done
    sleep 1
  done
  return 1
}

cd "$REPO" || exit 1

log "waiting for BROM 0e8d:0003..."
ok=0
for attempt in 1 2 3 4 5; do
  wait_brom 600 || { log "timeout waiting for BROM"; exit 1; }
  log "BROM present, connect attempt $attempt"
  sleep 2
  if timeout 60 "$PY" "$MTK" printgpt >>"$LOG" 2>&1; then
    log "connected on attempt $attempt"
    ok=1
    break
  fi
  log "attempt $attempt failed, retrying in 5s"
  sleep 5
done
[ "$ok" = "1" ] || { log "could not connect after 5 attempts"; exit 1; }

log "dumping misc"
if ! "$PY" "$MTK" r misc "$REPO/backup/misc_before_bcb_clear.bin" >>"$LOG" 2>&1; then
  log "misc dump failed"; exit 1
fi
sz=$(stat -c%s "$REPO/backup/misc_before_bcb_clear.bin" 2>/dev/null || echo 0)
log "misc size: $sz"

"$PY" - <<'EOF' >>"$LOG" 2>&1
p='/home/mk/Documents/tecno_ke7_linux_port/backup/misc_before_bcb_clear.bin'
d=bytearray(open(p,'rb').read())
n=min(4096,len(d))
for i in range(n): d[i]=0
open('/tmp/opencode/misc_zeroed.bin','wb').write(d)
print("zeroed",n,"of",len(d))
EOF

log "writing misc back"
if ! "$PY" "$MTK" w misc /tmp/opencode/misc_zeroed.bin >>"$LOG" 2>&1; then
  log "misc write failed"; exit 1
fi

log "restoring stock recovery"
if ! "$PY" "$MTK" w recovery "$STOCK_REC" >>"$LOG" 2>&1; then
  log "recovery write failed"; exit 1
fi

log "reset"
"$PY" "$MTK" reset >>"$LOG" 2>&1 || true
log "DONE — Android should boot normally"
