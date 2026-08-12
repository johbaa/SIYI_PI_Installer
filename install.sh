#!/usr/bin/env bash
set -Eeuo pipefail
# FLIGHTCORE_4_3_0_RC5_PUBLIC_INSTALLER_DUAL_MODE_V2
# FLIGHTCORE_4_3_0_RC5_PUBLIC_MAC_PROGRESS_WEBUI_LAUNCHER_V2
# FLIGHTCORE_4_2_3_RC10_GITHUB_HEAD_PIN_V1

REPO="johbaa/SIYI_PI_Installer"
API_REF="https://api.github.com/repos/${REPO}/git/ref/heads/main"
RAW_REPO="https://raw.githubusercontent.com/${REPO}"

resolve_head_sha() {
  if [[ "${FLIGHTCORE_PINNED_HEAD:-}" =~ ^[0-9a-fA-F]{40}$ ]]; then
    printf '%s\n' "$FLIGHTCORE_PINNED_HEAD"
    return 0
  fi
  local json sha
  json="$(curl -fsSL --max-time 15 \
    -H 'Accept: application/vnd.github+json' \
    -H 'Cache-Control: no-cache, no-store, max-age=0' \
    -H 'Pragma: no-cache' \
    "${API_REF}?cache_bust=$(date +%s)-$$")"
  sha="$(printf '%s\n' "$json" | sed -nE 's/.*"sha"[[:space:]]*:[[:space:]]*"([0-9a-fA-F]{40})".*/\1/p' | head -n1)"
  [[ "$sha" =~ ^[0-9a-fA-F]{40}$ ]] || { echo 'Unable to resolve immutable GitHub main commit SHA.' >&2; return 1; }
  printf '%s\n' "$sha"
}

