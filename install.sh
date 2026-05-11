#!/bin/bash
set -e

cd /tmp
rm -rf SIYI_PUBLIC_INSTALLER* SIYI_PI_INSTALLER* *.tar.gz

wget https://github.com/johbaa/SIYI_PI_Installer/raw/main/SIYI_PI_INSTALLER_RELEASE_2.2.1.tar.gz

tar -xzf SIYI_PI_INSTALLER_RELEASE_2.2.1.tar.gz

cd SIYI_PUBLIC_INSTALLER_V78B
chmod +x install.sh
./install.sh
