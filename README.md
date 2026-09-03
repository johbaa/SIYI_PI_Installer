# FlightCore 4.4.0 RC19

This repository contains the immutable five-file FlightCore `4.4.0-rc.19` release set.

RC19 adds an **Insert waypoint** map mode. Click a mission route segment to insert at that coordinate immediately before its later item. The inserted waypoint inherits the preceding waypoint's frame and altitude, becomes selected, and renumbers later items. Existing ArduPilot `MAV_CMD_DO_JUMP` targets shift when needed so they still reference the same logical item.

RC19 also adds an independent two-click **Measure A-B** tool. It shows one dashed line, A/B markers and Haversine ground distance in metres or kilometres until cleared or replaced. Measurement does not change the mission, dirty state, route distance, Cloud data or flight-controller state.

RC18's separate Jump-action editor, HOME/DO_JUMP semantics, 15-Jump limit, Cloud-only mission storage and confirmed-disarmed flight-controller boundary remain unchanged. FlightCore does not arm, start a mission, command RTL, change flight mode or modify flight-controller parameters.

The public repository contains exactly:

- `README.md`
- `install.sh`
- `manifest.json`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.19.tar.gz`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.19.sha256`
