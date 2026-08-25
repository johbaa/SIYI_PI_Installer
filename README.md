# FlightCore 4.4.0 RC1

Immutable candidate `4.4.0-rc.1` / `20260825.185436-44a1c01`.

This directory intentionally contains exactly five files. The canonical public install.sh is the self-contained manifest/hash-pinned bootstrap; it downloads and verifies the selected release archive before invoking the internal package installer with all companion files present.

RC1 is built from exact accepted RC41. It stabilizes the one shared prediction used by Turn Home and Turning distance, while retaining RC41's flight-proven Air Link, media, dual-stream and browser behavior unchanged. Complete RC41 flight replay reduced p95 consecutive Turning-distance movement from 4.899 km to 0.582 km, with conservative safety reductions still immediate.
