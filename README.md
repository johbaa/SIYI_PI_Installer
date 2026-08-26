# FlightCore 4.4.0 RC5

Immutable candidate `4.4.0-rc.5` / `20260826.222946-5a2c178`.

This directory intentionally contains exactly five files. The canonical public `install.sh` is the self-contained manifest/hash-pinned bootstrap; it downloads and verifies the selected release archive before invoking the internal package installer with all companion files present.

RC5 is built from the exact immutable RC4 parent. It separates manual-command freshness from browser/GCS transport liveness: stale manual input stops after 650 ms, while source-255 transport remains alive for a bounded three-second recovery window before the native flight-controller failsafe is exposed. The UI distinguishes control-link recovery from actual aircraft-link loss and requires two seconds of stable telemetry before clearing a true connection-lost state. Browser/server timing diagnostics and atomic, provenance-complete flight-log finalization are included. RC4 Turn Home, Smooth Voltage, Air Link, media, dual-stream, browser recording, and flight-control behavior are retained.
