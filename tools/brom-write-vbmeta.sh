#!/usr/bin/env bash
# Catch the split-second BROM window and write the port-era vbmeta set.
#
# Designed for live watching: the flash tool's own output is streamed to stdout
# as it happens, and state lines say exactly what we are doing:
#   LISTENING -> CAPTURED -> WRITING -> SUCCESS | RETRY | WAITING
#
# No buttons: the phone re-enters BROM by itself at power-on; we just stay
# armed and re-arm on every failure until all three partitions are written.
set -uo pipefail
cd "$(dirname "$0")/.."

B=backup/arch_state_20261025
LOG=${LOG:-/tmp/opencode/brom_loop.log}
ATT=/tmp/opencode/brom_attempt.log
STATUS=${STATUS:-/tmp/opencode/brom_status.txt}
PY=./mtk-venv/bin/python
MTK=mtkclient/mtk.py
MAX=${MAX:-400}

say() { printf '%s %s\n' "[$(date +%H:%M:%S)]" "$*"; }
st()  { printf '%s\n' "$*" > "$STATUS"; }

: > "$LOG"
say "LISTENING   armed for up to $MAX attempts -- no buttons, just plug in"
say "LISTENING   watching for BROM; a stream of dots below means still waiting"
st "LISTENING armed $(date +%H:%M:%S)"

prev_written=0
for a in $(seq 1 "$MAX"); do
  : > "$ATT"

  # Live view of whatever the flash tool prints.
  tail -f "$ATT" 2>/dev/null &
  tpid=$!

  "$PY" -u "$MTK" multi "\
w vbmeta $B/mmcblk0p34.bin;\
w vbmeta_system $B/mmcblk0p35.bin;\
w vbmeta_vendor $B/mmcblk0p36.bin;\
reset" >> "$ATT" 2>&1 &
  mpid=$!

  st "LISTENING attempt $a"
  captured=0
  ticks=0
  while kill -0 "$mpid" 2>/dev/null; do
    if [ "$captured" = 0 ] && grep -q 'Successfully received DA sync' "$ATT" 2>/dev/null; then
      captured=1
      say "CAPTURED    BROM/DA sync OK -- uploading, keep the cable in"
      st "CAPTURED attempt $a da-sync"
    fi
    if [ "$captured" = 1 ]; then
      n=$(grep -c '^Wrote ' "$ATT" 2>/dev/null); n=${n:-0}
      if [ "$n" -gt "$prev_written" ]; then
        prev_written=$n
        say "WRITING     $n/3 partitions done"
        st "WRITING attempt $a $n/3"
      fi
    fi
    ticks=$((ticks+1))
    if [ $((ticks % 40)) -eq 0 ] && [ "$captured" = 0 ]; then
      say "LISTENING   attempt $a, $((${ticks}/2))s in this window -- nothing seen yet"
    fi
    sleep 0.5
  done

  wait "$mpid"; rc=$?
  sleep 0.5
  kill "$tpid" 2>/dev/null
  wait "$tpid" 2>/dev/null

  cp "$ATT" "/tmp/opencode/brom_attempt_$a.log" 2>/dev/null
  { echo "---- attempt $a rc=$rc ----"; cat "$ATT"; } >> "$LOG"

  wrote=$(grep -c '^Wrote ' "$ATT" 2>/dev/null); wrote=${wrote:-0}
  if [ "$wrote" -ge 3 ]; then
    say "SUCCESS     $wrote/3 partitions written, reset sent"
    grep -E '^Wrote |Reset command' "$ATT"
    st "SUCCESS $(date +%H:%M:%S) $wrote/3 written"
    echo "SUCCESS after attempt $a" >> "$LOG"
    exit 0
  fi

  if [ "$captured" = 1 ] || grep -q 'Successfully received DA sync' "$ATT" 2>/dev/null; then
    say "RETRY       attempt $a captured the phone but the upload failed -- re-arming"
    st "RETRY attempt $a upload-failed"
    echo "attempt $a: DA reached, upload failed" >> "$LOG"
  else
    say "WAITING     attempt $a saw nothing in its window -- re-arming"
    st "WAITING attempt $a no-device"
    echo "attempt $a: no device" >> "$LOG"
  fi
  sleep 0.5
done

say "GAVEUP      no success after $MAX attempts"
st "GAVEUP"
exit 1
