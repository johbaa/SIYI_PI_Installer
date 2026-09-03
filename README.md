# FlightCore 4.4.0 RC16

This repository contains the immutable five-file FlightCore `4.4.0-rc.16` release set.

RC16 corrects the Missions acceptance issues found after RC15 publication. Flight-controller download now excludes only the ArduPilot HOME protocol item and preserves every following mission item, including `MAV_CMD_DO_JUMP`. Jump to item can be created and edited with target and repeat values, and upload preserves the flight controller's HOME item.

The planner is now map-dominant and QGC-inspired, with a narrow Plan panel, visible Item/Action/Details headings, a selected-item editor, draggable spatial markers, marker/row selection, and direct deletion of the selected item. Local, Cloud and Flight Controller operations are grouped clearly. The installer also repairs Local mission storage permissions.

Mission transfer still reuses the existing Ground Station MAVLink session and remains blocked unless the aircraft is positively confirmed disarmed. FlightCore does not arm, start a mission, command RTL, change flight mode or modify flight-controller parameters.

The public repository contains exactly:

- `README.md`
- `install.sh`
- `manifest.json`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.16.tar.gz`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.16.sha256`
