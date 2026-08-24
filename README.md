# FlightCore 4.3.0 RC38

Immutable candidate `4.3.0-rc.38` / `20260824.182435-dd98547`.

This public directory intentionally contains exactly five files. Verify `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.3.0-rc.38.sha256`, then use the resumable `install.sh`. RC38 retains RC37's integrated multi-unit rendering and makes the canonical `GroundStationWhepPlayer` the sole Air Link lifecycle owner. A decoded-frame stall now soft-resumes the existing media element without tearing down a healthy WHEP peer, stopping its track, or cloning the video element. Hard reconnect remains available for confirmed peer failure, sustained network disconnect, source-epoch change, and manual resync. Exact accepted RC37, RC36, and Registry-required RC6 upgrade routes are checksum-pinned; retained clean historical routes and fresh installation remain supported. Physical Android dual-stream and flight acceptance remain required.
