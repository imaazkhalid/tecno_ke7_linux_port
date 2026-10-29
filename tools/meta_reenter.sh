#!/bin/bash
# Fast re-entry: run the preloader handshake in the background and attach the
# 202d META device to the VM the instant it appears (no 5-minute wait).
set -u
LOG=/tmp/opencode/fast_reenter.log
echo "start $(date +%T)" > "$LOG"

python3 /tmp/opencode/premeta.py 300 >/tmp/opencode/fast_premeta.out 2>&1 &
PM=$!

for i in $(seq 1 1500); do
  found=0
  for d in /sys/bus/usb/devices/*/; do
    v=$(cat "$d/idVendor" 2>/dev/null); p=$(cat "$d/idProduct" 2>/dev/null)
    [ "$v" = "0e8d" ] && [ "$p" = "202d" ] && { found=1; break; }
  done
  if [ "$found" -eq 1 ]; then
    echo "202d at $(date +%T)" >> "$LOG"
    virsh -c qemu:///session attach-device WINMETA /tmp/opencode/usb-meta.xml --live >> "$LOG" 2>&1
    echo "attach rc=$? $(date +%T)" >> "$LOG"
    kill $PM 2>/dev/null
    exit 0
  fi
  sleep 0.2
done
echo "no 202d" >> "$LOG"
kill $PM 2>/dev/null
exit 1
