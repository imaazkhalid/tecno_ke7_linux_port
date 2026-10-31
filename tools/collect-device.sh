#!/usr/bin/env bash
# collect-device.sh — deep hardware/driver data collection from a rooted KE7.
#
# Produces a timestamped directory with everything needed to write mainline
# drivers: kernel config, module list, clock/power/OPP/pinctrl/regulator state,
# bus topology, DRM/DSI state, audio/camera/sensor HAL dumps, firmware and
# vendor-module inventories, partition map and the live device tree.
#
# Usage:
#   ./tools/collect-device.sh                 # core (fast, ~100 MB)
#   ./tools/collect-device.sh --firmware      # also pull /vendor/firmware
#   ./tools/collect-device.sh --modules       # also pull vendor kernel modules
#   ./tools/collect-device.sh --all           # everything
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
ADB="${ADB:-adb}"
OUT="${OUT:-$REPO/hardware-dump/collect-$(date +%Y%m%d-%H%M)}"
DO_FW=0; DO_MOD=0
for a in "$@"; do
  case "$a" in
    --firmware) DO_FW=1 ;;
    --modules)  DO_MOD=1 ;;
    --all)      DO_FW=1; DO_MOD=1 ;;
  esac
done
mkdir -p "$OUT"

sh_()  { "$ADB" shell "$@" </dev/null 2>/dev/null | tr -d '\r'; }
su_()  { "$ADB" shell "su -c '$*'" </dev/null 2>/dev/null | tr -d '\r'; }
cap()  { local n="$1"; shift; su_ "$@" > "$OUT/$n" 2>/dev/null; [ -s "$OUT/$n" ] || rm -f "$OUT/$n"; }
caps() { local n="$1"; shift; sh_ "$@" > "$OUT/$n" 2>/dev/null; [ -s "$OUT/$n" ] || rm -f "$OUT/$n"; }
# binary-safe: copy to /sdcard (no pty) then adb pull (sync protocol)
capbin(){ local n="$1" p="$2" tmp="/sdcard/_collect_$n"
  su_ "cp $p $tmp; chmod 644 $tmp" >/dev/null 2>&1
  "$ADB" pull "$tmp" "$OUT/$n" >/dev/null 2>&1
  su_ "rm -f $tmp" >/dev/null 2>&1
  [ -s "$OUT/$n" ] || rm -f "$OUT/$n"; }

echo "collecting into $OUT"
"$ADB" devices | sed -n '2p'
su_ id | grep -q uid=0 || { echo "!! root required"; exit 1; }

# ---------- identity ----------
{ su_ getprop | sed 's/^\[//; s/\]: \[/= /; s/\]$//'; } > "$OUT/getprop.txt"
su_ uname -a            > "$OUT/uname.txt"
su_ cat /proc/version   > "$OUT/version.txt"
su_ cat /proc/cmdline   > "$OUT/cmdline.txt"
su_ cat /proc/partitions > "$OUT/partitions.txt"
su_ cat /proc/mounts    > "$OUT/mounts.txt"
su_ ls -l /dev/block/by-name > "$OUT/by-name.txt" 2>/dev/null

# ---------- kernel ----------
su_ "zcat /proc/config.gz" > "$OUT/kernel_config.gz.txt" 2>/dev/null
su_ cat /proc/modules   > "$OUT/proc_modules.txt"
su_ lsmod               > "$OUT/lsmod.txt"
su_ cat /proc/devices   > "$OUT/devices.txt"
su_ cat /proc/iomem     > "$OUT/iomem.txt"
su_ cat /proc/interrupts > "$OUT/interrupts.txt"
su_ cat /proc/softirqs  > "$OUT/softirqs.txt"
su_ cat /proc/bus/input/devices > "$OUT/input_devices.txt"
su_ dmesg               > "$OUT/dmesg.txt" 2>/dev/null || su_ "cat /proc/kmsg" > "$OUT/dmesg.txt" 2>/dev/null

# module parameters (driver knobs reveal hardware config)
mkdir -p "$OUT/module_params"
for m in $(su_ ls /sys/module); do
  params=$(su_ ls /sys/module/$m/parameters 2>/dev/null)
  [ -z "$params" ] && continue
  for p in $params; do
    printf "%-30s %-28s %s\n" "$m" "$p" "$(su_ cat /sys/module/$m/parameters/$p 2>/dev/null)"
  done
