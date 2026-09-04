# FlightCore 4.4.0 RC20

This repository contains the immutable five-file FlightCore `4.4.0-rc.20` release set.

RC20 adds passive 2 Hz flight-forensic evidence from telemetry already received by FlightCore: flight-state/touchdown changes, failsafe context, requested versus actual mode, mission sequence and `DO_JUMP` trace, navigation accuracy, aggregated control-path data, battery, GPS/EKF changes, canonical wind fields, warning classes and a per-flight configuration fingerprint.

Existing modem replies are normalized into LTE quality and serving-cell identity when exposed by the modem: RSRP, RSRQ, SINR, band, EARFCN, PCI, network mode, MCC, MNC, TAC, ECI, eNodeB and sector. Serving-cell changes create sparse handover events. Subscriber identifiers and secrets are excluded.

RC20 does not add a MAVLink stream/request, modem command/poll, active diagnostic, packet capture or in-flight upload, and does not change the 0.5-second sample period. RC19 Missions behavior and every protected flight-control boundary remain unchanged. Public tower resolution is supplied separately by the deployed FlightCore Cloud `4.4.0-cloud-ui.6`, after upload.

The public repository contains exactly:

- `README.md`
- `install.sh`
- `manifest.json`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.20.tar.gz`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.20.sha256`
