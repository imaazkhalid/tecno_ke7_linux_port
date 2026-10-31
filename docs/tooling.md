# Tooling

Everything in [`../tools/`](../tools) exists because a step was painful enough to
automate. This page explains what each tool does and the traps it avoids.

---

## 1. Inventory

| Tool | Purpose |
|---|---|
| `save-state.sh` | **snapshot boot/recovery/vbmeta/misc/NV to the laptop before any write** |
| `brom_check.sh` | detect `0e8d:0003` and print the GPT |
| `unlock_device.sh` | write `seccfg` (unlock) + a disabled `vbmeta` |
| `flash_retail.sh` | flash the retail Android ROM, preserving critical partitions |
| `flash_lk.sh` | pack and flash the U-Boot payload into `boot` (p30) |
| `restore_arch.sh` | restore the saved mainline state from a partition backup |
| `meta_handshake.py` | the real META handshake (`METAMETA` → `READY`) |
| `meta_reenter.sh` | handshake + attach the phone to the Windows VM |
| `vm_exec.py` | QEMU guest-agent command/file helper (runs as SYSTEM) |
| `vm_key.py` | QMP keyboard/mouse helper |
| `snw_prep.ps1` | launch SN Write Tool, open the IMEI dialog, report control rects |
| `snw_drive.py` | drive the IMEI dialog with real QMP input |
| `ccci_fsd.py` | userspace modem filesystem daemon (`/dev/ccci_fs`) |
| `ccci_mdinit.py` | modem boot sequencer |
| `atci_cli.c` | minimal AT client for the vendor `atcid` socket |
| `fast_proxy.py` | tiny HTTP proxy for the USB gadget network |
| `simg2raw.py`, `inspect_stock.py`, `inject_twrp_fw.py` | image helpers |

All scripts resolve paths relative to the repository root, so a fresh clone works
without editing.

---

## 2. BROM and flashing

`mtkclient` talks to the BootROM over USB. The phone must be **powered off** and
plugged in while holding **Volume Down + Volume Up**.

```bash
# sanity check: GPT + connection
./tools/brom_check.sh

# unlock (writes seccfg + disabled vbmeta) — one time
./tools/unlock_device.sh

# flash retail Android
./tools/flash_retail.sh

# restore the Linux state you saved earlier
./tools/restore_arch.sh
```

Hard rules encoded in the scripts:

- never write the preloader (`boot0`/`boot1`);
- never re-lock `seccfg`;
- verify the GPT looks like a KE7 before writing;
- snapshot the GPT before every operation.

**BROM mode is power-cycled by the tool itself** after a write. If the phone does not
come back, unplug, wait 10 s, and plug it in again without keys to catch the
preloader window.

---

## 3. META mode: the real handshake

The preloader exposes `0e8d:2000` for a short window. Most instructions online wait
for the phone to send something — it never does. **The host speaks first.**

```
host  -> "METAMETA"
phone -> "READY" "ATEM0001" "ATEM0002" "ATEMATEX"
phone re-enumerates as 0e8d:202d  (META + ELT, two ACM ports)
```

[`meta_handshake.py`](../tools/meta_handshake.py) does exactly this on a raw
`/dev/ttyACM0` at 115200 8N1:

```bash
python3 tools/meta_handshake.py 300      # 5-minute window
# power the phone off, then plug the cable — no keys held
```

Verify with `lsusb | grep 202d`. In META the phone exposes two serial ports; the
modem META channel is usually the second one.

### Attaching to the Windows VM

```bash
virsh -c qemu:///session attach-device WINMETA tools/vm-usb-meta.xml --live
```

The hostdev is lost on every VM reboot — re-attach after each start.

---

## 4. Windows VM automation (for the vendor tools)

The IMEI tool is Windows-only and GUI-only. Instead of clicking screenshots, we
automate it end-to-end.

```
vm_exec.py  (guest agent, SYSTEM)
    └── schtasks /ru <user> /it  ──►  GUI app in the interactive session
            └── snw_prep.ps1  ──►  clicks Start, reports control rectangles
                    └── snw_drive.py  ──►  real QMP input (clicks + typing)
                            └── logs read back through the guest agent
```

### 4.1 Guest agent

`vm_exec.py` uses `virsh qemu-agent-command` to run programs and move files.

```bash
python3 tools/vm_exec.py run cmd.exe /c ver
python3 tools/vm_exec.py put local.ini 'C:\path\in.ini'
python3 tools/vm_exec.py get 'C:\path\log.txt' ./log.txt
```

It runs as **SYSTEM** — no UAC prompts ever. GUI applications therefore cannot be
started directly (session 0); use a scheduled task with `/ru <user> /it`.

### 4.2 Talking to the GUI

`snw_prep.ps1` finds the main window (class `#32770`), clicks **Start** with
`BM_CLICK` on control `1002`, waits for the **Scan Data** dialog and reports the
rectangles of the IMEI fields (`1056`, `1058`) and **OK** (`1071`).

`snw_drive.py` converts those rectangles to QMP absolute coordinates and types with
real key events.

### 4.3 Traps (each one cost us a cycle)

| Trap | Symptom | Fix |
|---|---|---|
| `GetWindowText` from another process | returns `""` even when the field is full | never trust it; read the app's log or take a screenshot |
| `SetWindowText` | sets the visible text but the app validates an empty model | send **real key events** |
| First click on an inactive window | only activates the window | click twice |
| Scheduled-task console | steals foreground, clicks land on it | hidden VBS launcher or force the dialog `HWND_TOPMOST` |
| `guest-file-open` without close | file stays locked in the guest | close handles in `finally` (already fixed in `vm_exec.py`) |
| QMP `send-key` modifiers | Meta/Ctrl can stick | release modifiers explicitly, then `Esc` |
| Windows Update banner | covers the app and reboots the VM | disable `wuauserv`/`UsoSvc`, set `NoAutoRebootWithLoggedOnUsers=1` |
| **Concurrent USB pollers during BROM** | another tool (`fastboot devices`, a second watcher) opening the MTK USB device kills the DA upload: `Status error: Wrong magic` + `Device disconnected` | run exactly **one** mtkclient session; pre-arm it (`wait_for_device`) instead of polling USB yourself |

### 4.4 SN Write Tool configuration

[`SN_Setup.patched.ini`](../tools/SN_Setup.patched.ini):

```ini
Already in Meta = True
Keep in Meta = True
IMEI Nums = 2
AP DB from DUT = False
MD DB from DUT = False
Ignore Database Inconsistent = True
```

Plus the one-byte TEE bypass described in
[imei-restore.md](imei-restore.md#61-the-licensing-gate). The MDDB path must match
the **exact filename** on disk — `File read/write error` means "not found".

---

## 5. On-device tools

| Tool | Purpose |
|---|---|
| `ccci_fsd.py` | implements the FSD protocol on `/dev/ccci_fs` (modem filesystem) |
| `ccci_mdinit.py` | sequences the modem boot (queues, handshakes) |
| `atci_cli.c` | talks to the vendor `atcid` socket for AT commands |

They are copied to `/usr/local/bin/` on the device and started manually (see
[modem.md](modem.md#3-runbook-once-the-modem-starts)).

---

## 6. Writing your own helpers

Two rules make MTK automation survivable:

1. **Never trust a GUI read.** The application's own log file is the source of truth.
2. **Never assume a click landed.** Query the control rectangles from inside the
   guest, then convert to the input backend's coordinate space explicitly.

Both rules are implemented in `snw_*.py`/`snw_*.ps1` and are reusable for any other
vendor tool (SP Flash Tool, ModemMETA, etc.).
