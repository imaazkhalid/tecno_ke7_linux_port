#!/usr/bin/env python3
"""
MediaTek CCCI Modem Initialization Daemon / Script (ccci_mdinit.py)
Reverse-engineered from stock vendor/bin/ccci_mdinit on Tecno KE7 (MT6768)

Protocol Flow:
1. Opens /dev/ccci_monitor
2. Issues CCCI_IOC_SET_BOOT_DATA (0x4040432f) with 64-byte configuration buffer:
   - MD_CFG_MDLOG_MODE = 0
   - MD_CFG_SBP_CODE = 0
   - MD_CFG_DUMP_FLAG = 0
   - MD_CFG_RAT_CHK_FLAG = 0
3. Issues CCCI_IOC_DO_START_MD (0x430d) to kick off modem hardware boot sequence
4. Polls CCCI_IOC_GET_MD_STATE (0x80044301) until modem reaches READY (2)
"""

import os
import sys
import time
import fcntl
import struct
import logging

CCCI_IOC_MAGIC = ord('C')
CCCI_IOC_DO_START_MD = 0x430d          # _IO('C', 13)
CCCI_IOC_DO_STOP_MD  = 0x4004430e      # _IOW('C', 14, unsigned int)
CCCI_IOC_SET_BOOT_DATA = 0x4040432f    # _IOW('C', 47, unsigned int[16])
CCCI_IOC_GET_MD_STATE = 0x80044301     # _IOR('C', 1, unsigned int)

MD_STATE_NAMES = {
    0: "INVALID",
    1: "RESET",
    2: "READY",
    3: "BOOTING",
    4: "EXCEPTION",
    5: "WAITING_TO_STOP",
    6: "STOPPED",
}

def main():
    logging.basicConfig(level=logging.DEBUG, format='[ccci_mdinit] %(asctime)s %(levelname)s: %(message)s')
    log = logging.getLogger("ccci_mdinit")

    mon_dev = sys.argv[1] if len(sys.argv) > 1 else "/dev/ccci_monitor"
    
    if not os.path.exists(mon_dev):
        log.error("Monitor device %s does not exist. Is ccci.ko loaded?", mon_dev)
        sys.exit(1)

    log.info("Opening CCCI monitor device: %s", mon_dev)
    fd = os.open(mon_dev, os.O_RDWR)

    try:
        # Step 1: Set boot data (16 uint32s = 64 bytes)
        # Array layout: [mdlog_mode, sbp_code, dump_flag, rat_chk_flag, ...]
        boot_data = struct.pack("16I", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        log.info("Sending CCCI_IOC_SET_BOOT_DATA (0x%08x)...", CCCI_IOC_SET_BOOT_DATA)
        ret = fcntl.ioctl(fd, CCCI_IOC_SET_BOOT_DATA, boot_data)
        log.info("CCCI_IOC_SET_BOOT_DATA returned: %d", ret)

        # Step 2: Trigger modem start
        log.info("Sending CCCI_IOC_DO_START_MD (0x%08x)...", CCCI_IOC_DO_START_MD)
        ret = fcntl.ioctl(fd, CCCI_IOC_DO_START_MD, 0)
        log.info("CCCI_IOC_DO_START_MD returned: %d", ret)

        # Step 3: Monitor modem state
        log.info("Monitoring modem state...")
        buf = bytearray(4)
        for i in range(30):
            ret = fcntl.ioctl(fd, CCCI_IOC_GET_MD_STATE, buf, True)
            state = struct.unpack("I", buf)[0]
            name = MD_STATE_NAMES.get(state, f"UNKNOWN({state})")
            log.info("Modem state [%d/30]: %s (%d)", i+1, name, state)
            if state == 2:  # READY
                log.info("SUCCESS: Modem is READY!")
                break
            time.sleep(1)

    finally:
        os.close(fd)

if __name__ == "__main__":
    main()
