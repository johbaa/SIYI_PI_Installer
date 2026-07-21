#!/usr/bin/env bash
set -Eeuo pipefail
RAW="https://raw.githubusercontent.com/johbaa/SIYI_PI_Installer/main"
cd /home/pi
curl -fsSL "$RAW/manifest.json" -o manifest.json
V="$(python3 -c 'import json;print(json.load(open("manifest.json"))["stable"])')"
A="SIYI_RPI_INSTALLER_RELEASE_${V}.tar.gz"; S="SIYI_RPI_INSTALLER_RELEASE_${V}.sha256"; D="SIYI_RPI_INSTALLER_RELEASE_${V}"
curl -fsSL "$RAW/$A" -o "$A"; curl -fsSL "$RAW/$S" -o "$S"
sha256sum -c "$S"; rm -rf "$D"; tar -xzf "$A"; cd "$D"; chmod +x install.sh; exec ./install.sh
