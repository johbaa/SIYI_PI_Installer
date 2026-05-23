#!/usr/bin/env bash
set -e
cd /home/pi
tar -xzf SIYI_PI_INSTALLER_RELEASE_2.4.9.tar.gz
cd SIYI_PI_INSTALLER_2.4.9
chmod +x install.sh
./install.sh
