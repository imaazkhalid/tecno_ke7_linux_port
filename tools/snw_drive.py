#!/usr/bin/env python3
"""Drive the SN Writer GUI: agent supplies control rects, QMP provides real input."""
import json, os, subprocess, sys, time

DOM = "WINMETA"
URI = "qemu:///session"
if len(sys.argv) < 3:
    print("usage: snw_drive.py <IMEI1> <IMEI2>"); sys.exit(1)
IMEI1, IMEI2 = sys.argv[1], sys.argv[2]
VM = os.path.expanduser("~/tecno_ke7_linux_port/tools/vm_exec.py")

def qmp(payload):
    r = subprocess.run(["virsh", "-c", URI, "qemu-monitor-command", DOM, json.dumps(payload)],
                       capture_output=True, text=True, timeout=30)
    return r.stdout

def _click(x, y, sw, sh):
    qx, qy = int(x * 32768 / sw), int(y * 32768 / sh)
    qmp({"execute": "input-send-event", "arguments": {"events": [
        {"type": "abs", "data": {"axis": "x", "value": qx}},
        {"type": "abs", "data": {"axis": "y", "value": qy}}]}})
    time.sleep(0.15)
    qmp({"execute": "input-send-event", "arguments": {"events": [
        {"type": "btn", "data": {"down": True, "button": "left"}}]}})
    time.sleep(0.10)
    qmp({"execute": "input-send-event", "arguments": {"events": [
        {"type": "btn", "data": {"down": False, "button": "left"}}]}})

def move_click(x, y, sw, sh):
    # First click activates the window (click-through prevention eats it),
    # second click actually lands on the control.
    _click(x, y, sw, sh)
    time.sleep(0.35)
    _click(x, y, sw, sh)
    time.sleep(0.30)

def key(name, down=True):
    qmp({"execute": "input-send-event", "arguments": {"events": [
        {"type": "key", "data": {"down": down, "key": {"type": "qcode", "data": name}}}]}})

def tap(name):
    key(name, True); time.sleep(0.02); key(name, False); time.sleep(0.03)

QCODE = {c: c for c in "0123456789"}
QCODE.update({"-": "minus", ".": "dot"})

def type_text(s):
    for ch in s:
        tap(QCODE.get(ch, ch))

def ctrl_a():
    key("ctrl", True); time.sleep(0.03); tap("a"); key("ctrl", False); time.sleep(0.12)

def read_state():
    r = subprocess.run(["python3", VM, "get", r"C:\Users\mk\snw_state.txt", "/tmp/opencode/_state.txt"],
                       capture_output=True, text=True, timeout=60)
    try:
        return open("/tmp/opencode/_state.txt", encoding="utf-8-sig").read().strip()
    except Exception:
        return ""

def wait_rects(timeout=40):
    t0 = time.time()
    while time.time() - t0 < timeout:
        r = subprocess.run(["python3", VM, "get", r"C:\Users\mk\snw_rects.txt", "/tmp/opencode/_rects.txt"],
                           capture_output=True, text=True, timeout=60)
        try:
            parts = open("/tmp/opencode/_rects.txt").read().split()
        except Exception:
            parts = []
        if len(parts) >= 18 and parts[0].isdigit():
            return [int(x) for x in parts[:18]]
        time.sleep(1.5)
    return None

def main():
    print("waiting for dialog rects...")
    r = wait_rects()
    if not r:
        print("no rects"); return 1
    sw, sh, l1, t1, rr1, b1, l2, t2, rr2, b2, l3, t3, rr3, b3, dl, dt, dr, db = r
    print(f"screen {sw}x{sh} e1=({l1},{t1})-({rr1},{b1}) e2=({l2},{t2})-({rr2},{b2}) ok=({l3},{t3})-({rr3},{b3})")

    # focus IMEI_1 and type
    move_click((l1 + rr1) // 2, (t1 + b1) // 2, sw, sh)
    ctrl_a(); tap("delete")
    type_text(IMEI1)
    time.sleep(0.8)
    st = read_state()
    print("after IMEI1:", st)
    if f"t1={IMEI1}" not in st:
        print("IMEI1 mismatch, retry once")
        move_click((l1 + rr1) // 2, (t1 + b1) // 2, sw, sh)
        ctrl_a(); tap("delete"); type_text(IMEI1); time.sleep(0.8)
        print("retry:", read_state())

    move_click((l2 + rr2) // 2, (t2 + b2) // 2, sw, sh)
    ctrl_a(); tap("delete")
    type_text(IMEI2)
    time.sleep(0.8)
    st = read_state()
    print("after IMEI2:", st)
    if f"t2={IMEI2}" not in st:
        print("IMEI2 mismatch, retry once")
        move_click((l2 + rr2) // 2, (t2 + b2) // 2, sw, sh)
        ctrl_a(); tap("delete"); type_text(IMEI2); time.sleep(0.8)
        print("retry:", read_state())

    st = read_state()
    if f"t1={IMEI1}" not in st or f"t2={IMEI2}" not in st:
        print("FATAL: fields not set, not clicking OK"); return 2

    move_click((l3 + rr3) // 2, (t3 + b3) // 2, sw, sh)
    print("clicked OK")

    last = ""
    t0 = time.time()
    while time.time() - t0 < 150:
        st = read_state()
        if st != last:
            print(f"[{int(time.time()-t0):3d}s] {st}")
            last = st
        if "Pass" in st.upper() and "status=..." not in st:
            pass
        time.sleep(2.0)
    print("monitor window over")
    return 0

if __name__ == "__main__":
    sys.exit(main())
