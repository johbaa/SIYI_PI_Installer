# FlightCore Control Platform

Current release candidate: 4.3.0 RC7 / Factory V78.

## Fresh install from macOS - one touch
```bash
tmp="$(mktemp "${TMPDIR:-/tmp}/flightcore-install.XXXXXX")"; curl -fsSL https://raw.githubusercontent.com/johbaa/SIYI_PI_Installer/main/install.sh -o "$tmp" && /bin/bash "$tmp"; rc=$?; rm -f "$tmp"; (exit "$rc")
```
Existing FlightCore systems upgrade through System -> Software Update. Factory V78 is rebuilt from exact immutable Factory V77 bytes after V77 physical acceptance was rejected. V78 completely overhauls Settings persistence while preserving all six Settings sections and existing functional controls, assigns each Air Link control to one canonical Connectivity or Media owner with no duplication, retains Cloud Registry V10 with a real browser RC6-log open gate, and preserves the protected control/failsafe architecture. Build-time compatibility is exact RC6/Factory V71 + exact RC7/Factory V77 + fresh install; publication remains blocked until the live Device Registry freeze confirms that set.
