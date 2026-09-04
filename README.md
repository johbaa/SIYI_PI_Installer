# FlightCore 4.4.0 RC21

This repository contains the immutable five-file FlightCore `4.4.0-rc.21` release set.

RC21 is the corrective reissue of failed RC20. RC20 stopped at 40% because its payload manifest declared `release_identity` as `4.4.0-rc.20` while retaining `release_version` as `4.4.0-rc.19`. The installer rejected that inconsistency and completed transactional rollback to exact accepted RC19. RC20 is consumed, non-promotable and not an approved source.

RC21 makes the target release identity single-source across the payload manifest, installer, installed marker and bundled metadata. Factory qualification executes the actual target fingerprint against both the consistent RC21 manifest and a deliberately drifted manifest, and the final archive gate repeats the identity check before publication.

The passive logging and LTE-serving-cell functionality intended for RC20 is carried forward unchanged. RC21 adds no MAVLink stream or request, modem command or poll, active diagnostic, packet capture, in-flight upload, sample-rate change, flight-control change, mission change, or video change. Public tower resolution remains in the separately deployed FlightCore Cloud `4.4.0-cloud-ui.6`.

The public repository contains exactly:

- `README.md`
- `install.sh`
- `manifest.json`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.21.tar.gz`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.21.sha256`
