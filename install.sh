#!/usr/bin/env bash
set -Eeuo pipefail
# FLIGHTCORE_4_3_0_RC5_PUBLIC_INSTALLER_DUAL_MODE_V2
# FLIGHTCORE_4_3_0_RC5_PUBLIC_MAC_PROGRESS_WEBUI_LAUNCHER_V2
# FLIGHTCORE_4_3_0_RC5_V65_MAC_AUTO_OPEN_CHECKED_V1
# FLIGHTCORE_4_3_0_RC6_V69_PUBLIC_ONE_TOUCH_MAC_LAUNCHER_V1
# FLIGHTCORE_4_3_0_RC6_V70_PUBLIC_ONE_TOUCH_STALE_HOSTKEY_RECOVERY_V1
# FLIGHTCORE_4_3_0_RC7_V73_MAC_TERMINAL_EXACT_ONCE_WIZARD_V1
# FLIGHTCORE_4_2_3_RC10_GITHUB_HEAD_PIN_V1
# FLIGHTCORE_4_3_0_RC13_CANONICAL_IDENTITY_BOOTSTRAP_V1
# FLIGHTCORE_4_3_0_RC14_CACHEABLE_HASH_PINNED_PUBLIC_INSTALLER_V1
# FLIGHTCORE_4_3_0_RC27_RESUMABLE_PUBLIC_DOWNLOAD_V2

REPO="johbaa/SIYI_PI_Installer"
RAW_BASE="https://raw.githubusercontent.com/${REPO}/main"
MANIFEST_URL="${RAW_BASE}/manifest.json"

download_release_file() {
  local url="$1" output="$2"
  local partial="${output}.part" attempt rc
  for attempt in 1 2 3 4 5 6; do
    echo "Downloading $(basename "$output") - attempt $attempt/6 ..."
    touch "$partial"
    set +e
    curl -fL --connect-timeout 20 --max-time 900 \
      --speed-time 90 --speed-limit 512 --continue-at - \
      "$url" -o "$partial"
    rc=$?
    set -e
    if [[ "$rc" -eq 0 ]]; then
      mv -f "$partial" "$output"
      return 0
    fi
    # curl 33 means the origin declined a range request. Restart once from
    # byte zero; all other transfer failures retain the verified partial file.
    if [[ "$rc" -eq 33 ]]; then
      : >"$partial"
    fi
    [[ "$attempt" -lt 6 ]] && sleep $((attempt * 2))
  done
  echo "ERROR: Could not download $(basename "$output") after six resumable attempts." >&2
  return 1
}

manifest_installer_sha() {
  python3 - "$1" <<'PYMANIFESTSHA'
import json,re,sys
m=json.load(open(sys.argv[1],encoding='utf-8'))
digest=str(m.get('installer_sha256') or '').strip().lower()
if not re.fullmatch(r'[0-9a-f]{64}',digest):
    raise SystemExit('invalid published installer SHA-256')
print(digest)
PYMANIFESTSHA
}

file_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

mac_open_url() {
  local url="$1"
  if [[ ! -x /usr/bin/open ]]; then
    echo "ERROR: macOS open command is unavailable; cannot auto-open $url" >&2
    return 1
  fi
  if /usr/bin/open "$url" >/dev/null 2>&1; then
    echo "Browser auto-open requested: $url"
    return 0
  fi
  echo "ERROR: macOS could not auto-open $url" >&2
  return 1
}

