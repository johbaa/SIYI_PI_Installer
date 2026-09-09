# FlightCore 4.4.0 RC33

RC33 replaces the published and installed RC32 after practical testing showed that the SIYI Home marker was still incorrect in the bench test and that historical flight-log upload notices still replayed after reboot. RC32 is consumed and non-promotable; its exact bytes remain an authorized recovery source.

RC33 corrects both failed paths:

- live Home is rendered only while the aircraft is positively armed and an actual Home has been received;
- the no-GPS bench test is available only while positively disarmed, freezes an imaginary same-altitude Home exactly 2 km ahead, and is erased immediately on arming;
- the complete normalized ArduPilot gimbal quaternion is inverted directly for parent-to-camera projection, without an Euler reconstruction;
- only MAVLink system 1, component 1, gimbal device 1 is accepted, and stale, malformed or frame-ambiguous samples fail closed;
- the rear hemisphere follows one continuous side-to-bottom-centre-to-side perimeter path through 180 degrees;
- the installer baselines every pre-existing local and deferred flight by Flight ID, while each genuinely new receipt is atomically claimed in preserved device state before it is displayed or spoken.

This repository must contain exactly five files:

- `README.md`
- `install.sh`
- `manifest.json`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.33.tar.gz`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.33.sha256`

The public `install.sh` is the self-contained bootstrap and must be byte-identical to `public-install.sh` inside the immutable archive. The internal payload installer is not a public bootstrap.

RC33 supports exact installed RC32 as its primary recovery source, retained exact RC31, RC30, RC28 and RC26 recovery, exact accepted RC24, represented historical routes and genuine fresh installation. Modified and unknown sources fail closed.
