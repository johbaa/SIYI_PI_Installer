# FlightCore 4.4.0 RC13

This repository contains the immutable five-file FlightCore `4.4.0-rc.13` release set.

RC13 is the workflow-corrected release candidate for the functional scope first assembled as RC12. RC12 was not a complete authoritative handover and is permanently failed; its identity, build and artifacts must never be published, installed or reused. RC13 carries the same functional scope under a new release identity, build ID, source commit and hashes.

RC13 adds fail-closed fleet-membership proof with authoritative readback and audited, idempotent join/transfer operations. It also adds disarmed-only waypoint mission planning and upload through the existing Ground Station MAVLink session while preserving the existing upload receipt.

The protected 50 Hz latest-state WebSocket path, 650 ms command withdrawal, three-second browser liveness boundary and native flight-controller failsafe authority are unchanged. FlightCore sends no automatic mode or RTL command.

The public repository contains exactly:

- `README.md`
- `install.sh`
- `manifest.json`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.13.tar.gz`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.13.sha256`

