# FlightCore Control Platform

Current release candidate: 4.3.0 RC8 / Factory V81.

## Fresh install from macOS - one touch
```bash
tmp="$(mktemp "${TMPDIR:-/tmp}/flightcore-install.XXXXXX")"; curl -fsSL https://raw.githubusercontent.com/johbaa/SIYI_PI_Installer/main/install.sh -o "$tmp" && /bin/bash "$tmp"; rc=$?; rm -f "$tmp"; (exit "$rc")
```

Existing FlightCore systems upgrade through System -> Software Update. RC8/V81 derives from the exact immutable RC7/V79 public payload (7033ce31687919f76947d5fc8c349cc347cc438e60bafe039b3adb3d30531d86) and supports the build-time Registry set exact RC6/V71 + exact RC7/V79 + fresh install, pending live Registry compatibility freeze before publication. TURN HOME forecast assistance is experimental until provider/fallback/replay/flight acceptance passes.
