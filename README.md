# FlightCore 4.4.0 RC27

FlightCore RC27 corrects the field-failed RC26 Home-marker projection by honoring the SIYI gimbal's declared earth/vehicle yaw frame and applying aircraft attitude exactly once. The fixed forward Air Link camera remains aircraft-frame only, and the off-screen marker travels continuously around the edge.

The disarmed-only **Simulated Home — 2 km bench test** creates an imaginary Home exactly 2 km ahead and 80 m below the imaginary aircraft, follows live aircraft attitude and SIYI gimbal orientation, and requires no GPS fix. Armed, stale, unknown or disconnected arm state discards it immediately. It cannot modify FC Home, GPS, attitude, mode, mission or MAVLink navigation.

The local Flight Logs viewer now presents ECI/eNodeB/sector/TAC and signal history even when MCC/MNC are unavailable. The separately controlled Cloud UI 7 companion provides the corresponding Cloud presentation; it is not part of this five-file device publication.

The public repository must contain exactly these five files:

- `README.md`
- `install.sh`
- `manifest.json`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.27.tar.gz`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.27.sha256`

RC27 supports a byte-exact recovery upgrade from failed installed RC26 and retains the exact accepted RC24 route. RC26 is consumed and non-promotable; it is an authorized source only, never acceptance evidence.

Operator order:

1. Run the RC27 publisher.
2. Run the independent RC27 publication verifier.
3. Run the exact RC26-to-RC27 or RC24-to-RC27 read-only preflight.
4. Only after PASS, install RC27 from FlightCore Software Update.
5. Run the post-upgrade check, bench acceptance and controlled flight acceptance.

Do not power off the Raspberry Pi during installation or post-reboot verification.
