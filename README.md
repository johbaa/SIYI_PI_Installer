# FlightCore 4.4.0 RC28

RC28 corrects the packaging defect that caused RC27's first native upgrade to fail staged-install validation. RC27 carried different top-level and installed copies of `release-notes.md`; its installer correctly rolled the unit back to exact RC26.

RC28 requires every duplicated release metadata file to be byte-identical. The deterministic archive builder refuses a mismatch, and the installer repeats the gate before dependency preparation, service interruption, backup or target deployment.

The intended RC27 feature scope is carried forward unchanged:

- camera-frame-correct Home **H**, including SIYI earth/vehicle yaw-frame handling and continuous full-sphere edge motion;
- a browser-only simulated Home exactly 2 km ahead and 80 m below, available only while freshly connected and explicitly disarmed;
- local and Cloud UI 7 presentation of partial ECI/eNodeB/sector/TAC history without fabricated tower coordinates.

The public repository must contain exactly these five files:

- `README.md`
- `install.sh`
- `manifest.json`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.28.tar.gz`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.28.sha256`

RC28 supports the exact installed RC26 recovery route and the exact accepted RC24 route. Failed RC27 is not an upgrade source and must not be retried.

Operator order:

1. Run the RC28 publisher.
2. Run the independent RC28 publication verifier.
3. Run the exact RC26-to-RC28 or RC24-to-RC28 read-only preflight.
4. Only after PASS, install RC28 from FlightCore Software Update.
5. Run the post-upgrade checker, bench acceptance and controlled flight acceptance.

Do not power off the Raspberry Pi during installation or post-reboot verification.
