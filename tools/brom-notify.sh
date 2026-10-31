#!/usr/bin/env bash
# Desktop notifications for the BROM capture loop.
# Watches $STATUS and pops a notification on every meaningful transition, so you
# do not have to watch a terminal to know whether the phone was captured.
set -uo pipefail
STATUS=${STATUS:-/tmp/opencode/brom_status.txt}
export DISPLAY=${DISPLAY:-:0}

last=""
while :; do
  cur=$(cat "$STATUS" 2>/dev/null)
  if [ "$cur" != "$last" ] && [ -n "$cur" ]; then
    case "$cur" in
      CAPTURED*)
        notify-send -u normal -t 5000 -h int:transient:1 -a "KE7 BROM" \
          "PHONE CAPTURED" "DA sync OK, uploading now.\nDo not unplug the cable." ;;
      WRITING*)
        notify-send -u normal -t 5000 -h int:transient:1 -a "KE7 BROM" \
          "Writing vbmeta" "${cur#WRITING }" ;;
      SUCCESS*)
        notify-send -u normal -t 5000 -h int:transient:1 -a "KE7 BROM" \
          "SUCCESS - all 3 written" "Reset sent. Unplug and replug to boot Linux." ;;
      RETRY*)
        notify-send -u normal -t 5000 -h int:transient:1 -a "KE7 BROM" \
          "Capture failed, retrying" "${cur#RETRY }" ;;
      GAVEUP*)
        notify-send -u normal -t 5000 -h int:transient:1 -a "KE7 BROM" \
          "Gave up" "No BROM window captured." ;;
    esac
    last="$cur"
  fi
  sleep 0.5
done
