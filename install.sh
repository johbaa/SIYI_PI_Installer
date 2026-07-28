#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export LC_CTYPE=C.UTF-8

RAW="https://raw.githubusercontent.com/johbaa/SIYI_PI_Installer/main"

for cmd in curl python3 sha256sum tar; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Required command is missing: $cmd" >&2
    exit 1
  }
done

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/siyi-rpi-installer.XXXXXX")"
cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT INT TERM
cd "$WORK_DIR"

curl -fsSL "$RAW/manifest.json" -o manifest.json
VERSION="$(python3 - <<'PY'
import json
with open('manifest.json', encoding='utf-8') as handle:
    value = str(json.load(handle)['stable']).strip()
if not value or any(ch not in '0123456789.' for ch in value):
    raise SystemExit('Invalid stable release value in manifest.json')
print(value)
PY
)"

ARCHIVE="SIYI_RPI_INSTALLER_RELEASE_${VERSION}.tar.gz"
CHECKSUM="SIYI_RPI_INSTALLER_RELEASE_${VERSION}.sha256"
RELEASE_DIR="SIYI_RPI_INSTALLER_RELEASE_${VERSION}"

curl -fsSL "$RAW/$ARCHIVE" -o "$ARCHIVE"
curl -fsSL "$RAW/$CHECKSUM" -o "$CHECKSUM"
sha256sum -c "$CHECKSUM"

tar -xzf "$ARCHIVE"
INNER_INSTALLER="$WORK_DIR/$RELEASE_DIR/install.sh"
[ -f "$INNER_INSTALLER" ] || {
  echo "Release archive is missing $RELEASE_DIR/install.sh" >&2
  exit 1
}
chmod +x "$INNER_INSTALLER"

if [ "$(id -u)" -eq 0 ]; then
  bash "$INNER_INSTALLER" "$@"
else
  command -v sudo >/dev/null 2>&1 || {
    echo "sudo is required to install SIYI ${VERSION}." >&2
    exit 1
  }
  echo "Administrator access is required to install SIYI ${VERSION}."
  sudo -v
  sudo -- bash "$INNER_INSTALLER" "$@"
fi
