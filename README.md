# FlightCore 4.4.0 RC18

This repository contains the immutable five-file FlightCore `4.4.0-rc.18` release set.

RC18 corrects the Missions presentation found during RC17 bench testing. Ordinary Waypoint, Takeoff, Land and RTL details contain no Jump wording or control.

A selected standalone ArduPilot `MAV_CMD_DO_JUMP` (177) row opens a separate **Jump action** editor containing only **Jump back to item**, **Number of additional repeats**, its ArduPilot explanation and **Delete Jump action**. A Jump action has no waypoint Action selector, position, altitude or map marker.

ArduPilot HOME item 0, DO_JUMP param1/param2 semantics, the 15-Jump limit, cloud-only mission storage, tenant-scoped cloud delete and the confirmed-disarmed flight-controller boundary remain unchanged.

Mission transfer still reuses the existing Ground Station MAVLink session and remains blocked unless the aircraft is positively confirmed disarmed. FlightCore does not arm, start a mission, command RTL, change flight mode or modify flight-controller parameters.

The public repository contains exactly:

- `README.md`
- `install.sh`
- `manifest.json`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.18.tar.gz`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.18.sha256`
