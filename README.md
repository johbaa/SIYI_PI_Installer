# FlightCore 4.4.0 RC17

This repository contains the immutable five-file FlightCore `4.4.0-rc.17` release set.

RC17 simplifies Missions storage to Cloud only in the visible UI, adds confirmed deletion of the selected tenant-scoped Cloud mission, and preserves pre-existing local mission files without exposing them. Cloud deletion never changes the editor or flight-controller mission.

`Jump to item` is now only a standalone ArduPilot `MAV_CMD_DO_JUMP` mission action. Ordinary waypoint details do not expose an obsolete duplicate Jump field. Target item number and additional repeats map directly to ArduPilot parameters 1 and 2; HOME sequence 0 remains hidden and preserved at the flight-controller boundary.

The inactive `My location` and `Add at map centre` controls are removed. Deliberate map-click placement, marker drag/select/delete, visible table headings and the map-dominant planner remain.

Mission transfer still reuses the existing Ground Station MAVLink session and remains blocked unless the aircraft is positively confirmed disarmed. FlightCore does not arm, start a mission, command RTL, change flight mode or modify flight-controller parameters.

The public repository contains exactly:

- `README.md`
- `install.sh`
- `manifest.json`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.17.tar.gz`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.17.sha256`
