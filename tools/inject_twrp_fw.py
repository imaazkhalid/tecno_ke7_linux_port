#!/usr/bin/env python3
"""inject_twrp_fw.py — add touch firmware to a TWRP boot image safely.

Appends new cpio "newc" entries immediately before the TRAILER, so every
original entry stays byte-for-byte identical (no mode/ownership drift from
extract/repack).  Then rebuilds the Android boot image with the same kernel
(including the appended DTB) and a recomputed SHA1 id.

Usage: inject_twrp_fw.py <in.img> <out.img> <firmware.bin> [name]
"""
import hashlib
import os
import struct
import sys
import zlib

ALIGN = 4


def pad4(n):
    return (n + ALIGN - 1) & ~(ALIGN - 1)


def newc_entry(name, mode, data=b"", ino=1, mtime=0):
    nlen = len(name) + 1
    hdr = b"070701"
    fields = [ino, mode, 0, 0, 1 if mode & 0o040000 else 1, mtime,
              len(data), 0, 0, 0, 0, nlen, 0]
    hdr += b"".join(b"%08X" % f for f in fields)
    out = hdr + name.encode() + b"\0"
    out += b"\0" * (pad4(len(out)) - len(out))
    out += data
    out += b"\0" * (pad4(len(data)) - len(data))
    return out


def find_trailer_offset(cpio):
    off = 0
    while off + 110 <= len(cpio):
        if cpio[off:off + 6] not in (b"070701", b"070702"):
            raise SystemExit(f"bad cpio magic at {off:#x}")
        f = lambda i: int(cpio[off + 6 + i * 8: off + 6 + (i + 1) * 8], 16)
        size, nlen = f(6), f(11)
        name = cpio[off + 110: off + 110 + nlen - 1].decode("latin1")
        hdr = pad4(110 + nlen)
        if name == "TRAILER!!!":
            return off
        off += hdr + pad4(size)
    raise SystemExit("TRAILER not found")


def split_boot(d):
    (kern, ka, rds, ra, sec, sa, tags, page, hver, osv) = struct.unpack_from("<10I", d, 8)
    koff = page
    roff = koff + ((kern + page - 1) // page) * page
    soff = roff + ((rds + page - 1) // page) * page
    return dict(hdr=d[:page], kern=d[koff:koff + kern], ramdisk=d[roff:roff + rds],
                second=d[soff:soff + sec] if sec else b"", page=page,
                meta=dict(kern=kern, ka=ka, ra=ra, sa=sa, tags=tags, hver=hver, osv=osv))


def main():
    src, dst, fw = sys.argv[1], sys.argv[2], sys.argv[3]
    fw_name = sys.argv[4] if len(sys.argv) > 4 else os.path.basename(fw)
    d = open(src, "rb").read()
    b = split_boot(d)
    rd = b["ramdisk"]
    o = zlib.decompressobj(16 + zlib.MAX_WBITS)
    cpio = o.decompress(rd) + o.flush()
    print(f"ramdisk gz {len(rd)} -> cpio {len(cpio)} (tail {len(o.unused_data)})")

    toff = find_trailer_offset(cpio)
    print(f"TRAILER at {toff:#x}, original entries kept as-is")

    blob = open(fw, "rb").read()
    add = b""
    ino = 900000
    ino += 1; add += newc_entry("lib", 0o040755, ino=ino)
    ino += 1; add += newc_entry("lib/firmware", 0o040755, ino=ino)
    ino += 1; add += newc_entry("lib/firmware/" + fw_name, 0o100644, blob, ino=ino)
    ino += 1; add += newc_entry("system/etc/firmware", 0o040755, ino=ino)
    ino += 1; add += newc_entry("system/etc/firmware/" + fw_name, 0o100644, blob, ino=ino)

    new_cpio = cpio[:toff] + add + cpio[toff:]
    new_gz = __import__("gzip").compress(new_cpio, 9)
    print(f"new cpio {len(new_cpio)}, gz {len(new_gz)}")

    # rebuild boot image
    page = b["page"]
    hdr = bytearray(b["hdr"])
    struct.pack_into("<I", hdr, 16, len(new_gz))       # ramdisk_size
    id_ = hashlib.sha1(b["kern"] + new_gz + b["second"]).digest()
    hdr[576:608] = id_[:32]
    out = bytes(hdr) + b["kern"]
    out += b"\0" * (((len(out) + page - 1) // page) * page - len(out))
    out += new_gz
    out += b"\0" * (((len(out) + page - 1) // page) * page - len(out))
    if b["second"]:
        out += b["second"]
        out += b"\0" * (((len(out) + page - 1) // page) * page - len(out))
    open(dst, "wb").write(out)
    print(f"wrote {dst}: {len(out)} bytes (kernel {len(b['kern'])}, ramdisk {len(new_gz)})")


if __name__ == "__main__":
    main()
