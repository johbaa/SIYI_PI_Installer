#!/usr/bin/env bash
set -Eeuo pipefail

REPO_RAW="https://raw.githubusercontent.com/johbaa/SIYI_PI_Installer/main"
WORKDIR="/home/pi"

cd "$WORKDIR"
curl -fsSL "$REPO_RAW/manifest.json" -o manifest.json

VERSION="$(
python3 - <<'PYVERSION'
import json
version=str(json.load(open("manifest.json")).get("stable") or "").strip()
if not version:
    raise SystemExit("manifest.json has no stable version")
print(version)
PYVERSION
)"

ARCHIVE="SIYI_RPI_INSTALLER_RELEASE_${VERSION}.tar.gz"
CHECKSUM="SIYI_RPI_INSTALLER_RELEASE_${VERSION}.sha256"
RELEASE_DIR="SIYI_RPI_INSTALLER_RELEASE_${VERSION}"

curl -fsSL "$REPO_RAW/$ARCHIVE" -o "$ARCHIVE"
curl -fsSL "$REPO_RAW/$CHECKSUM" -o "$CHECKSUM"
sha256sum -c "$CHECKSUM"
rm -rf "$RELEASE_DIR"
tar -xzf "$ARCHIVE"
cd "$RELEASE_DIR"
chmod +x install.sh
exec ./install.sh
