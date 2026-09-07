# FlightCore 4.4.0 RC30

RC30 corrects RC29's handover-only publication packaging defect. RC29's local publisher stopped before GitHub mutation because its public folder contained the full internal installer instead of the tested self-contained bootstrap. RC29 was never published or installed and is not an upgrade source.

RC30 retains the RC29 Home-marker implementation unchanged:

- direct normalized SIYI quaternion projection without an Euler round-trip;
- fixed Air Link uses aircraft attitude only;
- SIYI earth frame uses raw gimbal attitude;
- SIYI vehicle frame adds aircraft heading exactly once without reapplying aircraft pitch or roll;
- visible and off-screen positions share one continuous projection ray;
- live and 2 km no-GPS bench Home use the same display path;
- arming, stale, unknown or disconnected arm state discards simulation immediately.

This repository must contain exactly five files:

- `README.md`
- `install.sh`
- `manifest.json`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.30.tar.gz`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.30.sha256`

The public `install.sh` is the self-contained bootstrap and must be byte-identical to `public-install.sh` inside the immutable archive. The internal payload installer is not a public bootstrap.

RC30 supports exact installed RC28 and RC26 recovery, exact accepted RC24, retained represented historical routes and genuine fresh installation. Modified, unknown and RC29 sources fail closed.
