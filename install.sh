#!/usr/bin/env bash
set -e

VERSION="2.6.1"
ARCHIVE="SIYI_RPI_INSTALLER_RELEASE_${VERSION}.tar.gz"
DIR="SIYI_RPI_INSTALLER_RELEASE_${VERSION}"

cd /home/pi

echo
echo "Downloading ${ARCHIVE}..."
echo

curl -fsSL \
    -o "${ARCHIVE}" \
    "https://raw.githubusercontent.com/johbaa/SIYI_PI_Installer/main/${ARCHIVE}"

rm -rf "${DIR}"

tar -xzf "${ARCHIVE}"

cd "${DIR}"

chmod +x install.sh

set +e
./install.sh
RC=$?
set -e

exit $RC
