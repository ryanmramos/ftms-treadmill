# FTMS protocol notes

## Authority

The Bluetooth SIG Fitness Machine Service 1.0.1 specification is the authoritative source for FTMS behavior:

- <https://www.bluetooth.com/specifications/specs/fitness-machine-service-1-0-1/>

This repository does not reproduce the specification. It records only project-specific implementation decisions and test evidence.

## MVP Treadmill Data contract

The Garmin apps consume notifications from the FTMS Treadmill Data characteristic (`0x2ACD`).

- The packet starts with a 16-bit little-endian flags field.
- Optional fields are present and ordered according to those flags.
- Canonical internal units are meters/second for speed, meters for distance, and percent for incline.
- Zero is valid data; `null` means absent or unavailable.
- A truncated field produces a parse warning and no partially trusted value.
- Standard non-required (fields not being used) fields are safely skipped to preserve packet alignment.
- Reserved flag bits produce a warning.
- Unexpected trailing bytes produce a warning.
- An incline raw value of `0x7FFF` means FTMS Data Not Available; the parser exposes no incline value and records a warning.

## Fixture corpus

`protocol/fixtures/treadmill-data-vectors.json` contains language-neutral packet vectors used to document the protocol contract and support future firmware, transport, and parser tests.