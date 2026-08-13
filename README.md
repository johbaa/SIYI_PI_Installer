# FlightCore Control Platform

Current release candidate: 4.3.0 RC6 / Factory V71.

## Fresh install from macOS - one touch
Copy this single line into Terminal and press Enter:
```bash
tmp="$(mktemp "${TMPDIR:-/tmp}/flightcore-install.XXXXXX")"; curl -fsSL https://raw.githubusercontent.com/johbaa/SIYI_PI_Installer/main/install.sh -o "$tmp" && /bin/bash "$tmp"; rc=$?; rm -f "$tmp"; (exit "$rc")
```
The launcher handles target selection, stale SSH host keys, normal SSH authentication, immutable publication pinning, live port-8090 progress and First Setup opening. Existing FlightCore systems upgrade through System -> Software Update. Factory V71 also supports both exact published RC5/V64 and RC5/V65 variants for the shared registered RC5 build identity.