done > "$OUT/module_params.txt"

# ---------- clocks / power / opp / pinctrl ----------
cap clk_summary.txt        "cat /sys/kernel/debug/clk/clk_summary"
cap pm_genpd.txt           "cat /sys/kernel/debug/pm_genpd/pm_genpd_summary"
cap opp_summary.txt        "cat /sys/kernel/debug/opp/opp_summary"
cap regulator_summary.txt  "cat /sys/kernel/debug/regulator/regulator_summary"
cap gpio.txt               "cat /sys/kernel/debug/gpio"
cap dma.txt                "cat /sys/kernel/debug/dma"
cap suspend_stats.txt      "cat /sys/kernel/debug/suspend_stats"
cap pinctrl_all.txt        "for f in /sys/kernel/debug/pinctrl/*/pins /sys/kernel/debug/pinctrl/*/pinmux-pins /sys/kernel/debug/pinctrl/*/pinconf-pins; do echo ===\$f===; cat \$f; done"
cap devfreq.txt            "cat /sys/kernel/debug/devfreq/devfreq_summary 2>/dev/null || ls /sys/class/devfreq"
cap wakeup_sources.txt     "cat /sys/kernel/debug/wakeup_sources"

# ---------- buses / platform ----------
cap platform_devices.txt   "ls -l /sys/bus/platform/devices"
for f in /sys/bus/platform/devices/*/uevent; do
  echo "=== $f"; su_ "cat $f"
done > "$OUT/platform_uevents.txt" 2>/dev/null
cap i2c_devices.txt        "for d in /sys/bus/i2c/devices/*; do echo \$d \$(cat \$d/name 2>/dev/null); cat \$d/uevent 2>/dev/null; done"
cap spi_devices.txt        "for d in /sys/bus/spi/devices/*; do echo \$d \$(cat \$d/modalias 2>/dev/null); done"
cap mmc.txt                "for d in /sys/bus/mmc/devices/*; do echo ===\$d===; cat \$d/uevent 2>/dev/null; done"
cap thermal.txt            "for z in /sys/class/thermal/thermal_zone*; do echo \$z \$(cat \$z/type) \$(cat \$z/temp) \$(cat \$z/policy 2>/dev/null); done"
cap cooling_devices.txt    "for c in /sys/class/thermal/cooling_device*; do echo \$c \$(cat \$c/type) \$(cat \$c/cur_state) \$(cat \$c/max_state); done"
cap power_supply.txt       "for d in /sys/class/power_supply/*; do echo ===\$d===; cat \$d/uevent 2>/dev/null; done"
cap backlight.txt          "for b in /sys/class/backlight/*; do echo ===\$b===; cat \$b/max_brightness \$b/brightness 2>/dev/null; done"
cap leds.txt               "for l in /sys/class/leds/*; do echo \$l max=\$(cat \$l/max_brightness 2>/dev/null); done"
cap net.txt                "for n in /sys/class/net/*; do echo ===\$n===; cat \$n/address \$n/type \$n/uevent 2>/dev/null; done"
cap drm.txt                "for d in /sys/class/drm/*; do echo ===\$d===; cat \$d/status \$d/enabled \$d/modes 2>/dev/null; done"

# ---------- device tree ----------
capbin fdt.dtb             "/sys/firmware/fdt"
if [ -s "$OUT/fdt.dtb" ] && command -v dtc >/dev/null; then
  dtc -I dtb -O dts -o "$OUT/vendor.dts" "$OUT/fdt.dtb" 2>/dev/null || true
fi
capbin dtbo.img            "/dev/block/by-name/dtbo"

# ---------- display / DSI ----------
cap dsi_debug.txt          "for f in /d/dri/0/summary /d/dri/0/DSI-1/state /sys/kernel/debug/dri/0/summary; do [ -e \$f ] && { echo ===\$f===; cat \$f; }; done"
cap disp_debug.txt         "for f in /d/disp* /d/mtkfb* /proc/mtkfb; do [ -e \$f ] && { echo ===\$f===; cat \$f 2>/dev/null; }; done"

# ---------- audio ----------
caps dumpsys_audio.txt     "dumpsys media.audio_flinger"
caps dumpsys_audio_policy.txt "dumpsys audio"
cap tinymix.txt            "tinymix -D 0 2>/dev/null || true"
cap audio_cards.txt        "cat /proc/asound/cards; cat /proc/asound/pcm"
cap asoc_tree.txt          "find /d/asoc -maxdepth 3 2>/dev/null | head -200"
cap audio_routes.txt       "for c in /sys/class/sound/card*; do echo ===\$c===; cat \$c/id 2>/dev/null; done"

# ---------- camera ----------
caps dumpsys_camera.txt    "dumpsys media.camera"
cap camera_sensors.txt     "for f in /sys/class/camera/*/; do :; done; ls -l /dev/video* /dev/v4l* 2>/dev/null; getprop | grep -i camera"

