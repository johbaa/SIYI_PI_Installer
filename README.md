# FlightCore 4.4.0 RC23

FlightCore 4.4.0 RC23 is the immutable portability correction for RC22's local macOS publication-test failure. It upgrades only the exact accepted and Recovery-V5-verified RC19 build.

RC22's installer correction is retained: the canonical installed release tree is snapshotted before deployment and both rollback engines use the same checksummed helper. RC23 makes the extended-attribute portion of that tree fingerprint portable: native Python APIs are used where available, macOS uses its built-in `xattr` name/value interface, and missing backends fail closed.

The public repository must contain exactly these five files:

- `README.md`
- `install.sh`
- `manifest.json`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.23.tar.gz`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.23.sha256`

Approved upgrade path: `4.4.0-rc.19` build `20260903.133254-590c4c2`, status `accepted`, verified full release fingerprint `9d300f8b9935bc87b797352125d6f76f0a71745be11fd329cd7f87b444bd4cd0`, to `4.4.0-rc.23` build `20260905.210309-e72b309`.

RC20 failed during installation. RC21 was blocked before installation. RC22 stopped in its local publication gate before repository clone, commit or push. All three are consumed and are not authorized sources.

Operator order:

1. Run the RC23 publisher.
2. Run the independent RC23 publication verifier.
3. Run the RC19-to-RC23 read-only upgrade preflight.
4. Only after a PASS, install RC23 from the FlightCore Software Update page.
5. Run the post-upgrade check and complete physical acceptance.

Do not power off the Raspberry Pi during installation or post-reboot verification.
