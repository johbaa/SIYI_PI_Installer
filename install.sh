#!/usr/bin/env bash
set -Eeuo pipefail
RAW_BASE="https://raw.githubusercontent.com/johbaa/SIYI_PI_Installer/main"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/flightcore-install.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"
curl -fsSLo manifest.json "$RAW_BASE/manifest.json"
VERSION="$(python3 -c 'import json;print(json.load(open("manifest.json"))["stable"])')"
ARCHIVE="SIYI_RPI_INSTALLER_RELEASE_${VERSION}.tar.gz"
CHECKSUM="SIYI_RPI_INSTALLER_RELEASE_${VERSION}.sha256"
curl -fsSLo "$ARCHIVE" "$RAW_BASE/$ARCHIVE"
curl -fsSLo "$CHECKSUM" "$RAW_BASE/$CHECKSUM"
sha256sum -c "$CHECKSUM"
tar -xzf "$ARCHIVE"
exec bash "$TMP/SIYI_RPI_INSTALLER_RELEASE_${VERSION}/install.sh" "$@"
