# FlightCore 4.4.0 RC14

This repository contains the immutable five-file FlightCore `4.4.0-rc.14` release set.

RC14 refines Missions with a locally served map, draggable numbered waypoints, synchronized map/table route editing, named command and altitude-frame choices, field explanations, and explicit Local versus Cloud naming/save/open workflows.

Mission storage formats and cloud tenant enforcement are unchanged. Flight-controller transfer still reuses the existing Ground Station MAVLink session and remains blocked unless the aircraft is positively confirmed disarmed. FlightCore does not arm, start a mission, command RTL or change flight mode.

The public repository contains exactly:

- `README.md`
- `install.sh`
- `manifest.json`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.14.tar.gz`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.14.sha256`
