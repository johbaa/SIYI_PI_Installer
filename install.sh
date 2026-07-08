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

./install.sh

if [ -f /tmp/siyi_webui_update.log ]; then
cat > /tmp/siyi_webui_update.log <<EOF
Upgrade complete, current version ${VERSION}
EOF
sync
fi
