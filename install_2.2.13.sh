#!/usr/bin/env bash
set -e

VER="2.2.13"
TAR="SIYI_PI_INSTALLER_RELEASE_${VER}.tar.gz"

cd "$(dirname "$0")"

if [ ! -f "$TAR" ]; then
  echo "Missing $TAR"
  exit 1
fi

rm -rf SIYI_PUBLIC_INSTALLER_V78B
tar -xzf "$TAR"
cd SIYI_PUBLIC_INSTALLER_V78B
bash ./install.sh
