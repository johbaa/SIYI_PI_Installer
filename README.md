# FlightCore 4.4.0 RC31

RC31 corrects the SIYI Home-marker direction failure repeated on the published and installed RC30. RC30 remains an exact recovery source only and is consumed and non-promotable.

RC31 changes only the Home-marker presentation path:

- fixed Air Link uses the inverse aircraft attitude transform only;
- SIYI applies the MAVLink parent-to-camera transform directly without an Euler round-trip;
- SIYI vehicle frame converts Earth into aircraft heading exactly once without reapplying aircraft pitch or roll;
- visible and off-screen positions share one continuous projection ray;
- live and 2 km no-GPS bench Home use the same display path;
- arming, stale, unknown or disconnected arm state discards simulation immediately.

This repository must contain exactly five files:

- `README.md`
- `install.sh`
- `manifest.json`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.31.tar.gz`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.31.sha256`

The public `install.sh` is the self-contained bootstrap and must be byte-identical to `public-install.sh` inside the immutable archive. The internal payload installer is not a public bootstrap.

RC31 supports exact installed RC30, RC28 and RC26 recovery, exact accepted RC24, retained represented historical routes and genuine fresh installation. Modified and unknown sources fail closed.
