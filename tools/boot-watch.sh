#!/usr/bin/env bash
# Watch for the phone booting Linux after the boot set was completed.
# Reports: Linux USB gadget up, DHCP-less static IP answering, SSH reachable.
set -uo pipefail
export DISPLAY=${DISPLAY:-:0}
LOG=${LOG:-/tmp/opencode/boot_watch.log}
: > "$LOG"
say() { printf '%s %s\n' "[$(date +%H:%M:%S)]" "$*" | tee -a "$LOG"; }

say "BOOT WATCH  waiting for the phone to come back"
say "BOOT WATCH  success = 1d6b:0104 gadget + ping 172.16.42.2"

seen_gadget=0
for i in $(seq 1 1800); do
  ids=""
  for d in /sys/bus/usb/devices/*/; do
    v=$(cat "$d/idVendor" 2>/dev/null) || continue
    p=$(cat "$d/idProduct" 2>/dev/null)
    case "$v:$p" in
      1d6b:0104) ids="linux-gadget" ;;
      18d1:*)    ids="android-adb" ;;
      0e8d:201c) ids="android-adb" ;;
      0e8d:2000) ids="mtk-preloader" ;;
      0e8d:0003) ids="mtk-brom" ;;
    esac
    [ -n "$ids" ] && break
  done

  if [ -n "$ids" ]; then
    if [ "$ids" != "${last:-}" ]; then
      say "DEVICE  $ids"
      case "$ids" in
        linux-gadget) notify-send -u normal -t 5000 -h int:transient:1 -a "KE7 BOOT" "LINUX GADGET UP" "1d6b:0104 enumerated." ;;
        android-adb)  notify-send -u normal -t 5000 -h int:transient:1 -a "KE7 BOOT" "Android booted" "adb device present." ;;
        mtk-brom)     notify-send -u normal -t 5000 -h int:transient:1 -a "KE7 BOOT" "BROM again" "Phone did not boot." ;;
        mtk-preloader) notify-send -u normal -t 5000 -h int:transient:1 -a "KE7 BOOT" "Preloader again" "Phone did not boot." ;;
      esac
      last="$ids"
    fi
  fi

  if ping -c1 -W1 172.16.42.2 >/dev/null 2>&1; then
    if [ "${net:-}" != "up" ]; then
      say "NETWORK  172.16.42.2 answering"
      notify-send -u normal -t 5000 -h int:transient:1 -a "KE7 BOOT" "LINUX IS UP" "172.16.42.2 answers. ssh root@172.16.42.2"
      net=up
    fi
  elif [ "${net:-}" = "up" ]; then
    say "NETWORK  lost"
    net=down
  fi

  sleep 0.5
done
say "TIMEOUT after 15 min"
