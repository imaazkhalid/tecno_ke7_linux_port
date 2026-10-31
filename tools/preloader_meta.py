#!/usr/bin/env python3
"""
preloader_meta.py — catch the MTK preloader CDC port the moment it appears and
perform the META handshake over the serial port.

Protocol (from mtkclient's meta.py):
    preloader  -> "READY"
    host       -> "METAMETA"
    preloader  -> "METASLA" (SLA challenge)  or "ATEM..."  or "DISCONNECT"
    ... for Tecno the SLA secret is known, but first we just want to see
    whether READY arrives at all.

Usage: ./preloader_meta.py [seconds]
"""
import os, sys, time, select, termios, tty

DEV = "/dev/ttyACM0"
TIMEOUT = float(sys.argv[1]) if len(sys.argv) > 1 else 240

def usb_present(pid="2000"):
    """true when the MediaTek preloader is actually enumerated"""
    import glob
    for d in glob.glob('/sys/bus/usb/devices/*/'):
        try:
            vid = open(d + 'idVendor').read().strip()
            prd = open(d + 'idProduct').read().strip()
        except Exception:
            continue
        if vid == "0e8d" and prd == pid:
            return True
    return False

def wait_usb(timeout, pid="2000"):
    t0 = time.time()
    while time.time() - t0 < timeout:
        if usb_present(pid):
            return True
        time.sleep(0.02)
    return False

def wait_gone(timeout=20):
    """wait until a stale node disappears"""
    t0 = time.time()
    while time.time() - t0 < timeout:
        if not os.path.exists(DEV):
            return True
        time.sleep(0.05)
    return False

def wait_for_dev(timeout):
    t0 = time.time()
    while time.time() - t0 < timeout:
        if os.path.exists(DEV):
            return True
        time.sleep(0.02)
    return False

def open_raw(path):
    fd = os.open(path, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    try:
        attrs = termios.tcgetattr(fd)
        attrs[0] = 0                                  # iflag: raw
        attrs[1] = 0                                  # oflag: raw
        attrs[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
        attrs[3] = 0                                  # lflag: raw
        attrs[4] = attrs[5] = termios.B115200
        attrs[6][termios.VMIN] = 0
        attrs[6][termios.VTIME] = 1
        termios.tcsetattr(fd, termios.TCSANOW, attrs)
        termios.tcflush(fd, termios.TCIOFLUSH)
    except Exception as e:
        print("termios:", e)
    return fd

def main():
    print(f"waiting for preloader 0e8d:2000 (up to {TIMEOUT:.0f}s) ...", flush=True)
    if not wait_usb(TIMEOUT):
        print("!! preloader never enumerated")
        return 1
    # give devtmpfs a moment to create/refresh the node, then open fast
    time.sleep(0.05)
    if not os.path.exists(DEV):
        print("!! usb present but no", DEV)
        return 1

    print("== port appeared, opening", flush=True)
    try:
        fd = open_raw(DEV)
    except Exception as e:
        print("open failed:", e)
        return 1

    deadline = time.time() + 12
    buf = b""
    sent = False
    while time.time() < deadline:
        r, _, _ = select.select([fd], [], [], 0.2)
        if not r:
            continue
        try:
            chunk = os.read(fd, 256)
        except BlockingIOError:
            continue
        except OSError as e:
            print("read error:", e)
            break
        if not chunk:
            continue
        buf += chunk
        print("RX:", chunk[:64], flush=True)
        if b"READY" in buf and not sent:
            print("== got READY -> sending METAMETA", flush=True)
            os.write(fd, b"METAMETA")
            sent = True
            deadline = time.time() + 15
    os.close(fd)

    print("---- summary ----")
    if sent:
        print("handshake attempted. tail of data:", buf[-120:])
        return 0
    if buf:
        print("data but no READY:", buf[:120])
        return 2
    print("no data at all (preloader did not speak)")
    return 3

if __name__ == "__main__":
    sys.exit(main())
