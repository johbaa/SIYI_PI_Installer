#!/usr/bin/env bash
set -e

cd /home/pi
tar -xzf SIYI_RPI_INSTALLER_RELEASE_2.4.15.tar.gz
cd SIYI_RPI_INSTALLER_RELEASE_2.4.15

chmod +x install.sh
./install.sh
