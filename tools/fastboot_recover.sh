#!/bin/bash
# fastboot_recover.sh — wait for LK fastboot, clear misc (BCB), restore stock recovery.
set -u
REPO="/home/mk/Documents/tecno_ke7_linux_port"
FB="/tmp/opencode/platform-tools/fastboot"
STOCK_REC="$REPO/firmware/stock_retail/KE7-H693HJKM-Q-GL-220729V478(MobiFirmware.com)/recovery.img"
LOG="/tmp/opencode/fastboot_recover.log"
: > "$LOG"
log() { echo "$(date +%H:%M:%S) $*" | tee -a "$LOG"; }

log "waiting for fastboot (up to 10 min)..."
found=0
for i in $(seq 1 300); do
  if "$FB" devices 2>/dev/null | grep -q .; then found=1; break; fi
  sleep 2
done
[ "$found" = "1" ] || { log "TIMEOUT"; exit 1; }
log "fastboot: $("$FB" devices | tr '\n' ' ')"

log "erasing misc (clears boot-recovery flag)"
"$FB" erase misc >>"$LOG" 2>&1 || log "erase misc failed, trying zero flash"
if ! "$FB" erase misc >/dev/null 2>&1; then
  dd if=/dev/zero of=/tmp/opencode/zero1m.img bs=1M count=1 status=none
  "$FB" flash misc /tmp/opencode/zero1m.img >>"$LOG" 2>&1 || log "flash misc failed"
fi

log "restoring stock recovery"
"$FB" flash recovery "$STOCK_REC" >>"$LOG" 2>&1 || { log "recovery flash failed"; exit 1; }

log "rebooting"
"$FB" reboot >>"$LOG" 2>&1 || true
log "DONE"
