#!/usr/bin/env bash
# meta-mode.sh — put the phone into META mode from BROM, then wait for the
# CDC-ACM port to appear.
#
# Usage: ./tools/meta-mode.sh
#
# Sequence:
#   1. (you) phone off, hold Vol Up + Vol Down, plug in  -> BROM 0e8d:0003
#   2. (this script) DA command "SET_META_BOOT_MODE = usb"
#   3. (you) power-cycle the phone -> it boots into META instead of Android
#   4. (this script) waits for /dev/ttyACM* and reports it
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

echo "== waiting for BROM (hold Vol Up + Vol Down while plugging in) =="
echo "   mtkclient polls every 0.3 s, so the ~1 s BROM window is enough"
if ! mtk-venv/bin/python mtkclient/mtk.py da meta usb 2>&1 | grep -aiE "successfully set meta|failed|not in xflash" ; then
    :
fi

echo
echo "== now power-cycle the phone =="
echo "   unplug, then plug back in (or press power) - it should NOT boot Android"
echo
echo "== waiting for the META serial port =="
for i in $(seq 1 90); do
    for p in /dev/ttyACM*; do
        if [ -e "$p" ]; then
            echo "== META port: $p"
            ls -l "$p"
            # map into wine
            PREFIX="$HOME/.wine-meta"
            mkdir -p "$PREFIX/dosdevices"
            ln -sf "$p" "$PREFIX/dosdevices/com1"
            WINEPREFIX="$PREFIX" wine reg add 'HKLM\HARDWARE\DEVICEMAP\SERIALCOMM' \
                /v "$(basename "$p")" /t REG_SZ /d 'COM1' /f >/dev/null 2>&1
            echo "== mapped to COM1 in $PREFIX"
            exit 0
        fi
    done
    sleep 1
done
echo "!! no /dev/ttyACM* appeared after 90 s"
echo "   check 'lsusb' - if you see 0e8d:0003 the phone is still in BROM,"
echo "   if you see 0e8d:2000 with a CDC interface the kernel may need cdc_acm."
exit 1
