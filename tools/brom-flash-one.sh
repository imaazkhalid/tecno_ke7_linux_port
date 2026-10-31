#!/usr/bin/env bash
# Flash ONE partition via BROM, retrying until it lands.
#   usage: ./tools/brom-flash-one.sh <partition> <image> [expected-bytes]
# Example: ./tools/brom-flash-one.sh boot u-boot-boot.img 33554432
#
# Retries because BROM only shows up for a moment at power-on when the phone is
# not latched; each failed window is simply re-armed.
set -uo pipefail
cd "$(dirname "$0")/.."
export DISPLAY=${DISPLAY:-:0}

PART=${1:?partition name (e.g. boot)}
IMG=${2:?image path}
EXPECT=${3:-0}
PY=./mtk-venv/bin/python
MTK=mtkclient/mtk.py
LOG=/tmp/opencode/flash_one.log
ATT=/tmp/opencode/flash_one_attempt.log
MAX=${MAX:-400}

[ -f "$IMG" ] || { echo "missing image: $IMG" >&2; exit 1; }
size=$(stat -c%s "$IMG")
sha=$(sha256sum "$IMG" | cut -d' ' -f1)
say() { printf '%s %s\n' "[$(date +%H:%M:%S)]" "$*"; }

: > "$LOG"
say "TARGET  $PART  <-  $IMG"
say "        size=$size  sha256=${sha:0:16}…"
if [ "$EXPECT" != "0" ] && [ "$size" -gt "$EXPECT" ]; then
  say "ABORT   image ($size) larger than partition ($EXPECT)"; exit 1
fi
say "LISTENING  arming BROM; plug in (battery pull first if the phone is latched)"

for a in $(seq 1 "$MAX"); do
  : > "$ATT"
  tail -f "$ATT" 2>/dev/null & tpid=$!
  "$PY" -u "$MTK" multi "w $PART $IMG;reset" >> "$ATT" 2>&1 &
  mpid=$!
  captured=0; ticks=0
  while kill -0 "$mpid" 2>/dev/null; do
    if [ "$captured" = 0 ] && grep -q 'Successfully received DA sync' "$ATT" 2>/dev/null; then
      captured=1
      say "CAPTURED  DA sync OK -- writing $PART, keep the cable in"
      notify-send -u normal -t 5000 -h int:transient:1 -a "KE7 FLASH" "CAPTURED" "Writing $PART, do not unplug."
    fi
    ticks=$((ticks+1))
    [ $((ticks % 40)) -eq 0 ] && [ "$captured" = 0 ] && say "LISTENING  attempt $a, $((ticks/2))s in window"
    sleep 0.5
  done
  wait "$mpid"; rc=$?
  sleep 0.5; kill "$tpid" 2>/dev/null; wait "$tpid" 2>/dev/null

  if grep -q "^Wrote .* to sector" "$ATT" 2>/dev/null; then
    say "SUCCESS  $PART written"
    grep -E "^Wrote |Reset command" "$ATT" | tee -a "$LOG"
    notify-send -u normal -t 5000 -h int:transient:1 -a "KE7 FLASH" "SUCCESS" "$PART written. Reset sent."
    exit 0
  fi
  if [ "$captured" = 1 ]; then
    say "RETRY  attempt $a: captured but write failed (rc=$rc)"
  else
    say "WAITING  attempt $a: no device in this window"
  fi
  sleep 0.5
done
say "GAVEUP  $PART not written after $MAX attempts"
notify-send -u normal -t 5000 -h int:transient:1 -a "KE7 FLASH" "GAVE UP" "$PART not written."
exit 1
