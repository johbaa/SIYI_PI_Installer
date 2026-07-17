#!/usr/bin/env bash
set -euo pipefail
REPO_RAW="https://raw.githubusercontent.com/johbaa/SIYI_PI_Installer/main"
WORKDIR="/home/pi"
MANIFEST="$WORKDIR/manifest.json"
cd "$WORKDIR"
curl -fsSL "$REPO_RAW/manifest.json" -o "$MANIFEST"
VERSION="$(python3 - "$MANIFEST" <<'PYVERSION'
import json,sys
v=str(json.load(open(sys.argv[1],encoding='utf-8')).get('stable') or '').strip()
if not v: raise SystemExit('manifest.json does not contain a stable version')
print(v)
PYVERSION
)"
ARCHIVE="SIYI_RPI_INSTALLER_RELEASE_${VERSION}.tar.gz"
CHECKSUM="SIYI_RPI_INSTALLER_RELEASE_${VERSION}.sha256"
RELEASE_DIR="SIYI_RPI_INSTALLER_RELEASE_${VERSION}"
curl -fsSL "$REPO_RAW/$ARCHIVE" -o "$WORKDIR/$ARCHIVE"
curl -fsSL "$REPO_RAW/$CHECKSUM" -o "$WORKDIR/$CHECKSUM"
sha256sum -c "$WORKDIR/$CHECKSUM"
rm -rf "$WORKDIR/$RELEASE_DIR"
tar -xzf "$WORKDIR/$ARCHIVE" -C "$WORKDIR"
cd "$WORKDIR/$RELEASE_DIR"
chmod +x install.sh
exec ./install.sh
