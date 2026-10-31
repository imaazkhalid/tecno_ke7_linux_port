# IMEI restoration (MediaTek NV / META)

This is the story of bringing a phone back from "no IMEI at all" — and why the
obvious approaches cannot work.

> **Legal first:** this was done on a device we own, to restore its **original**
> IMEI printed on the box. Writing an IMEI that is not yours is illegal in most
> countries and is treated as device fraud. Read [legal.md](legal.md).

---

## 1. The problem

The phone arrived with every factory partition zeroed:

| Partition | Content | State |
|---|---|---|
| `nvram` (p26) | RF calibration, IMEI | all `0x00` |
| `nvdata` (p9) | modem NVRAM filesystem | all `0x00` |
| `nvcfg`, `persist`, `protect1/2` | config, MACs, keys | all `0x00` |

Consequences:

- Android shows **no IMEI** (`*#06#` empty, `AT+EGMR=0,7` returns `""`).
- The modem attaches with cause **6 `Illegal ME`** — the network rejects it.
- No RF calibration, so even a valid IMEI would need calibration data.

The modem hardware itself was fine: it booted, answered AT commands, and measured
signal (`AT+CSQ ≈ 24`).

---

## 2. Where the IMEI lives

MediaTek's modem NVRAM is a small filesystem of **NV items**, each identified by a
**LID** (logical ID). The IMEI is stored in the `NVD_IMEI` directory:

```
/mnt/vendor/nvdata/md/NVRAM/NVD_IMEI/NV0S_000
```

Decoded structure of `NV0S_000` (144 bytes on this unit):

| Offset | Value | Meaning |
|---|---|---|
| `0x00` | `LDI\0` | container magic |
| `0x04` | `0xF00A` | **LID** — `NVRAM_EF_IMEI_IMEISV_LID` |
| `0x08` | `2` | two records (dual SIM) |
| `0x0C` | `0x20` | record size (32 bytes) |
| `0x10` | `0x6081` | attributes (encrypted / checksummed) |

The modem API confirms the same record through META:
`META_NVRAM_GetRecLen(LID = "NVRAM_EF_IMEI_IMEISV_LID") = 10 bytes`.

So the **file** is a 32-byte container per SIM, but the **modem-side record** is
10 bytes (BCD digits + flags).

---

## 3. Why the records are encrypted

The attributes (`0x6081`) mark the record as protected. We verified:

- The AP-side library `libnvram_sec.so` exposes `sec_nvram_enc/dec` — both are
  **stubs** on this build; the AP never encrypts NV data.
- The key is derived **inside the modem** from OTP/SEJ/HACC material.
- On this unit the OTP key material is **blank** (wiped with the rest).
- Every publicly documented MTK NV AES key and derivation we tried produced records
  the modem rejected — the modem simply hangs or clears the item.

**Conclusion:** you cannot write a valid IMEI by editing `NV0S_000` or by patching
bytes in a partition image. Only the modem can produce a valid record.

---

## 4. Why you cannot just edit the file

We tried it. Writing a plaintext record into `NV0S_000` (and into a raw `nvdata`
image) makes the modem either:

- reject the item and re-initialise it, or
- **hang during HS2** because the checksum/encryption check fails inside the MD.

This is also why "restore `nvdata` from another phone" does not work: the record is
bound to the device's key material.

The only supported path is the **modem's own NVRAM API over META**.

---

## 5. Reaching META mode

Most guides get this wrong. The preloader handshake is **host-first**:

```
host  -> preloader : "METAMETA"
phone -> host      : "READY" + "ATEM0001" / "ATEM0002" / "ATEMATEX"
phone re-enumerates as 0e8d:202d  (META + ELT, two ACM ports)
```

If you wait for the phone to speak first, you will wait forever. The working script
is [`../tools/meta_handshake.py`](../tools/meta_handshake.py):

