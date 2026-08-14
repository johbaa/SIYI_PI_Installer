# FlightCore Control Platform

Current release candidate: 4.3.0 RC7 / Factory V79.

## Fresh install from macOS - one touch
```bash
tmp="$(mktemp "${TMPDIR:-/tmp}/flightcore-install.XXXXXX")"; curl -fsSL https://raw.githubusercontent.com/johbaa/SIYI_PI_Installer/main/install.sh -o "$tmp" && /bin/bash "$tmp"; rc=$?; rm -f "$tmp"; (exit "$rc")
```
Existing FlightCore systems upgrade through System -> Software Update. Factory V79 is a minimal installer/fingerprint correction from exact immutable Factory V78 bytes after V78 native upgrade was safely rejected and rolled back because a legitimate gimbal runtime atomic-write temporary file raced the source fingerprint. V79 preserves the complete V78 Settings persistence overhaul, canonical non-duplicated Air Link Connectivity/Media workspaces, Cloud Registry V10 and protected flight-control safety boundaries unchanged. Build-time compatibility remains exact RC6/Factory V71 + exact RC7/Factory V77 + fresh install because no Registry unit advanced to V78.
