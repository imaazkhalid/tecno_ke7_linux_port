#!/system/bin/sh
# microG (ReVanced) has no foreground service, so Android's "Clear all" in Recents
# kills it and patched YouTube then shows the microG help page.
# This watchdog respawns it within ~15 s.

PKG=app.revanced.android.gms
# Exported service used only to spawn the process.
ACTION=app.revanced.android.gms.fitness.GoogleFitnessService.START

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 5; done
sleep 15

# Keep it exempt from Doze (idempotent).
dumpsys deviceidle whitelist +$PKG >/dev/null 2>&1

while true; do
  if ! pidof $PKG >/dev/null 2>&1; then
    am startservice --user 0 -a $ACTION >/dev/null 2>&1
  fi
  sleep 15
done
