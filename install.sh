#!/usr/bin/env bash
set -euo pipefail

RAW_BASE="https://raw.githubusercontent.com/johbaa/SIYI_PI_Installer/main"
MANIFEST_URL="${RAW_BASE}/manifest.json"

cd /home/pi

CACHE_BUST="$(date +%s%N)"
echo
echo "Reading published SIYI release from GitHub..."
echo

VERSION="$(
  curl -fsSL \
    --connect-timeout 10 \
    --max-time 30 \
    -H 'Cache-Control: no-cache, no-store, max-age=0' \
    -H 'Pragma: no-cache' \
    "${MANIFEST_URL}?cache_bust=${CACHE_BUST}" |
  python3 -c '
import json, re, sys
try:
    data=json.load(sys.stdin)
    value=str(data.get("stable", "")).strip()
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", value):
        raise ValueError("manifest stable version is missing or invalid")
    print(value)
except Exception as exc:
    print(f"Unable to read published version: {exc}", file=sys.stderr)
    raise SystemExit(1)
'
)"

ARCHIVE="SIYI_RPI_INSTALLER_RELEASE_${VERSION}.tar.gz"
CHECKSUM="SIYI_RPI_INSTALLER_RELEASE_${VERSION}.sha256"
RELEASE_DIR="SIYI_RPI_INSTALLER_RELEASE_${VERSION}"

echo "Published version: ${VERSION}"
echo "Downloading ${ARCHIVE}..."

curl -fsSL --connect-timeout 15 --max-time 300 \
  -o "${ARCHIVE}" "${RAW_BASE}/${ARCHIVE}"
curl -fsSL --connect-timeout 15 --max-time 60 \
  -o "${CHECKSUM}" "${RAW_BASE}/${CHECKSUM}"

echo "Verifying SHA256 checksum..."
sha256sum -c "${CHECKSUM}"

rm -rf "${RELEASE_DIR}"
tar -xzf "${ARCHIVE}"

[ -d "${RELEASE_DIR}" ] || {
  echo "ERROR: Extracted release directory was not found: ${RELEASE_DIR}" >&2
  exit 1
}
[ -f "${RELEASE_DIR}/install.sh" ] || {
  echo "ERROR: Release installer was not found." >&2
  exit 1
}

cd "${RELEASE_DIR}"
chmod +x install.sh
exec ./install.sh