# ---------- fingerprint ----------
caps dumpsys_fp.txt        "dumpsys fingerprint"
caps fp_hal.txt            "lshal | grep -i -A2 fingerprint"
cap fp_devices.txt         "ls -l /dev/*fp* /dev/sunwave_fp /dev/teei_fp 2>/dev/null; ls -l /sys/bus/spi/devices"
cap fp_spi.txt             "for d in /sys/bus/spi/devices/*; do echo ===\$d===; cat \$d/modalias \$d/uevent 2>/dev/null; done"

# ---------- sensors ----------
caps dumpsys_sensors.txt   "dumpsys sensorservice"
cap sensors_list.txt       "ls -l /sys/bus/iio/devices 2>/dev/null; getprop | grep -i sensor"
cap sensorlist.txt         "cat /dev/sensorlist 2>/dev/null | tr -s '\\0' '\\n' | sort -u"
cap sensor_class.txt       "for s in /sys/class/sensor/*; do echo \$s; done"

# ---------- connectivity ----------
caps dumpsys_wifi.txt      "dumpsys wifi | head -200"
caps dumpsys_bluetooth.txt "dumpsys bluetooth_manager | head -100"
cap wmt.txt                "cat /proc/driver/wmt* 2>/dev/null; ls -l /dev/stp* /dev/wmt* 2>/dev/null"
cap connsys.txt            "for f in /sys/kernel/debug/conninfra/* /sys/kernel/debug/connectivity/*; do [ -e \$f ] && { echo ===\$f===; cat \$f 2>/dev/null; }; done"

# ---------- HAL / vendor config ----------
caps lshal.txt             "lshal"
cap vendor_etc_list.txt    "find /vendor/etc -maxdepth 2 -type f | sort"
cap vendor_lib_list.txt    "find /vendor/lib /vendor/lib64 -maxdepth 2 -type f -name '*.so' | sort"
cap vendor_fw_list.txt     "find /vendor/firmware -type f -exec sha256sum {} + 2>/dev/null | sort -k2"
cap vendor_modules_list.txt "find /vendor/lib/modules /vendor/lib64/modules -type f -exec sha256sum {} + 2>/dev/null | sort -k2"

# pull interesting vendor configs (small xml/conf)
mkdir -p "$OUT/vendor_etc"
for f in $(su_ find /vendor/etc -maxdepth 2 -type f \( -name '*.xml' -o -name '*.conf' -o -name '*.cfg' -o -name '*.json' \) 2>/dev/null); do
  n=$(echo "$f" | sed 's#/vendor/etc/##; s#/#__#g')
  su_ "cat $f" > "$OUT/vendor_etc/$n" 2>/dev/null || rm -f "$OUT/vendor_etc/$n"
done

# ---------- optional big payloads ----------
if [ "$DO_FW" = 1 ]; then
  echo "pulling /vendor/firmware ..."
  mkdir -p "$OUT/firmware"
  "$ADB" shell "su -c 'tar -C /vendor -cf - firmware'" 2>/dev/null | tar -C "$OUT/firmware" -xf - 2>/dev/null || true
fi
if [ "$DO_MOD" = 1 ]; then
  echo "pulling vendor kernel modules ..."
  mkdir -p "$OUT/vendor_modules"
  "$ADB" shell "su -c 'tar -C /vendor/lib -cf - modules'" 2>/dev/null | tar -C "$OUT/vendor_modules" -xf - 2>/dev/null || true
fi

# ---------- manifest ----------
( cd "$OUT" && find . -type f -exec sha256sum {} + | sort -k2 ) > "$OUT/MANIFEST.sha256"
echo
echo "done: $OUT"
echo "files: $(wc -l < "$OUT/MANIFEST.sha256")"
du -sh "$OUT" 2>/dev/null
