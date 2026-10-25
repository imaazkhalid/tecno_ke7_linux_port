#!/usr/bin/env bash
# restore_arch.sh — put the phone back into the exact mainline state saved in
# backup/arch_state_20261025/ (see PROJECT_STATUS.md §33.2).
#
# Requires: mtkclient venv, BROM mode, device powered off, USB connected.
# Run from the repo root:  ./restore_arch.sh [--partitions-only]
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
B="$REPO/backup/arch_state_20261025"
M=(mtk-venv/bin/python mtkclient/mtk.py)
IP="${PHONE_IP:-}"

echo "== backup dir: $B"
[ -f "$B/gpt_primary.bin" ] || { echo "missing gpt_primary.bin"; exit 1; }

if [ "${1:-}" != "--partitions-only" ]; then
  echo "== 1) restore the GPT (BROM required)"
  "${M[@]}" w pgpt "$B/gpt_primary.bin"
  echo "   verifying..."
  "${M[@]}" printgpt | tee /tmp/gpt_after_restore.txt
  grep -q "rootfs" /tmp/gpt_after_restore.txt || {
    echo "!! GPT does not look right, stopping before writing partitions"; exit 1; }
fi

echo "== 2) restore user-area partitions p1..p36, p40, p41, p42"
for p in $(seq 1 36) 40 41 42; do
  f="$B/mmcblk0p$p.bin"
  [ -f "$f" ] || { echo "missing $f"; exit 1; }
  printf "   p%-3s %s bytes\n" "$p" "$(stat -c%s "$f")"
  "${M[@]}" w "mmcblk0p$p" "$f"
done

echo "== 3) restore preloader boot partitions (boot0/boot1)"
"${M[@]}" w boot0 "$B/mmcblk0boot0.bin"
"${M[@]}" w boot1 "$B/mmcblk0boot1.bin"

echo "== 4) reset"
"${M[@]}" reset

echo
echo "== 5) filesystems"
echo "   The raw dumps already contain the filesystems, so no untar is needed."
echo "   If you prefer a clean Arch: untar the tarballs instead:"
echo "     ssh root@\$IP 'mkfs.ext4 -L root /dev/mmcblk0p43'"
echo "     zstd -dc \"$B/rootfs.tar.zst\" | ssh root@\$IP 'tar -C / -xpf -'"
echo "     ssh root@\$IP 'mkfs.vfat /dev/mmcblk0p40'"
echo "     zstd -dc \"$B/esp.tar.zst\"  | ssh root@\$IP 'tar -C /boot -xpf -'"
echo
echo "== 6) verify identities after boot"
echo "   md5sum /dev/mmcblk0p30   # expect fda47596d4db7ddc1e9273d187f77682 (our U-Boot)"
echo "   md5sum /dev/mmcblk0boot0 # expect a7e48ea81d65d918520ad83576814224"
echo "   then: modprobe ccci; python3 /usr/local/bin/ccci_fsd.py & ; python3 /tmp/start_md.py"
