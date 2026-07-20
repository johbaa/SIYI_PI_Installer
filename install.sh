#!/usr/bin/env bash
set -Eeuo pipefail

REPO_RAW="https://raw.githubusercontent.com/johbaa/SIYI_PI_Installer/main"
WORKDIR="/home/pi"
MANIFEST="$WORKDIR/manifest.json"

cd "$WORKDIR"
curl -fsSL "$REPO_RAW/manifest.json" -o "$MANIFEST"

VERSION="$(
python3 - "$MANIFEST" <<'PYVERSION'
import json
import sys
version=str(
    json.load(open(sys.argv[1],encoding="utf-8")).get("stable") or ""
).strip()
if not version:
    raise SystemExit("manifest.json has no stable version")
print(version)
PYVERSION
)"

ARCHIVE="SIYI_RPI_INSTALLER_RELEASE_${VERSION}.tar.gz"
CHECKSUM="SIYI_RPI_INSTALLER_RELEASE_${VERSION}.sha256"
RELEASE_DIR="SIYI_RPI_INSTALLER_RELEASE_${VERSION}"

curl -fsSL "$REPO_RAW/$ARCHIVE" -o "$WORKDIR/$ARCHIVE"
curl -fsSL "$REPO_RAW/$CHECKSUM" -o "$WORKDIR/$CHECKSUM"

cd "$WORKDIR"
sha256sum -c "$CHECKSUM"
rm -rf "$RELEASE_DIR"
tar -xzf "$ARCHIVE"
cd "$RELEASE_DIR"
chmod +x install.sh
exec ./install.sh