if [[ "$(uname -s)" == "Darwin" ]]; then
  # Public fresh-install launcher for macOS. Browser is the primary progress UI.
  cd "$HOME/Downloads"
  TS="$(date '+%Y%m%d_%H%M%S')"
  LOG="$HOME/Downloads/FLIGHTCORE_4.3.0_RC5_FRESH_INSTALL_${TS}.txt"
  exec > >(tee "$LOG") 2>&1

  echo "FlightCore 4.3.0 RC5 - fresh installation launcher"
  echo "Progress is shown in the browser on port 8090."
  echo

  PI_USER="${PI_USER:-pi}"
  LAST_IP_FILE="$HOME/Downloads/.flightcore_last_pi_ip"
  SUGGESTED_IP=""
  if [[ -n "${PI_IP:-}" ]]; then
    SUGGESTED_IP="$PI_IP"
  elif [[ -s "$LAST_IP_FILE" ]]; then
    SUGGESTED_IP="$(tr -d '[:space:]' < "$LAST_IP_FILE")"
  fi

  echo "FlightCore target selection"
  if [[ -n "$SUGGESTED_IP" ]]; then printf 'Pi IP [%s]: ' "$SUGGESTED_IP"; else printf 'Pi IP: '; fi
  read -r CONFIRMED_IP
  PI_IP="${CONFIRMED_IP:-$SUGGESTED_IP}"
  [[ -n "$PI_IP" ]] || { echo 'ERROR: No Pi IP supplied.' >&2; exit 2; }
  printf '%s\n' "$PI_IP" > "$LAST_IP_FILE"
  echo "Confirmed target: ${PI_USER}@${PI_IP}"

  ASKPASS="$(mktemp "${TMPDIR:-/tmp}/fcaskpass.XXXXXX")"
  cleanup_mac(){ rm -f "$ASKPASS"; }
  trap cleanup_mac EXIT
  printf '#!/bin/sh\nprintf "%%s\\n" raspberry\n' > "$ASKPASS"
  chmod 700 "$ASKPASS"
  export SSH_ASKPASS="$ASKPASS"
  export SSH_ASKPASS_REQUIRE=force
  export DISPLAY="${DISPLAY:-:0}"
  SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -o ServerAliveInterval=5 -o ServerAliveCountMax=2)

  echo
  echo "Waiting for SSH at ${PI_USER}@${PI_IP} ..."
  while true; do
    if ssh -T "${SSH_OPTS[@]}" "$PI_USER@$PI_IP" true </dev/null >/dev/null 2>&1; then
      echo "SSH available."
      break
    fi
    echo "Waiting for SSH... $(date '+%H:%M:%S')"
    sleep 5
  done

  # This public path is the end-user fresh-install path. Existing FlightCore
  # systems upgrade through System -> Software update instead.
  if ssh -T "${SSH_OPTS[@]}" "$PI_USER@$PI_IP" 'test -e /etc/siyi/release_version -o -e /home/pi/siyi-webui/server.py' </dev/null >/dev/null 2>&1; then
    echo "ERROR: FlightCore is already installed on this target." >&2
    echo "Use System -> Software update for an existing FlightCore installation." >&2
    exit 3
  fi

  echo "Resolving current GitHub release commit..."
  HEAD_SHA="$(resolve_head_sha)"
  [[ "$HEAD_SHA" =~ ^[0-9a-fA-F]{40}$ ]] || { echo 'ERROR: invalid GitHub commit SHA.' >&2; exit 1; }
  echo "Pinned GitHub commit: $HEAD_SHA"
  RAW_BASE="${RAW_REPO}/${HEAD_SHA}"

  REMOTE_CMD="set -Eeuo pipefail; curl -fsSL -H 'Cache-Control: no-cache, no-store' -H 'Pragma: no-cache' '${RAW_BASE}/install.sh' | FLIGHTCORE_PINNED_HEAD='${HEAD_SHA}' bash"
  echo "Starting commit-pinned FlightCore installer on Pi..."
  set +e
  ssh -T "${SSH_OPTS[@]}" "$PI_USER@$PI_IP" "$REMOTE_CMD" </dev/null &
  SSH_PID=$!
  set -e

  PROGRESS_URL="http://${PI_IP}:8090"
  PROGRESS_STATE="${PROGRESS_URL}/state"
  FIRST_SETUP_URL="http://${PI_IP}:8080/first_setup"
  PROGRESS_OPENED=0
  PROGRESS_SEEN=0
  PROGRESS_COMPLETE=0
  INSTALL_FAILED=0

  echo "Waiting for live Progress WebUI at $PROGRESS_URL ..."
  start_epoch="$(date +%s)"
  while true; do
    if curl -fsS --max-time 2 "${PROGRESS_STATE}?ts=$(date +%s)" >/tmp/flightcore-progress-state.$$ 2>/dev/null; then
      PROGRESS_SEEN=1
      if [[ "$PROGRESS_OPENED" -eq 0 ]]; then
        echo "Progress WebUI available - opening browser."
        open "$PROGRESS_URL" >/dev/null 2>&1 || true
        PROGRESS_OPENED=1
      fi
      status="$(sed -nE 's/.*"status"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' /tmp/flightcore-progress-state.$$ | head -n1 || true)"
      if [[ "$status" == "complete" || "$status" == "restarting" ]]; then PROGRESS_COMPLETE=1; fi
      if [[ "$status" == "failed" ]]; then INSTALL_FAILED=1; break; fi
    fi
    rm -f /tmp/flightcore-progress-state.$$ >/dev/null 2>&1 || true

    if curl -fsS --max-time 2 "$FIRST_SETUP_URL" >/dev/null 2>&1; then
      echo "First Setup is available."
      [[ "$PROGRESS_OPENED" -eq 1 ]] || open "$FIRST_SETUP_URL" >/dev/null 2>&1 || true
      wait "$SSH_PID" >/dev/null 2>&1 || true
      echo
      echo "FRESH INSTALL LAUNCHER: PASS"
      echo "First Setup: $FIRST_SETUP_URL"
      echo "Log: $LOG"
      exit 0
    fi

    if ! kill -0 "$SSH_PID" >/dev/null 2>&1; then
      set +e
      wait "$SSH_PID"
      SSH_RC=$?
      set -e
      echo "Remote installer SSH session ended (rc=$SSH_RC)."
      if [[ "$PROGRESS_COMPLETE" -eq 0 && "$PROGRESS_SEEN" -eq 0 && "$SSH_RC" -ne 0 ]]; then
        echo "ERROR: Remote installer ended before the Progress WebUI appeared." >&2
        exit "$SSH_RC"
      fi
      # A successful installer reboots the Pi, which normally drops SSH.
      break
    fi

    now="$(date +%s)"
    if (( now - start_epoch > 900 )); then
      echo "ERROR: Timed out waiting for FlightCore installation progress." >&2
      kill "$SSH_PID" >/dev/null 2>&1 || true
      exit 1
    fi
    sleep 1
  done

  [[ "$INSTALL_FAILED" -eq 0 ]] || { echo 'ERROR: FlightCore installer reported failure.' >&2; exit 1; }
  echo "Waiting for Pi reboot and First Setup..."
  deadline=$(( $(date +%s) + 600 ))
  while (( $(date +%s) < deadline )); do
    if curl -fsS --max-time 3 "$FIRST_SETUP_URL" >/dev/null 2>&1; then
      echo "First Setup available - opening browser."
      open "$FIRST_SETUP_URL" >/dev/null 2>&1 || true
      echo
      echo "FRESH INSTALL LAUNCHER: PASS"
      echo "First Setup: $FIRST_SETUP_URL"
      echo "Log: $LOG"
      exit 0
    fi
    sleep 3
  done
  echo "ERROR: Installation session ended but First Setup did not become reachable." >&2
  exit 1
