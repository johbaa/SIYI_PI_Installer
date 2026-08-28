# FlightCore 4.4.0 RC11

This repository contains the immutable five-file FlightCore `4.4.0-rc.11` release set.

RC11 supersedes RC10 after RC10's local macOS publication fixture entered the interactive fresh-install launcher and timed out before any repository clone, commit or push. RC11 explicitly selects the Linux/Pi archive-bootstrap branch during that factory-only execution test. Normal macOS and Pi installer behavior is unchanged.

RC11 retains RC10's lower-impact Flight Log implementation and strictly passive LTE diagnostics. LTE logging reuses only the results of existing router polls. It adds no request, ping, DNS lookup, throughput test, packet capture or other network probe. The existing 2-second status, 20-second context and 60-second network-mode cadence is unchanged.

The protected 50 Hz latest-state WebSocket path, 650 ms command withdrawal, three-second browser liveness boundary and native flight-controller failsafe authority are unchanged. RC11 sends no automatic mode or RTL command.

The public repository contains exactly:

- `README.md`
- `install.sh`
- `manifest.json`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.11.tar.gz`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.11.sha256`
