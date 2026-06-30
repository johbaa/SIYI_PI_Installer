#!/usr/bin/env bash
set -e

cd /home/pi

echo "Downloading SIYI RPi Installer 2.4.15..."

curl -fsSL -o SIYI_RPI_INSTALLER_RELEASE_2.4.15.tar.gz \
https://raw.githubusercontent.com/johbaa/SIYI_PI_Installer/main/SIYI_RPI_INSTALLER_RELEASE_2.4.15.tar.gz

tar -xzf SIYI_RPI_INSTALLER_RELEASE_2.4.15.tar.gz

cd SIYI_RPI_INSTALLER_RELEASE_2.4.15
chmod +x install.sh
exec ./install.sh
