#!/usr/bin/env python3
"""Preloader META handshake, correct direction: host sends METAMETA first,
preloader replies "READY" + reversed(seq[-3:]) = b"READYATE" for METAMETA."""
import os, sys, time, termios, glob, select

SEQ = b"METAMETA"
EXPECT = b"READY" + SEQ[:-4:-1]
TIMEOUT = float(sys.argv[1]) if len(sys.argv) > 1 else 300
LOG = "/tmp/opencode/premeta_try.log"

def log(msg):
    with open(LOG, "a") as f:
        f.write(msg + "\n")

def preloader_present():
    for d in glob.glob('/sys/bus/usb/devices/*/'):
        try:
            if open(d+'idVendor').read().strip() == "0e8d" and open(d+'idProduct').read().strip() == "2000":
                return True
        except Exception:
            pass
    return False

def open_raw(path):
    fd = os.open(path, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    a = termios.tcgetattr(fd)
    a[0] = 0; a[1] = 0
    a[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
    a[3] = 0
    a[4] = a[5] = termios.B115200
    a[6][termios.VMIN] = 0; a[6][termios.VTIME] = 1
    termios.tcsetattr(fd, termios.TCSANOW, a)
    termios.tcflush(fd, termios.TCIOFLUSH)
    return fd

open(LOG, "w").write(f"armed {time.strftime('%H:%M:%S')} expect={EXPECT!r}\n")
end = time.time() + TIMEOUT
while time.time() < end:
    if not preloader_present():
        time.sleep(0.02)
        continue
    log(f"preloader present {time.strftime('%H:%M:%S')}")
    for attempt in range(200):
        if not os.path.exists("/dev/ttyACM0"):
            time.sleep(0.02); continue
        try:
            fd = open_raw("/dev/ttyACM0")
        except Exception as e:
            time.sleep(0.03); continue
        try:
            os.write(fd, SEQ)
            buf = b""
            t0 = time.time()
            while time.time() - t0 < 0.15:
                r, _, _ = select.select([fd], [], [], 0.03)
                if r:
                    try:
                        buf += os.read(fd, 64)
                    except OSError:
                        break
            if buf:
                log(f"attempt {attempt}: RX {buf!r}")
            if EXPECT in buf:
                log(f"SUCCESS handshake {time.strftime('%H:%M:%S')}")
                os.close(fd)
                sys.exit(0)
        finally:
            try: os.close(fd)
            except Exception: pass
        time.sleep(0.02)
    log("preloader gone")
log("timeout")
sys.exit(1)
