# FlightCore Control Platform

Current release candidate: 4.3.0 RC7 / Factory V77.

## Fresh install from macOS - one touch
```bash
tmp="$(mktemp "${TMPDIR:-/tmp}/flightcore-install.XXXXXX")"; curl -fsSL https://raw.githubusercontent.com/johbaa/SIYI_PI_Installer/main/install.sh -o "$tmp" && /bin/bash "$tmp"; rc=$?; rm -f "$tmp"; (exit "$rc")
```
Existing FlightCore systems upgrade through System -> Software Update. Factory V77 is rebuilt from exact immutable Factory V76 bytes after V76 physical acceptance was rejected. Its build-time compatibility matrix contains exact RC6/Factory V71 and exact RC7/Factory V76 plus fresh install; publication is blocked until the mandatory live global Device Registry freeze confirms that exact set. V77 makes Settings persistence independent of telemetry geometry and verifies durable read-back before success, repairs standalone Cloud Registry Flight Log runtime JavaScript, isolates the Air Link Device editor to Connectivity while Media remains camera-only, and preserves V76 Air Link desired-address persistence, Restart Majestic, Cloud profile deletion, Ext MAV pill removal, and the protected control/failsafe architecture.
