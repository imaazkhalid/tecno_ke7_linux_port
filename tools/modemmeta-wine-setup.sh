#!/usr/bin/env bash
# modemmeta-wine-setup.sh — install ModemMETA into a dedicated Wine prefix,
# drop in the matching MT6768 modem database, and map the phone's META serial
# port to COM1.
#
# Usage: ./modemmeta-wine-setup.sh
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
FW="$REPO/firmware/stock_retail/KE7-H693HJKM-Q-GL-220729V478(MobiFirmware.com)"
ZIP="$HOME/Downloads/ModemMETA_v10.2044.0.02.zip"
EXTRACT="$HOME/Downloads/modemmeta"
EXE="$EXTRACT/ModemMETA_v10.2044.0.02/ModemMETA Setup.exe"

export WINEPREFIX="${WINEPREFIX:-$HOME/.wine-meta}"
export WINEARCH=win64
export WINEDEBUG=-all

echo "== prefix: $WINEPREFIX"
[ -d "$WINEPREFIX" ] || wineboot -u >/dev/null 2>&1

# ---- extract if needed -------------------------------------------------------
if [ ! -f "$EXE" ]; then
    echo "== extracting archive"
    mkdir -p "$EXTRACT"
    7z x -y -pMTKTOOL -o"$EXTRACT" "$ZIP" >/dev/null
fi
[ -f "$EXE" ] || { echo "!! installer not found"; exit 1; }

# ---- silent install ----------------------------------------------------------
INSTDIR="$WINEPREFIX/drive_c/ModemMETA"
if [ ! -d "$INSTDIR" ]; then
    echo "== running NSIS silent install (this takes a minute)"
    wine "$EXE" /S /D=C:\\ModemMETA >/dev/null 2>&1
    sleep 5
fi

if [ ! -d "$INSTDIR" ]; then
    echo ".. default path not used, searching for install dir"
    INSTDIR="$(find "$WINEPREFIX/drive_c" -maxdepth 3 -iname '*ModemMETA*' -type d 2>/dev/null | head -1)"
fi
[ -n "${INSTDIR:-}" ] && [ -d "$INSTDIR" ] || { echo "!! install dir not found"; exit 1; }
echo "== installed at: $INSTDIR"

# ---- copy modem databases ----------------------------------------------------
mkdir -p "$INSTDIR/database" "$INSTDIR/Database" 2>/dev/null
cp -v "$FW"/*.EDB   "$INSTDIR/database/" 2>/dev/null
cp -v "$FW"/APDB_*  "$INSTDIR/database/" 2>/dev/null
cp -v "$FW"/*.EDB   "$INSTDIR/Database/" 2>/dev/null
cp -v "$FW"/APDB_*  "$INSTDIR/Database/" 2>/dev/null

# ---- map serial port ---------------------------------------------------------
PORT=""
for p in /dev/ttyACM*; do [ -e "$p" ] && { PORT="$p"; break; }; done
if [ -n "$PORT" ]; then
    ln -sf "$PORT" "$WINEPREFIX/dosdevices/com1"
    wine reg add 'HKLM\HARDWARE\DEVICEMAP\SERIALCOMM' /v "$(basename "$PORT")" \
         /t REG_SZ /d 'COM1' /f >/dev/null 2>&1
    echo "== COM1 -> $PORT"
else
    echo "!! no /dev/ttyACM* yet - put the phone in META mode and re-run"
fi

echo
echo "== done. Launch with:"
echo "   WINEPREFIX=$WINEPREFIX wine \"$INSTDIR/ModemMETA.exe\""
ls -1 "$INSTDIR" | head -20
