# FlightCore 4.4.0 RC32

RC32 replaces the published and installed RC31 after practical testing rejected its SIYI Home-marker geometry and found reboot-triggered replay of historical cloud-upload notices. RC31 remains a byte-exact recovery source only and is consumed and non-promotable.

RC32 changes two presentation paths:

- fixed Air Link and SIYI use explicit forward/right/down camera axes in North-East-Down coordinates;
- SIYI Earth yaw is absolute and vehicle yaw adds aircraft heading exactly once;
- live Home is hidden inside 5 m where direction is undefined;
- the 2 km no-GPS bench Home uses the exact live solver and is erased immediately when armed;
- historical cloud-upload receipts are baselined, and future acknowledgements persist on the device across reboots.

This repository must contain exactly five files:

- `README.md`
- `install.sh`
- `manifest.json`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.32.tar.gz`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.32.sha256`

The public `install.sh` is the self-contained bootstrap and must be byte-identical to `public-install.sh` inside the immutable archive. The internal payload installer is not a public bootstrap.

RC32 supports exact installed RC31, RC30, RC28 and RC26 recovery, exact accepted RC24, retained represented historical routes and genuine fresh installation. Modified and unknown sources fail closed.
