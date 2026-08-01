#!/usr/bin/env bash
set -euo pipefail
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export LC_CTYPE=C.UTF-8
RAW_BASE="https://raw.githubusercontent.com/johbaa/SIYI_PI_Installer/main"
MANIFEST_URL="$RAW_BASE/manifest.json"
WORK_DIR="/home/pi/siyi-github-install"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"
curl -fL --connect-timeout 10 --max-time 30 -o manifest.json "$MANIFEST_URL"
VERSION="$(python3 - <<'PYVERSION'
import json,re
with open('manifest.json',encoding='utf-8') as f: value=str(json.load(f).get('stable','')).strip()
if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+',value): raise SystemExit('manifest stable version is missing or invalid')
print(value)
PYVERSION
)"
ARCHIVE="SIYI_RPI_INSTALLER_RELEASE_${VERSION}.tar.gz"
CHECKSUM="SIYI_RPI_INSTALLER_RELEASE_${VERSION}.sha256"
DIR="SIYI_RPI_INSTALLER_RELEASE_${VERSION}"
echo "Downloading SIYI release ${VERSION}..."
curl -fL --connect-timeout 10 --max-time 900 -o "$ARCHIVE" "$RAW_BASE/$ARCHIVE"
curl -fL --connect-timeout 10 --max-time 30 -o "$CHECKSUM" "$RAW_BASE/$CHECKSUM"
EXPECTED="$(awk 'NR==1 {print $1}' "$CHECKSUM")"
ACTUAL="$(sha256sum "$ARCHIVE" | awk '{print $1}')"
[[ "$EXPECTED" =~ ^[0-9a-fA-F]{64}$ ]] || { echo "Invalid published SHA256 file" >&2; exit 1; }
[ "${EXPECTED,,}" = "${ACTUAL,,}" ] || { echo "SHA256 verification failed" >&2; exit 1; }
echo "SHA256 verified."
rm -rf "$DIR"
tar -xzf "$ARCHIVE"
cd "$DIR"
chmod +x install.sh
./install.sh "$@"
