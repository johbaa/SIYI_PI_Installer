#!/usr/bin/env bash
set -euo pipefail

VER="2.2.13"
TAR="SIYI_PI_INSTALLER_RELEASE_${VER}.tar.gz"
REPO_RAW="https://raw.githubusercontent.com/johbaa/SIYI_PI_Installer/main"
URL="${REPO_RAW}/${TAR}"

cd "$(dirname "$0")"

if [ ! -f "$TAR" ]; then
  echo "Local ${TAR} not found. Downloading from GitHub..."
  curl -fL --retry 3 --retry-delay 2 -o "$TAR" "$URL"
fi

echo "Extracting ${TAR}..."
rm -rf SIYI_PUBLIC_INSTALLER_V78B
tar -xzf "$TAR"

cd SIYI_PUBLIC_INSTALLER_V78B

echo "Starting SIYI Pi installer ${VER}..."
chmod +x install.sh
./install.sh
