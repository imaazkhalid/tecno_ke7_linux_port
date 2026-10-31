#!/usr/bin/env bash
# Passive USB watcher: reports what the laptop actually sees, without ever
# opening the phone's USB device (so it cannot disturb BROM/preloader).
#
# Prints and notifies on:
#   - a device appearing          (new high-speed USB device)
#   - a completed enumeration     (New USB device found, idVendor=...)
#   - a failed enumeration        (error -71 / unable to enumerate)
set -uo pipefail
export DISPLAY=${DISPLAY:-:0}
LOG=${LOG:-/tmp/opencode/usb_watch.log}
say() { printf '%s %s\n' "[$(date +%H:%M:%S)]" "$*"; }
: > "$LOG"
say "passive watcher armed -- nothing is opened, safe to plug in"

journalctl -k -f -o short-iso 2>/dev/null | grep --line-buffered -iE \
  "new (high|full|low)-speed USB device|New USB device found|unable to enumerate|error -71|usb3-port3" \
| while IFS= read -r line; do
    ts=$(printf '%s' "$line" | sed -E 's/^[0-9-]+T([0-9:]+)\+.*/\1/')
    msg=$(printf '%s' "$line" | sed -E 's/^.*kernel: //')
    echo "$ts  $msg" | tee -a "$LOG"
    case "$msg" in
      *"New USB device found"*idVendor=0e8d*idProduct=0003*)
        notify-send -u critical -t 0 -a "KE7 USB" "BROM VISIBLE (0e8d:0003)" "Phone is in BROM now." ;;
      *"New USB device found"*idVendor=0e8d*)
        notify-send -u normal -t 4000 -a "KE7 USB" "Phone enumerated" "0e8d preloader, not BROM." ;;
      *"New USB device found"*)
        notify-send -u low -t 3000 -a "KE7 USB" "USB device enumerated" "$msg" ;;
      *"unable to enumerate"*)
        notify-send -u normal -t 4000 -a "KE7 USB" "Enumeration FAILED" "Port gave up again (error -71)." ;;
    esac
  done
