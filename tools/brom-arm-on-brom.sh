#!/usr/bin/env bash
# Arm mtkclient ONLY when a real BROM device (0e8d:0003) exists.
#
# Why: last session mtkclient grabbed the preloader (0e8d:2000) every time it
# appeared and attempted a handshake. That coincides with the phone failing to
# enumerate at all. This watcher never opens anything until BROM itself is
# present, so it cannot disturb the preloader's boot attempts.
#
# BROM waits indefinitely for its host, so a short detection delay is safe.
set -uo pipefail
cd "$(dirname "$0")/.."
export DISPLAY=${DISPLAY:-:0}

B=backup/arch_state_20261025
PY=./mtk-venv/bin/python
MTK=mtkclient/mtk.py
STATUS=${STATUS:-/tmp/opencode/brom_status.txt}
LOG=${LOG:-/tmp/opencode/arm_on_brom.log}
say() { printf '%s %s\n' "[$(date +%H:%M:%S)]" "$*"; }

: > "$LOG"
say "ARMED  waiting for 0e8d:0003 (BROM). Preloader is ignored on purpose."

found_any=0
for tick in $(seq 1 5400); do   # 5400 * 0.2s = 18 min
  hit=""
  for d in /sys/bus/usb/devices/*/; do
    [ "$(cat "$d/idVendor" 2>/dev/null)" = "0e8d" ] || continue
    pid=$(cat "$d/idProduct" 2>/dev/null)
    [ "$pid" = "0003" ] && hit="$d"
    [ "$pid" = "2000" ] && [ $((tick % 50)) -eq 0 ] && say "note: preloader 0e8d:2000 visible (ignored)"
  done
  if [ -z "$hit" ]; then sleep 0.2; continue; fi

  found_any=1
  say "DETECTED  0e8d:0003 BROM at $hit -- launching mtkclient now"
  printf 'CAPTURED brom %s\n' "$(date +%H:%M:%S)" > "$STATUS"
  notify-send -u critical -t 0 -a "KE7 BROM" "BROM DETECTED" "Starting vbmeta write now."

  : > /tmp/opencode/brom_attempt.log
  "$PY" -u "$MTK" multi "\
w vbmeta $B/mmcblk0p34.bin;\
w vbmeta_system $B/mmcblk0p35.bin;\
w vbmeta_vendor $B/mmcblk0p36.bin;\
reset" 2>&1 | tee /tmp/opencode/brom_attempt.log | tee -a "$LOG"

  wrote=$(grep -c '^Wrote ' /tmp/opencode/brom_attempt.log 2>/dev/null || echo 0)
  if [ "$wrote" -ge 3 ]; then
    say "SUCCESS  $wrote/3 written, reset sent"
    printf 'SUCCESS %s %s/3\n' "$(date +%H:%M:%S)" "$wrote" > "$STATUS"
    notify-send -u critical -t 0 -a "KE7 BROM" "SUCCESS - all 3 written" "Unplug and replug to boot Linux."
    exit 0
  fi
  say "RETRY  captured but only $wrote/3 written -- returning to wait"
  notify-send -u normal -t 4000 -a "KE7 BROM" "Write incomplete" "$wrote/3 partitions"
  sleep 1
done

say "TIMEOUT  no BROM in 18 minutes (preloader seen: $found_any)"
printf 'TIMEOUT %s\n' "$(date +%H:%M:%S)" > "$STATUS"
exit 1
