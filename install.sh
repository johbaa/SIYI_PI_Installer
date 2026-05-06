#!/bin/bash

set -e

cd /tmp

wget https://github.com/johbaa/SIYI_PI_Installer/raw/main/SIYI_PUBLIC_INSTALLER_V78B_FINAL_FIXED.tar.gz

tar -xzf SIYI_PUBLIC_INSTALLER_V78B_FINAL_FIXED.tar.gz

cd SIYI_PUBLIC_INSTALLER_V78B_FINAL_FIXED

chmod +x install.sh

./install.sh
