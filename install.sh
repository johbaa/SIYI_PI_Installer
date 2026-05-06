#!/bin/bash

set -e

cd /tmp

wget https://github.com/johbaa/SIYI_PI_Installer/raw/main/SIYI_PUBLIC_INSTALLER_V78J_APT_LOCK_SAFE_BATTERY_COPY_FIX.tar.gz

tar -xzf SIYI_PUBLIC_INSTALLER_V78J_APT_LOCK_SAFE_BATTERY_COPY_FIX.tar.gz

cd $(find . -maxdepth 1 -type d -name "SIYI_PUBLIC_INSTALLER*" | head -n 1)

chmod +x install.sh

./install.sh
