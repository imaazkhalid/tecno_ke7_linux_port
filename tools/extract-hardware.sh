#!/usr/bin/env bash
# extract-hardware.sh — reproduce this project's hardware inventory from YOUR phone.
#
# Runs against a booted, ROOTED stock Android (adb). Produces the same kind of
# dumps that live in hardware/dumps/, plus the vendor device tree.
#
# Usage:
#   ./tools/extract-hardware.sh [outdir]
#   ADB=./platform-tools/adb ./tools/extract-hardware.sh
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$REPO/hardware/dumps}"
ADB="${ADB:-adb}"

mkdir -p "$OUT"
say() { printf "\n== %s\n" "$*"; }
sh_() { "$ADB" shell "$@" 2>/dev/null; }
su_() { "$ADB" shell "su -c '$*'" 2>/dev/null; }
dump() { # dump <name> <command...>
  local name="$1"; shift
  if su_ "$@" > "$OUT/$name" && [ -s "$OUT/$name" ]; then
    echo "   ok   $name ($(wc -c <"$OUT/$name") bytes)"
  else
    echo "   --   $name (unavailable)"
    rm -f "$OUT/$name"
  fi
}

say "checking adb"
"$ADB" start-server >/dev/null 2>&1
"$ADB" devices | sed -n '2p'
if ! su_ id | grep -q "uid=0"; then
  echo "!! root required (Magisk). Enable it and retry."
  exit 1
fi
echo "   root ok"

say "device identity"
{ su_ getprop ro.product.model; su_ getprop ro.build.display.id; su_ getprop ro.board.platform; } \
  | tr -d '\r' > "$OUT/identity.txt"
cat "$OUT/identity.txt"

say "device tree"
su_ "cat /sys/firmware/fdt" > "$OUT/fdt.dtb" 2>/dev/null
if [ -s "$OUT/fdt.dtb" ]; then
  echo "   fdt.dtb $(wc -c <"$OUT/fdt.dtb") bytes"
  if command -v dtc >/dev/null; then
    dtc -I dtb -O dts -o "$OUT/vendor.dts" "$OUT/fdt.dtb" 2>/dev/null \
      && echo "   vendor.dts $(wc -l <"$OUT/vendor.dts") lines"
  else
    echo "   (install dtc to decompile: pacman -S dtc / apt install device-tree-compiler)"
  fi
else
  echo "   !! cannot read /sys/firmware/fdt"
fi

say "kernel and boot"
dump cmdline.txt      "cat /proc/cmdline"
dump dmesg.txt        "dmesg"
dump version.txt      "cat /proc/version"
dump config.gz        "cat /proc/config.gz"   # if present

say "interrupts and devices"
dump interrupts.txt   "cat /proc/interrupts"
dump input_devices.txt "cat /proc/bus/input/devices"
dump platform.txt     "ls -l /sys/bus/platform/devices"
dump i2c_names.txt    "for d in /sys/bus/i2c/devices/*; do echo \$d \$(cat \$d/name 2>/dev/null); done"
dump leds.txt         "for d in /sys/class/leds/*; do echo \$d max=\$(cat \$d/max_brightness 2>/dev/null); done"
dump thermal.txt      "for z in /sys/class/thermal/thermal_zone*; do echo \$z \$(cat \$z/type 2>/dev/null) \$(cat \$z/temp 2>/dev/null); done"

say "power"
dump power.txt        "for d in /sys/class/power_supply/*; do echo ===\$d===; cat \$d/uevent 2>/dev/null; done"
dump regulators.txt   "cat /sys/kernel/debug/regulator/regulator_summary"
dump gpio.txt         "cat /sys/kernel/debug/gpio"

say "HALs and subsystems"
dump lshal.txt        "lshal"
dump sensors.txt      "dumpsys sensorservice"
dump camera.txt       "dumpsys media.camera"
dump audio.txt        "dumpsys media.audio_flinger"
dump wifi.txt         "dumpsys wifi | head -100"

say "vendor configuration (xml/conf)"
for f in /vendor/etc/audio_policy_configuration.xml \
         /vendor/etc/audio_device.xml \
         /vendor/etc/media_profiles_V1_0.xml; do
  n=$(basename "$f")
  su_ "cat $f" > "$OUT/$n" 2>/dev/null || rm -f "$OUT/$n"
done
ls -1 "$OUT" | sed 's/^/   /'

say "done — $OUT"
echo
echo "Next: compare with docs/reference/hardware-inventory.md, then build your"
echo "own DTS from vendor.dts (see docs/porting-notes.md)."
