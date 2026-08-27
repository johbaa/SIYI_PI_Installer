# FlightCore 4.4.0 RC7

Immutable candidate `4.4.0-rc.7` / `20260827.002638-bf1d2c6`.

This directory intentionally contains exactly five files. The canonical public `install.sh` is the self-contained manifest/hash-pinned bootstrap; it downloads and verifies the selected release archive before invoking the internal package installer with all companion files present.

RC7 is the corrective successor to immutable RC6. It preserves the installed RC6 runtime while correcting the permanent acceptance-history writer to record the full release identity (`4.4.0-rc.7`) instead of the stable product version (`4.4.0`). The exact accepted RC6 build is an approved upgrade source, and the regression gate executes both the current release-identity path and the legacy metadata fallback while verifying root-only history permissions.

RC4 Turn Home, Smooth Voltage, Air Link, media, dual-stream, browser recording and flight-control behavior remain protected. RC5 and RC6 must not be republished under altered bytes.
