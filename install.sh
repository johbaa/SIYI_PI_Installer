#!/usr/bin/env bash
set -Eeuo pipefail
# FLIGHTCORE_4_2_3_RC10_GITHUB_HEAD_PIN_V1
API_REF="https://api.github.com/repos/johbaa/SIYI_PI_Installer/git/ref/heads/main"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/flightcore-install.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"
HEAD_SHA="$(python3 - "$API_REF" <<'PYHEAD'
import json,re,sys,time,urllib.request
url=sys.argv[1] + ('&' if '?' in sys.argv[1] else '?') + 'cache_bust=' + str(time.time_ns())
req=urllib.request.Request(url,headers={'User-Agent':'FlightCore-Installer/4.3.0-RC2','Accept':'application/vnd.github+json','Cache-Control':'no-cache, no-store, max-age=0','Pragma':'no-cache'})
with urllib.request.urlopen(req,timeout=12) as r: data=json.loads(r.read(65536).decode('utf-8'))
sha=str((data.get('object') or {}).get('sha','')).strip()
if not re.fullmatch(r'[0-9a-fA-F]{40}',sha): raise SystemExit('invalid GitHub main commit SHA')
print(sha)
PYHEAD
)"
RAW_BASE="https://raw.githubusercontent.com/johbaa/SIYI_PI_Installer/${HEAD_SHA}"
curl -fsSL -H 'Cache-Control: no-cache, no-store' -H 'Pragma: no-cache' -o manifest.json "$RAW_BASE/manifest.json"
read -r VERSION ARCHIVE CHECKSUM < <(python3 - <<'PYMAN'
import json,re
m=json.load(open('manifest.json'))
version=str(m.get('stable','')).strip(); archive=str(m.get('archive','')).strip(); checksum=str(m.get('checksum','')).strip()
if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+',version): raise SystemExit('invalid manifest version')
expected=f'FLIGHTCORE_RPI_INSTALLER_RELEASE_{version}.tar.gz'
if archive!=expected or checksum!=expected.replace('.tar.gz','.sha256'): raise SystemExit('unexpected FlightCore release filenames')
print(version,archive,checksum)
PYMAN
)
curl -fsSL -H 'Cache-Control: no-cache, no-store' -H 'Pragma: no-cache' -o "$ARCHIVE" "$RAW_BASE/$ARCHIVE"
curl -fsSL -H 'Cache-Control: no-cache, no-store' -H 'Pragma: no-cache' -o "$CHECKSUM" "$RAW_BASE/$CHECKSUM"
sha256sum -c "$CHECKSUM"
ROOT="$(tar -tzf "$ARCHIVE" | awk -F/ 'NF{print $1;exit}')"
[[ "$ROOT" =~ ^[A-Za-z0-9._-]+$ ]] || { echo 'Unsafe archive root' >&2; exit 1; }
tar -xzf "$ARCHIVE"
exec bash "$TMP/$ROOT/install.sh" "$@"
