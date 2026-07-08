#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

tar -xzf SIYI_RPI_INSTALLER_RELEASE_2.5.0.tar.gz

cd SIYI_RPI_INSTALLER_RELEASE_2.5.0

chmod +x install.sh
exec ./install.sh
