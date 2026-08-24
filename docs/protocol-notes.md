# FTMS protocol notes

## Authority

The Bluetooth SIG Fitness Machine Service 1.0.1 specification is the authoritative source for FTMS behavior:

- <https://www.bluetooth.com/specifications/specs/fitness-machine-service-1-0-1/>

This repository does not reproduce the specification. It records only project-specific implementation decisions and test evidence.

## MVP Treadmill Data contract

The Garmin apps consume notifications from the FTMS Treadmill Data characteristic (`0x2ACD`).

- The packet starts with a 16-bit little-endian flags field.
- One BLE notification is not necessarily one logical data record. For a record that exceeds the ATT-MTU payload, the first and intermediate notifications set More Data and the final notification clears it; instantaneous speed is omitted until that final notification. The transport must hold fragments in order and invoke the parser only after completion.
- A link loss while a record is fragmented discards the incomplete record. Reconnected notifications start a new record and must not reuse abandoned bytes.
- Optional fields are present and ordered according to those flags.
- Canonical internal units are meters/second for speed, meters for distance, and percent for incline.
- Zero is valid data; `null` means absent or unavailable.
- Fatal parse errors and warnings are separate. Missing optional data, unavailable incline, reserved flags, and diagnostic trailing bytes are warnings; missing flags, truncated flagged fields, and broken reassembly are fatal for the affected record. A sample with a fatal error cannot drive the UI or FIT contribution, even if earlier fields were decoded for diagnostics.
- Standard non-required (fields not being used) fields are safely skipped to preserve packet alignment.
- Reserved flag bits produce a warning.
- Unexpected trailing bytes produce a warning.
- An incline raw value of `0x7FFF` means FTMS Data Not Available; the parser exposes no incline value and records a warning.

## Fixture corpus

`protocol/fixtures/treadmill-data-vectors.json` contains language-neutral packet vectors used to document the protocol contract and support future firmware, transport, and parser tests.
