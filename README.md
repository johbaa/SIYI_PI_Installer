# FlightCore Control Platform

Current release candidate: 4.3.0 RC7 / Factory V74.

## Fresh install from macOS - one touch
```bash
tmp="$(mktemp "${TMPDIR:-/tmp}/flightcore-install.XXXXXX")"; curl -fsSL https://raw.githubusercontent.com/johbaa/SIYI_PI_Installer/main/install.sh -o "$tmp" && /bin/bash "$tmp"; rc=$?; rm -f "$tmp"; (exit "$rc")
```
Existing FlightCore systems upgrade through System -> Software Update. RC7/V74 upgrade compatibility is defined exclusively by the live global Device Registry freeze; the latest-known build-time set is exact accepted RC6/V71 only. Fresh install remains independently supported. V74 supersedes unpublished/untested V73.
