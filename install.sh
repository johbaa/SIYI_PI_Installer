#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_URL="https://raw.githubusercontent.com/johbaa/SIYI_PI_Installer/main"
MANIFEST_URL="${REPOSITORY_URL}/manifest.json"

cd /home/pi

echo
echo "Reading published release from GitHub..."
echo

VERSION="$(
    curl -fsSL "${MANIFEST_URL}" |
    python3 -c '
import json
import sys

try:
    data = json.load(sys.stdin)
    version = str(data.get("stable", "")).strip()

    if not version:
        raise ValueError("manifest does not contain a stable version")

    parts = version.split(".")
    if len(parts) != 3 or not all(part.isdigit() for part in parts):
        raise ValueError(f"invalid stable version: {version}")

    print(version)

except Exception as exc:
    print(f"Unable to read published version: {exc}", file=sys.stderr)
    sys.exit(1)
'
)"

ARCHIVE="SIYI_RPI_INSTALLER_RELEASE_${VERSION}.tar.gz"
CHECKSUM="SIYI_RPI_INSTALLER_RELEASE_${VERSION}.sha256"
DIR="SIYI_RPI_INSTALLER_RELEASE_${VERSION}"

echo "Published version: ${VERSION}"
echo
echo "Downloading ${ARCHIVE}..."
echo

curl -fsSL \
    -o "${ARCHIVE}" \
    "${REPOSITORY_URL}/${ARCHIVE}"

curl -fsSL \
    -o "${CHECKSUM}" \
    "${REPOSITORY_URL}/${CHECKSUM}"

echo
echo "Verifying SHA256 checksum..."
echo

sha256sum -c "${CHECKSUM}"

rm -rf "${DIR}"

tar -xzf "${ARCHIVE}"

if [[ ! -d "${DIR}" ]]; then
    echo "ERROR: Extracted directory not found: ${DIR}" >&2
    exit 1
fi

if [[ ! -f "${DIR}/install.sh" ]]; then
    echo "ERROR: Installer not found: ${DIR}/install.sh" >&2
    exit 1
fi

cd "${DIR}"

chmod +x install.sh

set +e
./install.sh
RC=$?
set -e

exit "${RC}"
```
