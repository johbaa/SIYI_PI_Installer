#!/usr/bin/env bash
set -e

VERSION="2.2.7"
TARBALL="SIYI_PI_INSTALLER_RELEASE_${VERSION}.tar.gz"

cd /tmp

rm -rf SIYI_PUBLIC_INSTALLER_V78B

wget -O "$TARBALL" "https://github.com/johbaa/SIYI_PI_Installer/raw/main/$TARBALL"

tar -xzf "$TARBALL"

cd SIYI_PUBLIC_INSTALLER_V78B

chmod +x install.sh

./install.sh
