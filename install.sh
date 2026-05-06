#!/bin/bash

set -e

cd /tmp

rm -rf SIYI_PUBLIC_INSTALLER* SIYI_PI_INSTALLER* *.tar.gz

wget https://github.com/johbaa/SIYI_PI_Installer/raw/main/SIYI_PI_INSTALLER_RELEASE_1.0.0.tar.gz

tar -xzf SIYI_PI_INSTALLER_RELEASE_1.0.0.tar.gz

cd $(find . -maxdepth 1 -type d \( -name "SIYI_PUBLIC_INSTALLER*" -o -name "SIYI_PI_INSTALLER*" \) | head -n 1)

chmod +x install.sh

./install.sh
