#!/usr/bin/env bash
set -euo pipefail

VERSION="2.2.4"
ARCHIVE="SIYI_PI_INSTALLER_RELEASE_${VERSION}.tar.gz"
REPO_RAW="https://raw.githubusercontent.com/johbaa/SIYI_PI_Installer/main"

cd /home/pi

echo
echo "Installing SIYI PI Control System ${VERSION}"
echo

rm -rf /home/pi/SIYI_PUBLIC_INSTALLER_V78B
rm -f "/home/pi/${ARCHIVE}"

echo "Downloading ${ARCHIVE}..."
curl -fL "${REPO_RAW}/${ARCHIVE}" -o "/home/pi/${ARCHIVE}"

echo "Extracting ${ARCHIVE}..."
tar -xzf "/home/pi/${ARCHIVE}"

cd /home/pi/SIYI_PUBLIC_INSTALLER_V78B
chmod +x ./install.sh

echo "Starting installer..."
exec ./install.sh