if [[ "$(uname -s)" == "Darwin" ]]; then
  # Public fresh-install launcher for macOS. Browser is the primary progress UI.
  cd "$HOME/Downloads"
  TS="$(date '+%Y%m%d_%H%M%S')"
  LOG="$HOME/Downloads/FLIGHTCORE_4.3.0_RC27_FRESH_INSTALL_${TS}.txt"
  exec > >(tee "$LOG") 2>&1

  echo "FlightCore 4.3.0 RC27 - fresh installation launcher"
  echo "Progress is shown in the browser on port 8090."
  echo

  BOOTSTRAP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/flightcore-bootstrap.XXXXXX")"
  BOOTSTRAP_MANIFEST="$BOOTSTRAP_DIR/manifest.json"
  download_release_file "$MANIFEST_URL" "$BOOTSTRAP_MANIFEST"
  EXPECTED_INSTALLER_SHA="$(manifest_installer_sha "$BOOTSTRAP_MANIFEST")"
  ACTUAL_INSTALLER_SHA="$(file_sha256 "$0")"
  [[ "$ACTUAL_INSTALLER_SHA" == "$EXPECTED_INSTALLER_SHA" ]] || {
    echo "ERROR: Public installer checksum does not match the published manifest." >&2
    rm -rf "$BOOTSTRAP_DIR"
    exit 1
  }
  echo "Verified published RC27 installer SHA-256."

  DEFAULT_PI_USER="${PI_USER:-pi}"
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
  printf 'SSH user [%s]: ' "$DEFAULT_PI_USER"
  read -r CONFIRMED_USER
  PI_USER="${CONFIRMED_USER:-$DEFAULT_PI_USER}"
  [[ -n "$PI_USER" ]] || { echo 'ERROR: No SSH user supplied.' >&2; exit 2; }
  printf '%s\n' "$PI_IP" > "$LAST_IP_FILE"
  echo "Confirmed target: ${PI_USER}@${PI_IP}"

  # Freshly reimaged Pis normally generate a new SSH host key while often
  # reusing the same IP. The public one-touch fresh-install path owns this
  # recovery so the user never needs a separate ssh-keygen command.
  SSH_KEYGEN_BIN="$(command -v ssh-keygen || true)"
  [[ -n "$SSH_KEYGEN_BIN" ]] || { echo 'ERROR: ssh-keygen is unavailable on this Mac.' >&2; exit 1; }
  "$SSH_KEYGEN_BIN" -R "$PI_IP" >/dev/null 2>&1 || true
  echo "Cleared stale SSH host-key cache for $PI_IP (if present)."

  # Capture only the Terminal window that launched this installer. RC7 never
  # hides or closes unrelated Terminal windows.
  INSTALLER_TERMINAL_WINDOW_ID=""
  if [[ "${TERM_PROGRAM:-}" == "Apple_Terminal" ]] && command -v osascript >/dev/null 2>&1; then
    INSTALLER_TERMINAL_WINDOW_ID="$(/usr/bin/osascript -e 'tell application "Terminal" to if (count of windows) > 0 then return id of front window' 2>/dev/null || true)"
    INSTALLER_TERMINAL_WINDOW_ID="$(printf '%s' "$INSTALLER_TERMINAL_WINDOW_ID" | tr -cd '0-9')"
  fi
  LAUNCH_SUCCESS=0
  TERMINAL_MINIMIZED=0
  FIRST_SETUP_OPENED=0

  mac_minimize_installer_terminal(){
    [[ -n "$INSTALLER_TERMINAL_WINDOW_ID" ]] || return 0
    /usr/bin/osascript - "$INSTALLER_TERMINAL_WINDOW_ID" <<'OSA' >/dev/null 2>&1 || return 0
on run argv
  set wid to (item 1 of argv) as integer
  tell application "Terminal"
    try
      set miniaturized of window id wid to true
    end try
  end tell
end run
OSA
    TERMINAL_MINIMIZED=1
  }
  mac_restore_installer_terminal(){
    [[ -n "$INSTALLER_TERMINAL_WINDOW_ID" ]] || return 0
    /usr/bin/osascript - "$INSTALLER_TERMINAL_WINDOW_ID" <<'OSA' >/dev/null 2>&1 || return 0
on run argv
  set wid to (item 1 of argv) as integer
  tell application "Terminal"
    try
      set miniaturized of window id wid to false
      set frontmost to true
    end try
  end tell
end run
OSA
  }
  mac_close_installer_terminal_after_exit(){
    [[ -n "$INSTALLER_TERMINAL_WINDOW_ID" ]] || return 0
    # Schedule the close so this shell can finish, flush its log and exit first.
    /usr/bin/osascript - "$INSTALLER_TERMINAL_WINDOW_ID" <<'OSA' >/dev/null 2>&1 &
on run argv
  set wid to (item 1 of argv) as integer
  delay 1
  tell application "Terminal"
    try
      close window id wid
    end try
  end tell
end run
OSA
  }

  SSH_CONTROL="${TMPDIR:-/tmp}/flightcore-ssh-${BASHPID:-$$}.sock"
  cleanup_mac(){
    ssh -S "$SSH_CONTROL" -O exit "$PI_USER@$PI_IP" >/dev/null 2>&1 || true
    rm -f "$SSH_CONTROL" /tmp/flightcore-progress-state.$$ >/dev/null 2>&1 || true
    rm -rf "$BOOTSTRAP_DIR" >/dev/null 2>&1 || true
    if [[ "$LAUNCH_SUCCESS" -eq 1 ]]; then
      mac_close_installer_terminal_after_exit || true
    elif [[ "$TERMINAL_MINIMIZED" -eq 1 ]]; then
      mac_restore_installer_terminal || true
    fi
  }
  trap cleanup_mac EXIT
  SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -o ServerAliveInterval=5 -o ServerAliveCountMax=2 -o ControlPath="$SSH_CONTROL")

  echo
  echo "Waiting for SSH at ${PI_USER}@${PI_IP} ..."
  NC_BIN="$(command -v nc || true)"
  [[ -n "$NC_BIN" ]] || { echo 'ERROR: nc is unavailable on this Mac.' >&2; exit 1; }
  while ! "$NC_BIN" -z -w 2 "$PI_IP" 22 >/dev/null 2>&1; do
    echo "Waiting for SSH... $(date '+%H:%M:%S')"
    sleep 2
  done
  echo "SSH is available. Authenticate to the Pi when prompted."
  ssh -MNf "${SSH_OPTS[@]}" -o ControlMaster=yes -o ControlPersist=600 "$PI_USER@$PI_IP" || { echo 'ERROR: SSH authentication failed.' >&2; exit 1; }
  echo "SSH authentication established."

  # This public path is the end-user fresh-install path. Existing FlightCore
  # systems upgrade through System -> Software update instead.
  if ssh -T "${SSH_OPTS[@]}" "$PI_USER@$PI_IP" 'test -e /etc/siyi/release_version -o -e /home/pi/siyi-webui/server.py' </dev/null >/dev/null 2>&1; then
    echo "ERROR: FlightCore is already installed on this target." >&2
    echo "Use System -> Software update for an existing FlightCore installation." >&2
    exit 3
  fi

  REMOTE_INSTALLER="/tmp/flightcore-public-installer-${BASHPID:-$$}.sh"
  scp "${SSH_OPTS[@]}" "$0" "$PI_USER@$PI_IP:$REMOTE_INSTALLER" >/dev/null || {
    echo 'ERROR: Could not transfer the verified public installer to the Pi.' >&2
    exit 1
  }
  REMOTE_CMD="set -Eeuo pipefail; chmod 0700 '$REMOTE_INSTALLER'; bash '$REMOTE_INSTALLER'; rc=\$?; rm -f '$REMOTE_INSTALLER'; exit \$rc"
  echo "Starting hash-verified FlightCore installer on Pi..."
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
        if mac_open_url "$PROGRESS_URL"; then
          PROGRESS_OPENED=1
          mac_minimize_installer_terminal || true
        else
          echo "Browser auto-open request failed; retrying while Progress WebUI remains reachable."
        fi
      fi
      status="$(sed -nE 's/.*"status"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' /tmp/flightcore-progress-state.$$ | head -n1 || true)"
      if [[ "$status" == "complete" || "$status" == "restarting" ]]; then PROGRESS_COMPLETE=1; fi
      if [[ "$status" == "failed" ]]; then INSTALL_FAILED=1; break; fi
    fi
    rm -f /tmp/flightcore-progress-state.$$ >/dev/null 2>&1 || true

    if curl -fsS --max-time 2 "$FIRST_SETUP_URL" >/dev/null 2>&1; then
      echo "First Setup is available."
      # If the Progress WebUI was opened, it owns the single same-tab redirect
      # to First Setup. Never open a second browser tab/window from Terminal.
      if [[ "$PROGRESS_OPENED" -eq 0 && "$FIRST_SETUP_OPENED" -eq 0 ]]; then
        if mac_open_url "$FIRST_SETUP_URL"; then FIRST_SETUP_OPENED=1; fi
      fi
      wait "$SSH_PID" >/dev/null 2>&1 || true
      echo
      echo "FRESH INSTALL LAUNCHER: PASS"
      echo "First Setup: $FIRST_SETUP_URL"
      echo "Log: $LOG"
      LAUNCH_SUCCESS=1
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
      echo "First Setup available."
      if [[ "$PROGRESS_OPENED" -eq 0 && "$FIRST_SETUP_OPENED" -eq 0 ]]; then
        if mac_open_url "$FIRST_SETUP_URL"; then FIRST_SETUP_OPENED=1; fi
      fi
      echo
      echo "FRESH INSTALL LAUNCHER: PASS"
      echo "First Setup: $FIRST_SETUP_URL"
      echo "Log: $LOG"
      LAUNCH_SUCCESS=1
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
download_release_file "$MANIFEST_URL" manifest.json
EXPECTED_INSTALLER_SHA="$(manifest_installer_sha manifest.json)"
ACTUAL_INSTALLER_SHA="$(file_sha256 "$0")"
[[ "$ACTUAL_INSTALLER_SHA" == "$EXPECTED_INSTALLER_SHA" ]] || {
  echo 'Public installer checksum does not match the published manifest.' >&2
  exit 1
}
read -r RELEASE_IDENTITY ARCHIVE CHECKSUM EXPECTED_PAYLOAD_SHA < <(python3 - <<'PYMAN'
import json,re
m=json.load(open('manifest.json'))
identity=str(m.get('release_identity','')).strip(); archive=str(m.get('archive','')).strip(); checksum=str(m.get('checksum','')).strip(); payload=str(m.get('payload_sha256','')).strip().lower()
if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+-rc\.[1-9][0-9]*',identity): raise SystemExit('invalid manifest release identity')
expected=f'FLIGHTCORE_RPI_INSTALLER_RELEASE_{identity}.tar.gz'
if archive!=expected or checksum!=expected.replace('.tar.gz','.sha256'): raise SystemExit('unexpected FlightCore release filenames')
if not re.fullmatch(r'[0-9a-f]{64}',payload): raise SystemExit('invalid payload SHA-256')
print(identity,archive,checksum,payload)
PYMAN
)
download_release_file "$RAW_BASE/$ARCHIVE" "$ARCHIVE"
download_release_file "$RAW_BASE/$CHECKSUM" "$CHECKSUM"
sha256sum -c "$CHECKSUM"
[[ "$(file_sha256 "$ARCHIVE")" == "$EXPECTED_PAYLOAD_SHA" ]] || {
  echo 'Published FlightCore archive checksum does not match the manifest.' >&2
  exit 1
}
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
