#!/usr/bin/env bash
# check-kernel.sh — verify the KE7 port still builds on a given kernel tree.
#
# This is the guard that keeps the device alive across LTS releases. Run it
# against every new LTS (and optionally linux-next as a compile canary).
#
# Usage:
#   ./tools/check-kernel.sh                 # build in ./linux
#   ./tools/check-kernel.sh /path/to/linux  # build in another tree
#   APPLY=1 ./tools/check-kernel.sh         # apply patches/linux/*.patch first
#   DTBS_CHECK=1 ./tools/check-kernel.sh    # also run dtbs_check (slow)
#
# Exit code 0 = the port builds.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TREE="${1:-$REPO/linux}"
CROSS="${CROSS_COMPILE:-aarch64-linux-gnu-}"
LOG="${LOG:-$REPO/hardware-dump/check-kernel-$(date +%Y%m%d-%H%M).log}"

mkdir -p "$(dirname "$LOG")"

say() { printf "\n== %s\n" "$*" | tee -a "$LOG"; }
run() { "$@" 2>&1 | tee -a "$LOG"; return "${PIPESTATUS[0]}"; }

[ -d "$TREE" ] || { echo "no kernel tree at $TREE"; exit 1; }
cd "$TREE"

say "kernel: $(make -s kernelversion 2>/dev/null || echo unknown)"
say "tree:   $TREE"

if [ "${APPLY:-0}" = "1" ]; then
  say "applying patches/linux/*.patch"
  for p in "$REPO"/patches/linux/*.patch; do
    [ -e "$p" ] || continue
    if git -C "$TREE" apply --check "$p" 2>/dev/null; then
      run git -C "$TREE" apply "$p" || exit 1
      echo "   applied $(basename "$p")"
    else
      echo "   skipped (already applied or conflicts): $(basename "$p")"
    fi
  done
fi

say "configuring"
# in-tree builds only (O= fails on trees that already contain build artifacts)
SAVED=""
if [ -f .config ]; then SAVED="$(mktemp)"; cp .config "$SAVED"; fi
restore_config() { [ -n "$SAVED" ] && cp "$SAVED" .config && rm -f "$SAVED"; }
trap restore_config EXIT

run make ARCH=arm64 CROSS_COMPILE="$CROSS" defconfig >/dev/null || exit 1
scripts/config --module DRM_PANEL_NOVATEK_NT36525B
run make ARCH=arm64 CROSS_COMPILE="$CROSS" olddefconfig >/dev/null || exit 1

say "building the KE7 DTB"
if ! run make ARCH=arm64 CROSS_COMPILE="$CROSS" -j"$(nproc)" mediatek/mt6768-tecno-ke7.dtb; then
  echo "FAIL: DTB does not build on this kernel"
  exit 1
fi

say "building the panel driver"
if ! run make ARCH=arm64 CROSS_COMPILE="$CROSS" -j"$(nproc)" \
        drivers/gpu/drm/panel/panel-novatek-nt36525b.o; then
  echo "FAIL: panel driver does not build on this kernel"
  exit 1
fi

if [ "${DTBS_CHECK:-0}" = "1" ]; then
  say "dtbs_check (warnings are reported, not fatal)"
  run make ARCH=arm64 CROSS_COMPILE="$CROSS" W=1 dtbs_check \
      DT_SCHEMA_FILES=mediatek/mt6768-tecno-ke7.dts || true
fi

say "OK — port builds on $(make -s kernelversion)"
echo "log: $LOG"
