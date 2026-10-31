#!/usr/bin/env bash
# meta-serial-setup.sh — prepare a Wine prefix that can see the phone's META port.
#
# Usage:   ./meta-serial-setup.sh [prefix]
# Default prefix: ~/.wine-meta
#
# What it does:
#   1. creates/updates a dedicated Wine prefix (64-bit)
#   2. finds the phone's CDC-ACM META port (/dev/ttyACM*)
#   3. links it as COM1 inside the prefix
#   4. pre-seeds HKLM\HARDWARE\DEVICEMAP\SERIALCOMM so ModemMETA/MauiMETA
#      can enumerate it even if SetupAPI emulation is incomplete
set -euo pipefail

PREFIX="${1:-$HOME/.wine-meta}"
export WINEPREFIX="$PREFIX"
export WINEARCH=win64

echo "== prefix: $PREFIX"
if [ ! -d "$PREFIX" ]; then
    wineboot -u >/dev/null 2>&1 || true
fi

# --- find the META serial port ------------------------------------------------
PORT=""
for p in /dev/ttyACM*; do
    [ -e "$p" ] || continue
    PORT="$p"
    break
done

if [ -z "$PORT" ]; then
    echo "!! no /dev/ttyACM* present."
    echo "   Put the phone into META mode first, e.g.:"
    echo "     mtk-venv/bin/python mtkclient/mtk.py da meta usb   (over BROM)"
    echo "   then plug in / power-cycle and re-run this script."
    exit 1
fi
echo "== META port: $PORT"

# --- map to COM1 --------------------------------------------------------------
mkdir -p "$PREFIX/dosdevices"
ln -sf "$PORT" "$PREFIX/dosdevices/com1"
echo "== $PREFIX/dosdevices/com1 -> $PORT"

# --- registry seeding ---------------------------------------------------------
# HKLM\HARDWARE\DEVICEMAP\SERIALCOMM : value names are the device names,
# data is the COM port string.
wine reg add 'HKLM\HARDWARE\DEVICEMAP\SERIALCOMM' /v "$(basename "$PORT")" \
     /t REG_SZ /d 'COM1' /f >/dev/null 2>&1 || true

echo "== registry:"
wine reg query 'HKLM\HARDWARE\DEVICEMAP\SERIALCOMM' 2>/dev/null || true

echo
echo "== done. launch the tool with:"
echo "   WINEPREFIX=$PREFIX wine /path/to/ModemMETA.exe"
