# FlightCore 4.4.0 RC9

This repository contains the immutable five-file FlightCore `4.4.0-rc.9` release set.

RC9 supersedes failed immutable RC8. RC8's official public `install.sh` was the archive's internal installer, so native Software Update stopped at 0% while looking for the absent temporary companion `webui-ip.sh`. The failure occurred before archive download, transaction creation, backup, target modification or reboot.

RC9 restores the self-contained public bootstrap. It verifies its published SHA-256, downloads and verifies the manifest-selected archive and checksum, extracts the complete package, and invokes the internal installer beside every required companion file. An executable factory fixture now tests this complete path.

The RC8 runtime corrections are carried forward unchanged: the short-screen Control Center footer fix, bounded post-disarm cloud-log handoff, and persistent manually dismissed verified cloud-upload receipt with one voice announcement per uploaded log. RC9 does not intentionally change Air Link transport, LTE transmission logic, joystick behavior, or flight-controller failsafe authority.

The public repository contains exactly:

- `README.md`
- `install.sh`
- `manifest.json`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.9.tar.gz`
- `FLIGHTCORE_RPI_INSTALLER_RELEASE_4.4.0-rc.9.sha256`
