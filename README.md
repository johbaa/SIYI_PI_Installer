# FlightCore 4.4.0 RC8

This repository contains the immutable five-file FlightCore `4.4.0-rc.8` release set.

RC8 is a corrective release based on the accepted RC7 route. It fixes the Control Center sidebar footer so navigation remains usable on small screens, makes completed flight logs eligible for cloud upload 20 seconds after disarm, and adds a verified, persistent, manually dismissed “safe to power off” receipt with a one-shot Ground Station voice announcement.

The receipt is produced only after the cloud has accepted the complete log and its SHA-256 checksum has been verified. RC8 does not intentionally change Air Link transport, LTE transmission logic, joystick behavior, or flight-controller failsafe behavior.

Public files:

- `README.md`
- `install.sh`
- `manifest.json`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.8.tar.gz`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.8.sha256`

The installer and WebUI Software Update path enforce the supported source route and post-reboot acceptance checks.