```bash
python3 tools/meta_handshake.py 300     # wait up to 5 min for 0e8d:2000
# power the phone off, then plug the cable (no keys held)
```

The same handshake works from Android with `adb reboot meta` **only if** the vendor
init wiring is present; on this unit it is not, so the preloader route is the one
that works.

---

## 6. The vendor tool and its TEE gate

With the phone in META, we used **SN Write Tool v1.2020.00** (the same engine as
ModemMETA) on a Windows 10 VM.

Two problems had to be solved:

### 6.1 The licensing gate

```
TEE stuff path: ...\tee_stuff
use VTurkeyLicenser
KPHA_Init failed            <- LibKPHA returns -3
```

The tool refuses to continue without a TEE provisioning licence (`vturkey` with an
all-zero keybox UUID). No licence exists for a decommissioned device.

**Bypass (1 byte):**

```
VA 0x4125e9   file offset 0x119e9
79 61  (jns 0x41264c)  ->  EB 61  (jmp 0x41264c)
```

The `KPHA_Init` result is the only thing checked; nothing later in the IMEI flow uses
TEE. With the jump forced, the tool proceeds to load the AP database, connect to the
modem, and write NV records.

### 6.2 The modem database

`SN_Setup.ini` must point at the **real** MDDB file shipped with the toolkit. The
failure mode `META_NVRAM_Init_Ex_Mdtype_r(): File read/write error` literally means
"file not found" — the ini referenced a longer filename than the file on disk.

Correct values (see [`../tools/SN_Setup.patched.ini`](../tools/SN_Setup.patched.ini)):

```ini
Already in Meta = True
Keep in Meta = True
IMEI Nums = 2
AP DB from DUT = False
MD DB from DUT = False
Ignore Database Inconsistent = True
```

---

## 7. The write

The tool performs, in one META session:

1. Read the current NV record (proves the path works).
2. Compose the new 10-byte record (BCD + flags).
3. Write it to the modem's NVRAM.
4. **Read it back and compare** — the tool's own PASS is authoritative.
5. Back up NVRAM to the BinRegion.
6. Write the same IMEIs into **`prod_info`** (`AP_CFG_REEB_PRODUCT_INFO_LID`,
   1024 bytes) with `sn_flag = 0x0005` (IMEI | Barcode | Pass).
7. Read `prod_info` back and verify.

The success log looks like this (values redacted):

```
Write_IMEI[<IMEI1>] ... Read_IMEI[<IMEI1>] ... Check nvram data PASS!!
Write_IMEI[<IMEI2>] ... Read_IMEI[<IMEI2>] ... Check nvram data PASS!!
Backup nvram successfully!!
Check prod_info data PASS!!
All Operate successfully!!
```

Because the write goes through the modem, the records are encrypted and signed
correctly — no key knowledge required.

---

## 8. Verification

On a booted Android:

```bash
adb shell "su -c 'service call iphonesubinfo 1'"    # returns the IMEI as UTF-16
adb shell dumpsys telephony.registry | grep -i mServiceState
```

A valid IMEI shows up as `IN_SERVICE` with a real operator. In our case the SIM
registered on LTE immediately after the write, which is the strongest end-to-end
proof.

---

## 9. Reusable takeaways

| Finding | Why it matters |
|---|---|
| META handshake is host-first (`METAMETA`) | every public guide that says otherwise is wrong |
| NV records are modem-encrypted (`attr 0x6081`) | file patching can never work |
| `NV0S_000` is a container; the modem record is 10 bytes | explains the 144-byte file |
| The TEE gate is a single branch | vendor tools can be made to work offline |
| `prod_info` also stores the IMEI | some ROMs read it instead of NV |
| The modem rejects attach with cause 6 without an IMEI | quick way to confirm the symptom |

Full experiments and dead ends: [`reference/project-log.md`](reference/project-log.md)
§38–41 and §52–55, and [`reference/hardware-research.md`](reference/hardware-research.md) §33.
