#!/bin/bash
# backup-android-full.sh — one-folder, one-flash restore set for the current Android.
#
# Captures:
#   super.img.zst     (system/vendor/product — the debloated ROM state)
#   userdata.img.zst  (apps, Magisk modules, package-manager debloat state)
#   boot/recovery/vbmeta*/misc/seccfg/boot_para/proinfo (small, uncompressed)
#
# Restore: decompress + dd the two big images, then dd the small ones.
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
ADB="${ADB:-adb}"
OUT="$REPO/backup/android-full-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"

say() { printf "\n== %s\n" "$*"; }
dumpz() {
  local name="$1" part="$2"
  say "$name"
  "$ADB" exec-out "su -c 'dd if=/dev/block/by-name/$part bs=4M 2>/dev/null'" \
    | zstd -1 -T0 -o "$OUT/$name.img.zst" || { echo "!! $name failed"; return 1; }
  ls -lh "$OUT/$name.img.zst"
}
dumpsmall() {
  local part="$1"
  "$ADB" exec-out "su -c 'dd if=/dev/block/by-name/$part bs=1M 2>/dev/null'" \
    > "$OUT/$part.img" 2>/dev/null
  printf "   %-16s %s bytes\n" "$part" "$(stat -c%s "$OUT/$part.img")"
}

say "device"
"$ADB" devices | sed -n '2p'
"$ADB" shell "su -c id" 2>/dev/null | grep -q uid=0 || { echo "!! root required"; exit 1; }

dumpz super super
dumpz userdata userdata

say "small partitions"
for p in boot recovery vbmeta vbmeta_system vbmeta_vendor misc seccfg boot_para proinfo; do
  dumpsmall "$p"
done

say "manifest"
( cd "$OUT" && sha256sum * > MANIFEST.sha256 )
echo
echo "saved: $OUT"
du -sh "$OUT"
