# FlightCore 4.4.0 RC6

Immutable candidate `4.4.0-rc.6` / `20260826.213509-1fd2743`.

This directory intentionally contains exactly five files. The canonical public `install.sh` is the self-contained manifest/hash-pinned bootstrap; it downloads and verifies the selected release archive before invoking the internal package installer with all companion files present.

RC6 is the corrective successor to immutable, rejected RC5. It carries forward RC5's browser-joystick link handling and atomic flight-log completion without runtime modification. RC6 corrects the release archive so every manifest-declared directory—including empty parameter-import paths—is present in the final tarball, and adds a final-archive manifest gate that verifies every file, directory, symlink and checksum.

RC4 Turn Home, Smooth Voltage, Air Link, media, dual-stream, browser recording and flight-control behavior remain protected. RC5 must not be retried or republished.
