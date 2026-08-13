# FlightCore Control Platform

Current release candidate: 4.3.0 RC6 / Factory V69.

## Fresh install from macOS - one touch
Copy this single line into Terminal and press Enter:
```bash
tmp="$(mktemp "${TMPDIR:-/tmp}/flightcore-install.XXXXXX")"; curl -fsSL https://raw.githubusercontent.com/johbaa/SIYI_PI_Installer/main/install.sh -o "$tmp" && /bin/bash "$tmp"; rc=$?; rm -f "$tmp"; (exit "$rc")
```
The launcher asks for the Pi IP and SSH user, authenticates normally over SSH, pins the current immutable GitHub main commit, starts/verifies the live port-8090 Progress WebUI, opens it automatically, and shows the same live progress/activity plus elapsed time. Existing FlightCore systems upgrade through System -> Software update.
