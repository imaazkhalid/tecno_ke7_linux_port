#!/usr/bin/env python3
"""simg2raw.py — convert an Android sparse image to a raw image (streaming).

Usage: simg2raw.py <in.sparse> <out.raw>

Supports chunk types RAW (0xCAC1), FILL (0xCAC2), DONT_CARE (0xCAC3)
and CRC32 (0xCAC4).  Writes with large buffers so a 5 GB image is fine.
"""
import os
import struct
import sys

MAGIC = 0xED26FF3A
CHUNK_RAW = 0xCAC1
CHUNK_FILL = 0xCAC2
CHUNK_DONT_CARE = 0xCAC3
CHUNK_CRC32 = 0xCAC4


def main():
    src, dst = sys.argv[1], sys.argv[2]
    with open(src, "rb") as f:
        hdr = f.read(28)
        (magic, major, minor, fhdr, chdr, blk, total_blks,
         total_chunks, csum) = struct.unpack("<IHHHHIIII", hdr)
        if magic != MAGIC:
            raise SystemExit(f"not a sparse image: magic={magic:#x}")
        print(f"sparse v{major}.{minor} blk={blk} blocks={total_blks} "
              f"chunks={total_chunks} -> {total_blks * blk:,} bytes")
        zero = b"\0" * (1024 * 1024)
        written = 0
        with open(dst, "wb") as o:
            for n in range(total_chunks):
                ch = f.read(12)
                if len(ch) < 12:
                    raise SystemExit("truncated chunk header")
                ctype, _res, csz, tsz = struct.unpack("<HHII", ch)
                data_left = tsz - 12
                if ctype == CHUNK_RAW:
                    left = csz * blk
                    while left:
                        buf = f.read(min(1 << 20, left))
                        if not buf:
                            raise SystemExit("truncated raw chunk")
                        o.write(buf)
                        left -= len(buf)
                        written += len(buf)
                elif ctype == CHUNK_FILL:
                    val = f.read(4)
                    left = csz * blk
                    block = (val * ((1 << 20) // 4))[: 1 << 20]
                    while left:
                        n2 = min(len(block), left)
                        o.write(block[:n2])
                        left -= n2
                        written += n2
                elif ctype == CHUNK_DONT_CARE:
                    left = csz * blk
                    while left:
                        n2 = min(len(zero), left)
                        o.write(zero[:n2])
                        left -= n2
                        written += n2
                elif ctype == CHUNK_CRC32:
                    f.read(4)
                else:
                    raise SystemExit(f"unknown chunk type {ctype:#x}")
                if n % 500 == 0:
                    print(f"  chunk {n}/{total_chunks} written={written:,}", flush=True)
        expect = total_blks * blk
        print(f"done: {written:,} / {expect:,} bytes")
        if written != expect:
            raise SystemExit("size mismatch")
    return 0


if __name__ == "__main__":
    sys.exit(main())
