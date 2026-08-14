# FlightCore Control Platform

Current release candidate: 4.3.0 RC7 / Factory V75.

## Fresh install from macOS - one touch
```bash
tmp="$(mktemp "${TMPDIR:-/tmp}/flightcore-install.XXXXXX")"; curl -fsSL https://raw.githubusercontent.com/johbaa/SIYI_PI_Installer/main/install.sh -o "$tmp" && /bin/bash "$tmp"; rc=$?; rm -f "$tmp"; (exit "$rc")
```
Existing FlightCore systems upgrade through System -> Software Update. Factory V75 supports the exact global-Registry source set frozen on 14 August 2026: RC6/Factory V71 and RC7/Factory V74, plus fresh installation. V75 supersedes V74 and uses a factory-unique updater-visible build ID so V74 can discover this same-RC correction.
