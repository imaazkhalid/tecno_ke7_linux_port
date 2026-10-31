# Legal, ethical and safety notes

> This is not legal advice. Laws differ by country. If you are unsure, ask a lawyer
> before touching a device that is not yours.

---

## 1. You may only modify hardware you own

Everything in this repository assumes the device belongs to you. Unlocking,
reflashing and modifying a phone you do not own can violate computer-misuse laws
even if the owner "would not mind".

## 2. IMEI rules

- **Restoring the original IMEI of your own device** is what this project documents.
  It is legitimate in many jurisdictions and is the only way to return a
  factory-wiped phone to service.
- **Changing an IMEI to a different value** — cloning, "repairing" a stolen phone,
  evading a blocklist — is illegal in most countries and is a criminal offence in
  many.
- Some countries regulate **any** IMEI write, including restoring your own. Check
  your local rules.
- Never publish an IMEI, IMSI or SIM identifier. This repository contains none, and
  neither should your fork.

## 3. Firmware and vendor binaries

- **No firmware, no vendor source, no vendor tools are included here.** The scripts
  expect *you* to supply the stock firmware you obtained legitimately.
- Vendor firmware is copyrighted. Do not redistribute it, and do not commit it to a
  public repository.
- The decompiled device trees in `dts/` are derived from the device you own and are
  published for interoperability and documentation. They are not a redistribution of
  the firmware image.
- The one-byte patch described in [imei-restore.md](imei-restore.md) is a
  interoperability fix for a tool you already own; it does not circumvent a
  technological protection measure protecting copyrighted works.

## 4. Bootloader unlocking and warranty

- Unlocking the bootloader **voids the manufacturer's warranty** and may trip
  attestation (SafetyNet/Play Integrity) permanently.
- The "orange state" warning is expected and cannot be removed without re-locking,
  which is dangerous on modified devices.

## 5. Brick risk

- The **preloader** (`boot0`/`boot1`) is the only stage that cannot be recovered from
  software. Never flash it.
- **`seccfg`**: write it once to unlock, never re-lock.
- **`otp` / `flashinfo` / `tkv`**: factory-unique. A wrong write is unrecoverable.
- Always keep a full partition backup before experimenting. The scripts in `tools/`
  snapshot the GPT and refuse to run when the device does not look like a KE7.

## 6. Privacy

This repository deliberately contains **no device-unique data**:

- no IMEI, IMSI, phone number or SIM identifier;
- no serial number;
- no MAC addresses of the original hardware (the example is locally administered);
- no partition dumps, calibration data or NVRAM images;
- no personal paths or credentials.

If you fork it, keep it that way.

## 7. Trademarks

Tecno, Spark, MediaTek, Helio, Arm, Mali, Android, Arch Linux and GNOME are
trademarks of their respective owners. This project is an independent
reverse-engineering effort and is not affiliated with or endorsed by any of them.

## 8. No warranty

The software and documentation are provided **"as is"**, without warranty of any
kind. The authors are not liable for bricked devices, lost data or legal
consequences. See [LICENSE](../LICENSE).
