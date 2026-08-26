# FlightCore 4.4.0 RC4

Immutable candidate `4.4.0-rc.4` / `20260826.160745-5b68f7c`.

This directory intentionally contains exactly five files. The canonical public install.sh is the self-contained manifest/hash-pinned bootstrap; it downloads and verifies the selected release archive before invoking the internal package installer with all companion files present.

RC4 is built from the exact immutable RC3 parent. It waits for a settled raw-current cruise baseline, caps remaining energy at configured pack capacity, and displays Turning Distance as one-decimal km/mi. Turn Home time is derived afterward to the same heading-independent boundary. RC3 Air Link, media, dual-stream, browser and flight-control behavior is retained.
