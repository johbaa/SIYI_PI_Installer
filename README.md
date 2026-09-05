# FlightCore 4.4.0 RC24

FlightCore 4.4.0 RC24 is the immutable correction for the stale RC21 archive filename in RC23's delivered upgrade preflight. It upgrades only the exact accepted and Recovery-V5-verified RC19 build.

RC22's canonical release-tree rollback correction and RC23's macOS/Linux extended-attribute portability are retained. RC24's operator preflight derives the checksum filename from this candidate manifest. The Factory gate executes the validator extracted from the exact delivered preflight with the valid checksum, a wrong filename and a wrong digest.

The public repository must contain exactly these five files:

- `README.md`
- `install.sh`
- `manifest.json`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.24.tar.gz`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.24.sha256`

Approved upgrade path: `4.4.0-rc.19` build `20260903.133254-590c4c2`, status `accepted`, verified full release fingerprint `9d300f8b9935bc87b797352125d6f76f0a71745be11fd329cd7f87b444bd4cd0`, to `4.4.0-rc.24` build `20260905.212756-93deeb4`.

RC20 failed during installation. RC21 was blocked before installation. RC22 stopped in its local publication gate. RC23 was published but its delivered preflight rejected the correct checksum before SSH. All four are consumed and are not authorized sources.

Operator order:

1. Run the RC24 publisher.
2. Run the independent RC24 publication verifier.
3. Run the RC19-to-RC24 read-only upgrade preflight.
4. Only after a PASS, install RC24 from the FlightCore Software Update page.
5. Run the post-upgrade check and complete physical acceptance.

Do not power off the Raspberry Pi during installation or post-reboot verification.