fi

# Linux/Pi branch: immutable-commit bootstrap used by the macOS launcher and
# direct Pi execution. It downloads only the manifest-selected FlightCore archive.
TMP="$(mktemp -d "${TMPDIR:-/tmp}/flightcore-install.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"
HEAD_SHA="$(resolve_head_sha)"
RAW_BASE="${RAW_REPO}/${HEAD_SHA}"
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

# FLIGHTCORE_4_3_0_RC5_PUBLIC_FRESH_PROGRESS_PRESTART_V1
# Start the browser-facing progress service before the inner installer does any
# route/dependency work. The state directory is user-writable so this works
# before root escalation and survives the inner installer's runtime staging.
if [[ ! -e /etc/siyi/release_version && ! -e /home/pi/siyi-webui/server.py && -x "$TMP/$ROOT/fresh-install-webui.py" ]]; then
  FRESH_UI_DIR="/tmp/flightcore-installer-ui"
  FRESH_UI_STATE="$FRESH_UI_DIR/state.json"
  FRESH_UI_LOG="$FRESH_UI_DIR/server.log"
  mkdir -p "$FRESH_UI_DIR"
  python3 - "$FRESH_UI_STATE" <<'PYFC5STATE'
import datetime,json,os,sys,tempfile
p=sys.argv[1]; os.makedirs(os.path.dirname(p),exist_ok=True)
state={'status':'starting','progress':1,'stage':'Preparing installer','error':'','log_path':'','updated_at':datetime.datetime.now().astimezone().isoformat(timespec='seconds')}
fd,tmp=tempfile.mkstemp(prefix='.state.',dir=os.path.dirname(p))
with os.fdopen(fd,'w',encoding='utf-8') as f: json.dump(state,f,indent=2); f.write('\n'); f.flush(); os.fsync(f.fileno())
os.chmod(tmp,0o644); os.replace(tmp,p)
PYFC5STATE
  nohup python3 "$TMP/$ROOT/fresh-install-webui.py" --port 8090 --state "$FRESH_UI_STATE" >"$FRESH_UI_LOG" 2>&1 </dev/null &
  FRESH_UI_PID=$!
  FRESH_UI_OK=0
  for _fc_try in $(seq 1 50); do
    if curl -fsS --max-time 1 http://127.0.0.1:8090/state >/dev/null 2>&1; then FRESH_UI_OK=1; break; fi
    kill -0 "$FRESH_UI_PID" >/dev/null 2>&1 || break
    sleep 0.2
  done
  if [[ "$FRESH_UI_OK" -ne 1 ]]; then
    echo "ERROR: FlightCore Progress WebUI failed to start on port 8090." >&2
    cat "$FRESH_UI_LOG" >&2 2>/dev/null || true
    exit 1
  fi
  echo "Progress WebUI prestarted and verified on port 8090."
  export SIYI_FRESH_INSTALL_UI_PRESTARTED=1 SIYI_FRESH_INSTALL_UI_STATE="$FRESH_UI_STATE"
fi

exec bash "$TMP/$ROOT/install.sh" "$@"
