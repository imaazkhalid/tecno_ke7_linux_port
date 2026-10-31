#!/usr/bin/env bash
# verify_firmware.sh — check a KE7 retail firmware directory against known hashes.
#
# Usage: ./tools/verify_firmware.sh [dir]
# Default dir: firmware/stock_retail/bin
set -u
DIR="${1:-$(cd "$(dirname "$0")/.." && pwd)/firmware/stock_retail/bin}"

declare -A H=(
  [boot.img]=56220382e730e85a3cc49afec1c53ab768020ba71fc9f0deed7187749a4a36f4
  [recovery.img]=e35e38d0494be5c7674591ebe925202c7ffce6e01c63891910152e603cc60433
  [dtbo.img]=1b4b7dbc59063621d7d4ddcda357de00846ff16af6b4bfe4ae276ae8600595e8
  [lk.img]=f977f6ef957960e9c19f08e889af1e5b9bf58366623ad7988ef37b8a1efedeed
  [md1img.img]=0ee98c40f275a66f193ee310f3e6695324f3e14d50e03965d620aaf5e3da872f
  [scp.img]=35c84d2adb100b8149f9ac63ae9e660db035aa28ce6aedbd915211f676259a51
  [sspm.img]=bfa5e6d9e92806646b283811c0b8e6964ef9e2c90b379a469b56f4accee88163
  [spmfw.img]=739cb96753135aa9b09dcd26d4178615cad727909c16c553e37ffec61937cf29
  [tee.img]=aa7f4f77614d795d0922a4728431c442d6c12115029e9a1aa731bc8f93e42793
  [vbmeta.img]=a712098cf1400073042e8fab38f03fc352522f9ca9dc9049e0e425b7532e601f
  [vbmeta_system.img]=1d39329b8b8fe5e862bb186d73b704dae3b4dd7831467b33f99df4b0631776aa
  [vbmeta_vendor.img]=3980ec5991e7e2f3077bd824fb9e132e8c6fa863aae72507f632c42047ea3f06
  [logo.bin]=a3743b474d0f6808f4ae2ff1169c5d3964c0d9d1e458d7d25aa3f2d70aaf9db2
  [cache.raw]=021dbf8b3a14bbf1f0fed8ea110afceca8b73096faa858cf229509627239a489
  [tranfs.raw]=f8f7c35b804aad36c83a10c351985b05c2e99f276b89e46b3e31d6f031cce526
)

echo "verifying $DIR"
fail=0
for f in "${!H[@]}"; do
  if [ ! -e "$DIR/$f" ]; then
    printf "  MISSING  %s\n" "$f"; fail=1; continue
  fi
  got=$(sha256sum "$DIR/$f" | cut -d' ' -f1)
  if [ "$got" = "${H[$f]}" ]; then
    printf "  ok       %s\n" "$f"
  else
    printf "  MISMATCH %s\n    expected %s\n    got      %s\n" "$f" "${H[$f]}" "$got"
    fail=1
  fi
done
echo
if [ "$fail" -eq 0 ]; then
  echo "All present files match the KE7-H693HJKM-Q-GL-220729V478 retail build."
else
  echo "Some files are missing or do not match. Do NOT flash a mixed set."
fi
exit "$fail"
