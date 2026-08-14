# FlightCore Control Platform

Current release candidate: 4.3.0 RC7 / Factory V76.

## Fresh install from macOS - one touch
```bash
tmp="$(mktemp "${TMPDIR:-/tmp}/flightcore-install.XXXXXX")"; curl -fsSL https://raw.githubusercontent.com/johbaa/SIYI_PI_Installer/main/install.sh -o "$tmp" && /bin/bash "$tmp"; rc=$?; rm -f "$tmp"; (exit "$rc")
```
Existing FlightCore systems upgrade through System -> Software Update. Factory V76 is the consolidated RC7 rebuild from exact Factory V75 bytes. Its build-time compatibility matrix contains exact RC6/Factory V71 and exact RC7/Factory V75 plus fresh install; publication is blocked until the mandatory live global Device Registry freeze confirms that exact set. V76 corrects Air Link save/recovery and non-blocking UI behavior, restores explicit Restart Majestic, fixes unit-global battery setting persistence, Cloud telemetry-profile deletion and RC6 Cloud Flight Log opening, removes the obsolete Ext MAV reachability pill, and preserves the protected control/failsafe architecture.
