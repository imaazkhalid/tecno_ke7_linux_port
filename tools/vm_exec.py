#!/usr/bin/env python3
"""Fast VM control through the QEMU guest agent (no screenshots, no synthetic input).

Usage:
  vm_exec.py run <exe> [args...]          run a program, print stdout/stderr
  vm_exec.py ps                           list processes
  vm_exec.py put <hostfile> <guestpath>   write a file into the guest
  vm_exec.py get <guestpath> <hostfile>   read a file from the guest
"""
import base64, json, subprocess, sys, time

DOM = "WINMETA"
URI = "qemu:///session"

def qga(payload, timeout=60):
    r = subprocess.run(["virsh", "-c", URI, "qemu-agent-command", DOM, json.dumps(payload)],
                       capture_output=True, text=True, timeout=timeout)
    try:
        return json.loads(r.stdout)
    except Exception:
        return {"error": r.stdout + r.stderr}

def run(path, args, timeout=600):
    r = qga({"execute": "guest-exec", "arguments": {"path": path, "arg": args, "capture-output": True}})
    if "return" not in r:
        print("exec error:", r, file=sys.stderr); return 1
    pid = r["return"]["pid"]
    t0 = time.time()
    while time.time() - t0 < timeout:
        s = qga({"execute": "guest-exec-status", "arguments": {"pid": pid}})
        st = s.get("return", {})
        if st.get("exited"):
            out = base64.b64decode(st.get("out-data", "") or "").decode("utf-8", "replace")
            err = base64.b64decode(st.get("err-data", "") or "").decode("utf-8", "replace")
            sys.stdout.write(out)
            if err:
                sys.stderr.write(err)
            return st.get("exitcode", 0)
        time.sleep(0.15)
    print("timeout", file=sys.stderr); return 124

def put(hostfile, guestpath):
    data = open(hostfile, "rb").read()
    h = qga({"execute": "guest-file-open", "arguments": {"path": guestpath, "mode": "wb"}})
    if "return" not in h:
        print("open error:", h, file=sys.stderr); return 1
    handle = h["return"]
    # MAX_ARG_STRLEN is 128 KiB per argv entry; base64 expands 4/3.
    # 32 KiB raw -> ~43 KiB of base64, safely under the limit.
    STEP = 32768
    rc = 0
    try:
        for i in range(0, len(data), STEP):
            chunk = base64.b64encode(data[i:i+STEP]).decode()
            w = qga({"execute": "guest-file-write", "arguments": {"handle": handle, "buf-b64": chunk}}, timeout=120)
            if "return" not in w:
                print("write error:", w, file=sys.stderr); rc = 1; break
    finally:
        # Always release the handle or the guest file stays locked.
        qga({"execute": "guest-file-close", "arguments": {"handle": handle}})
    if rc == 0:
        print(f"wrote {len(data)} bytes -> {guestpath}")
    return rc

def get(guestpath, hostfile):
    h = qga({"execute": "guest-file-open", "arguments": {"path": guestpath, "mode": "rb"}})
    if "return" not in h:
        print("open error:", h, file=sys.stderr); return 1
    handle = h["return"]
    out = b""
    while True:
        r = qga({"execute": "guest-file-read", "arguments": {"handle": handle, "count": 1048576}}, timeout=120)
        if "return" not in r:
            print("read error:", r, file=sys.stderr); break
        out += base64.b64decode(r["return"].get("buf-b64", "") or "")
        if r["return"].get("eof"):
            break
    qga({"execute": "guest-file-close", "arguments": {"handle": handle}})
    open(hostfile, "wb").write(out)
    print(f"read {len(out)} bytes -> {hostfile}")
    return 0

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__); sys.exit(1)
    a = sys.argv[1]
    if a == "run":
        sys.exit(run(sys.argv[2], sys.argv[3:]))
    if a == "ps":
        sys.exit(run("cmd.exe", ["/c", "tasklist"]))
    if a == "put":
        sys.exit(put(sys.argv[2], sys.argv[3]))
    if a == "get":
        sys.exit(get(sys.argv[2], sys.argv[3]))
    print(__doc__)
