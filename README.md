# FlightCore 4.4.0 RC34

RC34 replaces the published and installed RC33 after practical bench testing proved that the SIYI device quaternion was being treated as the optical-camera frame. RC33 is consumed and non-promotable; its exact bytes remain an authorized recovery source.

RC34 corrects that failed path:

- the SIYI mechanically-forward device basis is converted into FlightCore's optical-camera FRD basis before aircraft heading is composed;
- yawing the aircraft right moves **H** left, yawing left moves **H** right, and a 180-degree yaw places **H** at bottom-centre;
- the correction is tested against the exact heading/quaternion samples captured from the RC33 test unit;
- the no-GPS bench test and armed live Home use the same final projection;
- the fixed Airlink camera path is unchanged and receives no SIYI basis correction;
- arming immediately erases simulated Home, and the feature remains presentation-only.

This repository must contain exactly five files:

- `README.md`
- `install.sh`
- `manifest.json`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.34.tar.gz`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.34.sha256`

The public `install.sh` is the self-contained bootstrap and must be byte-identical to `public-install.sh` inside the immutable archive. The internal payload installer is not a public bootstrap.

RC34 supports exact installed RC33 as its primary recovery source, retained exact RC32, RC31, RC30, RC28 and RC26 recovery, exact accepted RC24, represented historical routes and genuine fresh installation. Modified and unknown sources fail closed.
