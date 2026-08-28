#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export LC_CTYPE=C.UTF-8

SIYI_INSTALL_BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=webui-ip.sh
. "$SIYI_INSTALL_BOOTSTRAP_DIR/webui-ip.sh"
siyi_capture_install_route_context

# FLIGHTCORE_4_3_0_RC5_V65_FRESH_PROGRESS_SUDO_HANDOFF_FIX_V1
# FLIGHTCORE_4_3_0_RC6_V69_FRESH_PROGRESS_SINGLE_SOURCE_V1
# Run the transaction engine as root, while retaining the real interactive
# caller only for the human-readable install log location.
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  command -v sudo >/dev/null 2>&1 || { echo "sudo is required." >&2; exit 1; }
  _siyi_caller="$(id -un 2>/dev/null || true)"
  [ -n "$_siyi_caller" ] || { echo "Could not determine the invoking user." >&2; exit 1; }
  echo "Sudo check: enter the Pi password if asked." >&2
  exec sudo /usr/bin/env \
    SIYI_INSTALL_CALLER="$_siyi_caller" \
    SIYI_INSTALL_ROUTE_IP="${SIYI_INSTALL_ROUTE_IP:-}" \
    SIYI_INSTALL_SSH_CONNECTION="${SIYI_INSTALL_SSH_CONNECTION:-}" \
    SIYI_FRESH_INSTALL_UI_PRESTARTED="${SIYI_FRESH_INSTALL_UI_PRESTARTED:-0}" \
    SIYI_FRESH_INSTALL_UI_STATE="${SIYI_FRESH_INSTALL_UI_STATE:-}" \
    SIYI_PRESERVE_GROUPS="${SIYI_PRESERVE_GROUPS:-buttons,flaps,mavlink,camera,gimbal,voice,video}" \
    SIYI_PRESERVE_REMEMBER="${SIYI_PRESERVE_REMEMBER:-0}" \
    bash "$0" "$@"
fi

# SIYI_INSTALLER_STABLE_RUNTIME_STAGE_V1
# The public launcher extraction directory is a managed-extra namespace and can
# be deleted during deployment. Execute the transaction engine from a root-only
# /run snapshot before any managed cleanup so Python/pip and rollback helpers
# always have a valid working directory and immutable release inputs.
if [ "${SIYI_INSTALL_STAGED_RUNTIME:-0}" != "1" ]; then
  _siyi_stage_source="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  _siyi_stage_root="${SIYI_INSTALL_STAGE_ROOT:-/run}"
  _siyi_stage_dir="${_siyi_stage_root%/}/siyi-installer-stage-${BASHPID:-$$}"
  rm -rf "$_siyi_stage_dir"
  install -d -o root -g root -m 0700 "$_siyi_stage_dir"
  cp -a "$_siyi_stage_source/." "$_siyi_stage_dir/"
  chown -R root:root "$_siyi_stage_dir"
  chmod 0700 "$_siyi_stage_dir"
  cd /
  exec /usr/bin/env SIYI_INSTALL_STAGED_RUNTIME=1 bash "$_siyi_stage_dir/install.sh" "$@"
fi

VERSION="4.4.0-rc.8"
BUILD_ID="20260828.051159-e9277b6"
# FLIGHTCORE_4_4_0_RC5_CONTROL_LINK_AND_FLIGHT_LOG_HARDENING_V1
# FLIGHTCORE_4_4_0_RC6_COMPLETE_ARCHIVE_MANIFEST_V1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD="$SCRIPT_DIR/payload/rootfs"
MANIFEST="$SCRIPT_DIR/payload-manifest.json"
SOURCE_LOCK="$SCRIPT_DIR/source-lock.json"
REPAIR=0
NO_REBOOT=0
REQUIRE_FC=0
REQUESTED_TARGET=""
PRESERVE_CSV="${SIYI_PRESERVE_GROUPS:-buttons,flaps,mavlink,camera,gimbal,voice,video}"
REMEMBER_SELECTION="${SIYI_PRESERVE_REMEMBER:-0}"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repair) REPAIR=1; shift ;;
    --no-reboot) NO_REBOOT=1; shift ;;
    --require-fc) REQUIRE_FC=1; shift ;;
    --target) [ "$#" -ge 2 ] || { echo "--target requires a value" >&2; exit 2; }; REQUESTED_TARGET="$2"; shift 2 ;;
    --preserve) [ "$#" -ge 2 ] || { echo "--preserve requires a value" >&2; exit 2; }; PRESERVE_CSV="$2"; shift 2 ;;
    --remember) [ "$#" -ge 2 ] || { echo "--remember requires a value" >&2; exit 2; }; REMEMBER_SELECTION="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
[ -z "$REQUESTED_TARGET" ] || [ "$REQUESTED_TARGET" = "$VERSION" ] || [ "$REQUESTED_TARGET" = "4.4.0" ] || { echo "Requested target $REQUESTED_TARGET does not match package $VERSION" >&2; exit 2; }
case "$REMEMBER_SELECTION" in 0|1) ;; *) echo "--remember must be 0 or 1" >&2; exit 2;; esac
declare -A _siyi_seen_groups=()
_siyi_selected_groups=()
IFS=',' read -r -a _siyi_requested_groups <<<"$PRESERVE_CSV"
for _siyi_group in "${_siyi_requested_groups[@]}"; do
  _siyi_group="${_siyi_group//[[:space:]]/}"
  [ -n "$_siyi_group" ] || continue
  case "$_siyi_group" in
    buttons|flaps|mavlink|camera|gimbal|voice|video)
      if [ -z "${_siyi_seen_groups[$_siyi_group]+x}" ]; then _siyi_selected_groups+=("$_siyi_group"); _siyi_seen_groups[$_siyi_group]=1; fi ;;
    groundstation|telemetry|network) : ;; # legacy aliases; these are always preserved
    *) echo "Unknown preservation group: $_siyi_group" >&2; exit 2 ;;
  esac
done
PRESERVE_CSV="$(IFS=,; echo "${_siyi_selected_groups[*]}")"
export SIYI_PRESERVE_GROUPS="$PRESERVE_CSV" SIYI_PRESERVE_REMEMBER="$REMEMBER_SELECTION"

# A single root transaction lock covers every installer entrypoint. The WebUI
# launcher keeps its own UI lifecycle lock; the installer lock prevents it from
# racing a terminal, repair, or recovery invocation.
command -v flock >/dev/null 2>&1 || { echo "flock is required." >&2; exit 1; }
SIYI_INSTALL_LOCK=/run/siyi-installer-transaction.lock
exec 8>"$SIYI_INSTALL_LOCK"
if ! flock -n 8; then
  echo "Another FlightCore install, upgrade, repair, or recovery transaction is already running." >&2
  exit 75
fi

CALLING_USER="${SIYI_INSTALL_CALLER:-${SUDO_USER:-${USER:-root}}}"
if [ "$CALLING_USER" = root ]; then
  if id pi >/dev/null 2>&1; then CALLING_USER=pi; else CALLING_USER=root; fi
fi
CALLING_HOME="$(getent passwd "$CALLING_USER" 2>/dev/null | cut -d: -f6 || true)"
[ -n "$CALLING_HOME" ] || CALLING_HOME="$(getent passwd root | cut -d: -f6)"
CALLING_GROUP="$(id -gn "$CALLING_USER" 2>/dev/null || true)"
[ -n "$CALLING_GROUP" ] || CALLING_GROUP=root
INSTALL_LOG="$CALLING_HOME/siyi_install_${VERSION}_$(date +%Y%m%d_%H%M%S).log"
if [ ! -d "$CALLING_HOME" ]; then
  install -d -o "$CALLING_USER" -g "$CALLING_GROUP" -m 0750 "$CALLING_HOME"
fi
install -o "$CALLING_USER" -g "$CALLING_GROUP" -m 0600 /dev/null "$INSTALL_LOG"

SIYI_BLUE=$'\033[0;94m'
SIYI_GREEN=$'\033[1;32m'
SIYI_RESET=$'\033[0m'
SIYI_PROGRESS_HEADING_PRINTED=0
exec 3>&1 4>&2
if [ "${SIYI_WEBUI_UPGRADE:-0}" = "1" ]; then
  exec > >(tee -a "$INSTALL_LOG" >&3) 2>&1
else
  exec >>"$INSTALL_LOG" 2>&1
fi
CURRENT_STEP_NAME="starting"
INSTALL_START_TS="$SECONDS"
PROGRESS_ANIM_PID=""
PROGRESS_LAST=0
SUCCESS=0
SNAPSHOT_READY=0
MARKER_SNAPSHOT_READY=0
VENV_SWAPPED=0
CAM_PROFILE_CREATED=0
MAPTILER_CACHE_STATE_READY=0
SERVICE_STATE_READY=0
UNIT_STATE_READY=0
TARGET_RELEASE_TREE_MUTATED=0
FRESH_DEPENDENCY_PHASE=0
SOURCE_PREFLIGHT_PHASE=0
ROLLBACK_RESULT="not required"
DEFERRED_POSTINSTALL_ACTIVE=0
SIYI_MANAGED_UNITS=(
  mavlink-router.service mediamtx.service
  siyi-battery-cache.service siyi-button-bridge.service
  siyi-camera-time-sync.service siyi-groundstation.service
  siyi-joystickd.service siyi-paramd.service
  siyi-rec-proxy.service siyi-rec-redirect.service
  siyi-rtsp-redirect.service siyi-telemetry-canvas.service
  siyi-video-dual.service siyi-video-source.service flightcore-siyi-ingest.service
  siyi-webui.service siyi-postinstall-verify.service
  flightcore-registry.service flightcore-registry.timer
)
TX="$(date +%Y%m%d_%H%M%S)_$RANDOM"
TX_DIR="/var/lib/siyi-installer/transactions/$TX"
TX_LOG="/var/log/siyi-installer/install_${VERSION}_${TX}.log"

progress_next_target() {
  case "$1" in
    5) echo 9 ;; 10) echo 24 ;; 25) echo 34 ;; 35) echo 44 ;; 45) echo 49 ;;
    50) echo 57 ;; 58) echo 64 ;; 65) echo 69 ;; 70) echo 75 ;; 76) echo 81 ;;
    82) echo 87 ;; 88) echo 93 ;; 94) echo 99 ;; *) echo "$1" ;;
  esac
}

# SIYI_WEBUI_UPGRADE_ATOMIC_PROGRESS_STATE_V1
siyi_write_webui_progress_state() {
  local pct="$1" msg="$2"
  [ "${SIYI_WEBUI_UPGRADE:-0}" = "1" ] || return 0
  python3 - "$pct" "$msg" <<'PYSIYIWEBUISTATE'
import datetime,json,os,sys,tempfile
path=os.environ.get('SIYI_UPGRADE_STATE_FILE','/var/lib/siyi-upgrade/state.json')
pct=float(sys.argv[1]); msg=sys.argv[2]
try:
    with open(path,encoding='utf-8') as f: state=json.load(f)
    if not isinstance(state,dict): state={}
except Exception:
    state={}
progress=max(0.0,min(99.0,pct if pct < 100 else 99.0))
state.update({
    'running': True,
    'status': 'restarting' if pct >= 100 else 'installing',
    'progress': round(progress,1),
    'stage': 'Installation complete; restarting system' if pct >= 100 else msg,
    'from_version': str(state.get('from_version') or '4.2.0'),
    'to_version': str(state.get('to_version') or '4.4.0'),
    'started_at': str(state.get('started_at') or datetime.datetime.now().astimezone().isoformat(timespec='seconds')),
    'updated_at': datetime.datetime.now().astimezone().isoformat(timespec='seconds'),
    'technical_log': '',
    'error': '',
})
os.makedirs(os.path.dirname(path),exist_ok=True)
fd,tmp=tempfile.mkstemp(prefix='.state.',suffix='.tmp',dir=os.path.dirname(path))
try:
    with os.fdopen(fd,'w',encoding='utf-8') as f:
        json.dump(state,f,indent=2); f.write('\n'); f.flush(); os.fsync(f.fileno())
    os.chmod(tmp,0o644)
    os.replace(tmp,path)
finally:
    try: os.unlink(tmp)
    except FileNotFoundError: pass
PYSIYIWEBUISTATE
}

siyi_write_fresh_install_ui_state() {
  local pct="$1" msg="$2" status="${3:-installing}" error="${4:-}" elapsed="${5:-$((SECONDS-INSTALL_START_TS))}"
  [ "${SIYI_FRESH_INSTALL_UI:-0}" = "1" ] || return 0
  python3 - "$SIYI_FRESH_INSTALL_UI_STATE" "$pct" "$msg" "$status" "$error" "$INSTALL_LOG" "$elapsed" <<'PYFC423INSTALLUI'
import datetime,json,os,sys,tempfile
path,pct,msg,status,error,log,elapsed=sys.argv[1:]
try:
    previous=json.load(open(path,encoding='utf-8'))
    if not isinstance(previous,dict): previous={}
except Exception:
    previous={}
now=datetime.datetime.now().astimezone().isoformat(timespec='seconds')
state={'status':status,'progress':max(0,min(100,float(pct))),'stage':msg,'error':error,'log_path':log,'elapsed_seconds':max(0,int(float(elapsed))),'started_at':str(previous.get('started_at') or now),'updated_at':now}
if previous.get('next_url') and status in ('complete','restarting'): state['next_url']=previous['next_url']
os.makedirs(os.path.dirname(path),exist_ok=True); fd,tmp=tempfile.mkstemp(prefix='.state.',dir=os.path.dirname(path))
with os.fdopen(fd,'w',encoding='utf-8') as f: json.dump(state,f,indent=2); f.write('\n'); f.flush(); os.fsync(f.fileno())
os.chmod(tmp,0o644); os.replace(tmp,path)
PYFC423INSTALLUI
}

# FLIGHTCORE_4_3_0_RC2_FRESH_INSTALL_WEBUI_EARLY_START_V1
# FLIGHTCORE_4_3_0_RC3_FRESH_INSTALL_WEBUI_ACCEPTANCE_V1
SIYI_FRESH_INSTALL_UI=0
SIYI_FRESH_INSTALL_UI_PID=""
SIYI_FRESH_INSTALL_UI_STATE="${SIYI_FRESH_INSTALL_UI_STATE:-/run/flightcore-installer-ui/state.json}"
# FLIGHTCORE_4_3_0_RC5_FRESH_PROGRESS_PRESTART_HANDOFF_V1
if [ "${SIYI_FRESH_INSTALL_UI_PRESTARTED:-0}" = "1" ] && curl -fsS --max-time 2 http://127.0.0.1:8090/state >/dev/null 2>&1; then
  SIYI_FRESH_INSTALL_UI=1
  fresh_ui_ip="${SIYI_INSTALL_ROUTE_IP:-}"
  if [ -z "$fresh_ui_ip" ]; then fresh_ui_ip="$(hostname -I 2>/dev/null | awk '{print $1}')"; fi
  echo "Fresh-install WebUI: http://${fresh_ui_ip:-PI-IP}:8090" >&3
  echo "Fresh-install WebUI persistent evidence: prestarted and reachable on port 8090"
elif [ ! -e /etc/siyi/release_version ] && [ ! -e /home/pi/siyi-webui/server.py ] && [ -x "$SCRIPT_DIR/fresh-install-webui.py" ]; then
  install -d -o root -g root -m 0755 /run/flightcore-installer-ui
  SIYI_FRESH_INSTALL_UI=1
  nohup python3 "$SCRIPT_DIR/fresh-install-webui.py" --port 8090 >/run/flightcore-installer-ui/server.log 2>&1 </dev/null &
  SIYI_FRESH_INSTALL_UI_PID="$!"
  fresh_ui_ip="${SIYI_INSTALL_ROUTE_IP:-}"
  if [ -z "$fresh_ui_ip" ]; then fresh_ui_ip="$(hostname -I 2>/dev/null | awk '{print $1}')"; fi
  echo "Fresh-install WebUI: http://${fresh_ui_ip:-PI-IP}:8090" >&3
  echo "Fresh-install WebUI persistent evidence: inner installer started port 8090"
  siyi_write_fresh_install_ui_state 1 "Preparing installer" starting "" "$((SECONDS-INSTALL_START_TS))"
fi

draw_progress() {
  local pct="$1" msg="$2" elapsed="${3:-0}"
  # V69: one authoritative live progress/elapsed state feeds both Terminal and :8090.
  siyi_write_fresh_install_ui_state "$pct" "$msg" "$( [ "$pct" -ge 100 ] && echo restarting || echo installing )" "" "$elapsed"
  if [ "${SIYI_WEBUI_UPGRADE:-0}" = "1" ]; then
    siyi_write_webui_progress_state "$pct" "$msg"
    printf "%3d%%  %s\n" "$pct" "$msg" >&3
    return
  fi
  # A non-interactive stream cannot update a line in place. Emit only the
  # explicit stage update; suppress the one-second animation refreshes.
  if ! [ -t 3 ]; then
    [ "${SIYI_PROGRESS_BACKGROUND:-0}" = "1" ] && return
    printf "%3d%%  %s\n" "$pct" "$msg" >&3
    return
  fi
  local cols="" width=12 filled empty bar="" i spin='|/-\\' idx sp timer="" display="$msg"
  cols="$(stty size </dev/tty 2>/dev/null | awk '{print $2}' || true)"
  [[ "$cols" =~ ^[0-9]+$ ]] || cols="${COLUMNS:-80}"
  [[ "$cols" =~ ^[0-9]+$ ]] || cols=80
  [ "$cols" -ge 40 ] || cols=40
  [ "$cols" -lt 72 ] && width=8
  [ "$cols" -ge 100 ] && width=20
  case "$display" in
    "Validating operating-system dependencies") display="Validating OS dependencies" ;;
  esac
  filled=$((pct * width / 100)); empty=$((width-filled))
  sp="${spin:$((SECONDS % 4)):1}"
  if [ "$elapsed" -gt 0 ]; then timer=$(printf " (%02dm %02ds)" $((elapsed/60)) $((elapsed%60))); fi
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=0; i<empty; i++)); do bar+="░"; done
  local prefix suffix max_msg plain
  prefix="$sp [$bar] $(printf '%3d%%' "$pct")  "
  max_msg=$((cols - ${#prefix} - ${#timer} - 1))
  if [ "$max_msg" -lt 10 ]; then timer=""; max_msg=$((cols - ${#prefix} - 1)); fi
  [ "$max_msg" -ge 1 ] || max_msg=1
  if [ "${#display}" -gt "$max_msg" ]; then
    if [ "$max_msg" -gt 1 ]; then display="${display:0:$((max_msg-1))}…"; else display="${display:0:1}"; fi
  fi
  plain="${prefix}${display}${timer}"
  if [ "${#plain}" -ge "$cols" ]; then plain="${plain:0:$((cols-1))}"; fi
  if [ "${SIYI_PROGRESS_HEADING_PRINTED:-0}" -eq 0 ]; then
    printf "%sInstalling FlightCore%s\n\n" "$SIYI_BLUE" "$SIYI_RESET" >&3
    SIYI_PROGRESS_HEADING_PRINTED=1
  fi
  printf "\r\033[2K%s%s%s" "$SIYI_GREEN" "$plain" "$SIYI_RESET" >&3
}
stop_progress_anim() {
  if [ -n "${PROGRESS_ANIM_PID:-}" ]; then
    kill "$PROGRESS_ANIM_PID" >/dev/null 2>&1 || true
    wait "$PROGRESS_ANIM_PID" >/dev/null 2>&1 || true
    PROGRESS_ANIM_PID=""
  fi
}

progress() {
  local pct="$1" msg="$2" target cur
  stop_progress_anim
  CURRENT_STEP_NAME="$msg"
  PROGRESS_LAST="$pct"
  draw_progress "$pct" "$msg" "$((SECONDS-INSTALL_START_TS))"
  target="$(progress_next_target "$pct")"
  if [ "$pct" -ge 100 ]; then
    stop_progress_anim
    draw_progress 100 "$msg" "$((SECONDS-INSTALL_START_TS))"
    printf "\n" >&3
    return
  fi
  (
    SIYI_PROGRESS_BACKGROUND=1
    cur="$pct"
    while true; do
      sleep 1
      elapsed=$((SECONDS-INSTALL_START_TS))
      if [ "$cur" -lt "$target" ]; then cur=$((cur+1)); fi
      draw_progress "$cur" "$msg" "$elapsed"
    done
  ) &
  PROGRESS_ANIM_PID="$!"
}

run_logged() {
  local description="$1"; shift
  echo "=== $description ==="
  "$@"
}

die() { echo "INSTALL FAILED: $*"; return 1; }

cleanup_target_transients() {
  local preserve_staged="${1:-0}"
  rm -rf "/tmp/siyi-mediamtx-$TX" /home/pi/mavlink-router-build
  [ "$preserve_staged" = "1" ] || rm -rf /home/pi/siyi-bridge-venv.new
}

restore_existing_pi_groups() {
  [ -f "$TX_DIR/pi-user-existed" ] || return 0
  [ -f "$TX_DIR/pi-supplementary-groups-before" ] || return 1
  id pi >/dev/null 2>&1 || return 1
  local wanted actual csv
  wanted="$(sort -u "$TX_DIR/pi-supplementary-groups-before" | sed '/^$/d')"
  csv="$(printf '%s\n' "$wanted" | paste -sd, -)"
  usermod -G "$csv" pi >/dev/null 2>&1 || return 1
  actual="$(id -Gn pi | tr ' ' '\n' | grep -vx "$(id -gn pi)" | sort -u || true)"
  [ "$actual" = "$wanted" ]
}

remove_created_pi_identity() {
  local warning=0
  if [ -f "$TX_DIR/pi-user-created" ]; then
    pkill -u pi >/dev/null 2>&1 || true
    userdel pi >/dev/null 2>&1 || warning=1
    id pi >/dev/null 2>&1 && warning=1
  fi
  if [ -f "$TX_DIR/pi-group-created" ]; then
    groupdel pi >/dev/null 2>&1 || warning=1
    getent group pi >/dev/null 2>&1 && warning=1
  fi
  return "$warning"
}

refresh_new_packages() {
  [ -f "$TX_DIR/packages-before.tsv" ] || return 0
  dpkg-query -W -f='${binary:Package}\t${Version}\n' 2>/dev/null | sort -u >"$TX_DIR/packages-current.tsv"
  python3 - "$TX_DIR/packages-before.tsv" "$TX_DIR/packages-current.tsv" "$TX_DIR/new-packages.txt" <<'PYPKGREFRESH'
import sys
before,current,out=sys.argv[1:]
def read(path):
 d={}
 for line in open(path,encoding='utf-8',errors='replace'):
  parts=line.rstrip('\n').split('\t',1)
  if len(parts)==2:d[parts[0]]=parts[1]
 return d
b,c=read(before),read(current)
changed=[p for p in b if c.get(p)!=b[p]]
if changed: raise SystemExit('pre-existing package state changed: '+','.join(changed))
open(out,'w').write(''.join(p+'\n' for p in sorted(set(c)-set(b))))
PYPKGREFRESH
}

verify_package_state() {
  [ -f "$TX_DIR/packages-before.tsv" ] || return 0
  dpkg-query -W -f='${binary:Package}\t${Version}\n' 2>/dev/null | sort -u >"$TX_DIR/packages-restored.tsv"
  cmp -s "$TX_DIR/packages-before.tsv" "$TX_DIR/packages-restored.tsv"
}

record_rollback_failure() {
  local reason="${1:-rollback_incomplete}"
  printf '%s\n' "$(date -Is) reason=$reason tx=$TX_DIR" >"$TX_DIR/ROLLBACK_FAILED" 2>/dev/null || true
  install -d -o root -g root -m 0755 /var/lib/siyi-installer >/dev/null 2>&1 || true
  printf '%s\n' "$TX_DIR" >/var/lib/siyi-installer/last_rollback_failure 2>/dev/null || true
  install -d -o root -g root -m 0775 /etc/siyi >/dev/null 2>&1 || true
  if [ -z "${SIYI_SOURCE_RELEASE:-}" ]; then
    printf '%s\n' "$VERSION" >/etc/siyi/release_version 2>/dev/null || true
    printf '%s\n' "$BUILD_ID" >/etc/siyi/release_build 2>/dev/null || true
  fi
  printf '%s\n' rollback_failed >/etc/siyi/release_status 2>/dev/null || true
}

restore_unit_states() {
  local state_file="$TX_DIR/unit-state.tsv" unit expected_enabled expected_active actual warning=0
  [ -f "$state_file" ] || return 0
  unit_enabled_state() { local v; v="$(sudo systemctl is-enabled "$1" 2>/dev/null || true)"; [ -n "$v" ] || v=not-found; printf '%s\n' "$v"; }
  unit_active_state() { local v; v="$(sudo systemctl is-active "$1" 2>/dev/null || true)"; [ -n "$v" ] || v=inactive; printf '%s\n' "$v"; }
  sudo systemctl daemon-reload >/dev/null 2>&1 || warning=1
  while IFS=$'\t' read -r unit expected_enabled expected_active; do
    [ -n "$unit" ] || continue
    sudo systemctl unmask --runtime "$unit" >/dev/null 2>&1 || true
    sudo systemctl unmask "$unit" >/dev/null 2>&1 || true
    sudo systemctl disable --runtime "$unit" >/dev/null 2>&1 || true
    sudo systemctl disable "$unit" >/dev/null 2>&1 || true
    case "$expected_enabled" in
      masked) sudo systemctl mask "$unit" >/dev/null 2>&1 || warning=1 ;;
      masked-runtime) sudo systemctl mask --runtime "$unit" >/dev/null 2>&1 || warning=1 ;;
      enabled) sudo systemctl enable "$unit" >/dev/null 2>&1 || warning=1 ;;
      enabled-runtime) sudo systemctl enable --runtime "$unit" >/dev/null 2>&1 || warning=1 ;;
      disabled|static|indirect|generated|transient|alias|not-found) : ;;
      *) echo "Unsupported captured enable state for exact rollback: $unit=$expected_enabled"; warning=1 ;;
    esac
  done <"$state_file"
  sudo systemctl daemon-reload >/dev/null 2>&1 || warning=1
  for unit in NetworkManager.service zerotier-one.service serial-getty@serial0.service serial-getty@ttyS0.service serial-getty@ttyAMA0.service "${SIYI_MANAGED_UNITS[@]}"; do
    expected_enabled="$(awk -F '\t' -v u="$unit" '$1==u{print $2; exit}' "$state_file")"
    expected_active="$(awk -F '\t' -v u="$unit" '$1==u{print $3; exit}' "$state_file")"
    [ -n "$expected_active" ] || continue
    case "$expected_active" in
      active)
        if [ "$unit" = siyi-postinstall-verify.service ]; then
          # SIYI_ROLLBACK_DEFER_POSTINSTALL_UNTIL_UNLOCK_V1
          DEFERRED_POSTINSTALL_ACTIVE=1
          printf '%s\n' active >"$TX_DIR/deferred-postinstall-state"
        else
          sudo systemctl start "$unit" >/dev/null 2>&1 || warning=1
        fi
        ;;
      inactive)
        if [ "$expected_enabled" != not-found ]; then
          sudo systemctl stop "$unit" >/dev/null 2>&1 || [ "$(unit_active_state "$unit")" = inactive ] || warning=1
        fi
        sudo systemctl reset-failed "$unit" >/dev/null 2>&1 || true
        ;;
      *) echo "Unsupported captured active state for exact rollback: $unit=$expected_active"; warning=1 ;;
    esac
  done
  while IFS=$'\t' read -r unit expected_enabled expected_active; do
    [ -n "$unit" ] || continue
    actual="$(unit_enabled_state "$unit")"; [ "$actual" = "$expected_enabled" ] || { echo "Enable-state verify failed: $unit expected=$expected_enabled actual=$actual"; warning=1; }
    if [ "$unit" = siyi-postinstall-verify.service ] && [ "$DEFERRED_POSTINSTALL_ACTIVE" -eq 1 ]; then
      continue
    fi
    actual="$(unit_active_state "$unit")"; [ "$actual" = "$expected_active" ] || { echo "Active-state verify failed: $unit expected=$expected_active actual=$actual"; warning=1; }
  done <"$state_file"
  return "$warning"
}



rollback_transaction() {
  local original_rc="$1" rollback_warning=0 unit map_cache_state map_cache_uid map_cache_gid map_cache_mode
  set +e
  echo "=== ROLLBACK START: transaction $TX, original exit $original_rc ==="

  # SIYI_4_2_0_ROLLBACK_SERVICE_STATE_GUARD_V21
  # Do not touch a pre-existing installation when route selection, sudo,
  # platform checks, or an already-installed check fails before service state
  # has been captured.
  if [ "$SERVICE_STATE_READY" -eq 1 ]; then
    sudo systemctl stop "${SIYI_MANAGED_UNITS[@]}" >/dev/null 2>&1 || true
    for unit in "${SIYI_MANAGED_UNITS[@]}"; do
      sudo systemctl disable --runtime "$unit" >/dev/null 2>&1 || true
      sudo systemctl disable "$unit" >/dev/null 2>&1 || true
    done
  fi

  refresh_new_packages || rollback_warning=1
  if [ -s "$TX_DIR/new-packages.txt" ]; then
    mapfile -t _siyi_new_packages <"$TX_DIR/new-packages.txt"
    sudo -E apt-get -o Dpkg::Use-Pty=0 -o APT::Color=0 purge -y "${_siyi_new_packages[@]}" || rollback_warning=1
  fi
  verify_package_state || rollback_warning=1

  if [ "$VENV_SWAPPED" -eq 1 ]; then
    sudo rm -rf /home/pi/siyi-bridge-venv || rollback_warning=1
    if [ -d "$TX_DIR/siyi-bridge-venv.previous" ]; then
      sudo mv "$TX_DIR/siyi-bridge-venv.previous" /home/pi/siyi-bridge-venv || rollback_warning=1
      sudo chown -R pi:pi /home/pi/siyi-bridge-venv >/dev/null 2>&1 || rollback_warning=1
    fi
  fi

  cleanup_target_transients || rollback_warning=1

  if [ "$SNAPSHOT_READY" -eq 1 ]; then
    if (cd "$TX_DIR" && sha256sum -c recovery-helper.sha256); then
      # SIYI_ROLLBACK_PINNED_MANIFEST_V1
      sudo python3 "$TX_DIR/transaction-restore.py" "$TX_DIR/payload-manifest.json" "$TX_DIR/backup-index.json" "$TX_DIR/backup-root" || rollback_warning=1
    else
      rollback_warning=1
    fi
  fi

  if [ "$MARKER_SNAPSHOT_READY" -eq 1 ] && [ -f "$TX_DIR/marker-state.json" ]; then
    sudo python3 - "$TX_DIR/marker-state.json" "$TX_DIR/marker-backup" <<'PYMARKERRESTORE' || rollback_warning=1
import json, os, shutil, sys
state_path, backup_root = sys.argv[1:]
state = json.load(open(state_path, encoding='utf-8'))
for path, info in state.items():
    if os.path.isdir(path) and not os.path.islink(path):
        shutil.rmtree(path)
    elif os.path.lexists(path):
        os.unlink(path)
    if info.get('exists'):
        src = os.path.join(backup_root, path.lstrip('/'))
        os.makedirs(os.path.dirname(path), exist_ok=True)
        if os.path.islink(src):
            os.symlink(os.readlink(src), path)
        elif os.path.isfile(src):
            shutil.copy2(src, path, follow_symlinks=False)
        else:
            raise SystemExit(f'missing marker backup: {path}')
PYMARKERRESTORE
  fi

  if [ "$CAM_PROFILE_CREATED" -eq 1 ]; then
    sudo nmcli connection delete cam-eth0 >/dev/null 2>&1 || rollback_warning=1
  elif [ -f "$TX_DIR/cam-profile-state.tsv" ]; then
    while IFS=$'	' read -r key value; do
      [ -n "$key" ] || continue
      sudo nmcli connection modify cam-eth0 "$key" "$value" >/dev/null 2>&1 || rollback_warning=1
    done <"$TX_DIR/cam-profile-state.tsv"
    if [ -f "$TX_DIR/cam-profile-was-active" ]; then sudo nmcli connection up cam-eth0 >/dev/null 2>&1 || rollback_warning=1; else sudo nmcli connection down cam-eth0 >/dev/null 2>&1 || true; fi
  fi

  # SIYI_4_2_0_MAPTILER_CACHE_ROLLBACK_V21
  if [ "$MAPTILER_CACHE_STATE_READY" -eq 1 ] && [ -f "$TX_DIR/maptiler-cache-state" ]; then
    map_cache_state="$(cat "$TX_DIR/maptiler-cache-state" 2>/dev/null || true)"
    if [ "$map_cache_state" = "absent" ]; then
      sudo rm -rf /var/cache/siyi-maptiler || rollback_warning=1
    elif [ -n "$map_cache_state" ]; then
      read -r map_cache_uid map_cache_gid map_cache_mode <<<"$map_cache_state"
      sudo chown "$map_cache_uid:$map_cache_gid" /var/cache/siyi-maptiler >/dev/null 2>&1 || rollback_warning=1
      sudo chmod "$map_cache_mode" /var/cache/siyi-maptiler >/dev/null 2>&1 || rollback_warning=1
    fi
  fi

  if [ "$TARGET_RELEASE_TREE_MUTATED" -eq 1 ] || [ -f "$TX_DIR/target-release-tree-mutated" ]; then
    sudo rm -rf "/usr/local/share/siyi/releases/4.4.0" >/dev/null 2>&1 || rollback_warning=1
  fi
  if { [ "$TARGET_RELEASE_TREE_MUTATED" -eq 1 ] || [ -f "$TX_DIR/target-release-tree-mutated" ]; } && [ -n "${SIYI_SOURCE_RELEASE:-}" ] && [ -f "$TX_DIR/source-release-tree.ready" ] && [ -d "$TX_DIR/source-release-tree" ]; then
    sudo install -d -o root -g root -m 0755 /usr/local/share/siyi/releases
    sudo rm -rf "/usr/local/share/siyi/releases/$SIYI_SOURCE_RELEASE" >/dev/null 2>&1 || true
    sudo cp -a "$TX_DIR/source-release-tree" "/usr/local/share/siyi/releases/$SIYI_SOURCE_RELEASE" || rollback_warning=1
  fi
  sudo rm -f /var/lib/siyi-installer/pending-transaction >/dev/null 2>&1 || true
  sudo systemctl daemon-reload >/dev/null 2>&1 || rollback_warning=1

  # Restore exact captured enable/mask/active states.
  if [ "$UNIT_STATE_READY" -eq 1 ]; then
    restore_unit_states || rollback_warning=1
  fi
  restore_existing_pi_groups || rollback_warning=1
  remove_created_pi_identity || rollback_warning=1

  # RC13 Device Registry identity/config are persistent across normal upgrades,
  # but a failed fresh install must restore a genuinely clean OS.
  if [ -f "$TX_DIR/flightcore-flight-logs-dir-created" ]; then sudo rm -rf /var/lib/flightcore/flight-logs >/dev/null 2>&1 || rollback_warning=1; fi
  if [ -f "$TX_DIR/flightcore-registry-state-dir-created" ]; then sudo rm -rf /var/lib/flightcore >/dev/null 2>&1 || rollback_warning=1; fi
  if [ -f "$TX_DIR/flightcore-registry-config-created" ]; then sudo rm -f /etc/flightcore/registry.json >/dev/null 2>&1 || rollback_warning=1; fi
  if [ -f "$TX_DIR/flightcore-device-id-created" ]; then sudo rm -f /etc/flightcore/device-id >/dev/null 2>&1 || rollback_warning=1; fi
  if [ -d /etc/flightcore ] && [ -z "$(find /etc/flightcore -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then sudo rmdir /etc/flightcore >/dev/null 2>&1 || true; fi

  # SIYI_ROLLBACK_DEFER_POSTINSTALL_UNTIL_UNLOCK_V1
  # The source postinstall unit itself acquires the global installer lock. It
  # cannot be restored to active while rollback still owns fd 8, otherwise it
  # exits 75/TEMPFAIL and falsely turns an otherwise complete rollback into
  # rollback_failed. Release the lock only after all other state is restored.
  if [ "$DEFERRED_POSTINSTALL_ACTIVE" -eq 1 ]; then
    flock -u 8 >/dev/null 2>&1 || rollback_warning=1
    exec 8>&-
    sudo systemctl reset-failed siyi-postinstall-verify.service >/dev/null 2>&1 || true
    sudo systemctl start siyi-postinstall-verify.service >/dev/null 2>&1 || rollback_warning=1
    [ "$(sudo systemctl is-active siyi-postinstall-verify.service 2>/dev/null || true)" = active ] || rollback_warning=1
  fi

  if [ "$rollback_warning" -eq 0 ]; then
    ROLLBACK_RESULT="Complete"
  else
    record_rollback_failure "pre_reboot_rollback_incomplete"
    ROLLBACK_RESULT="FAILED: rollback was incomplete; release status marked rollback_failed"
  fi
  echo "=== ROLLBACK END: $ROLLBACK_RESULT ==="
  set -e
}

on_failure() {
  local rc="$1"
  trap - ERR INT TERM
  stop_progress_anim || true
  siyi_write_fresh_install_ui_state "${PROGRESS_LAST:-0}" "${CURRENT_STEP_NAME:-Installation failed}" failed "Installer failed at ${CURRENT_STEP_NAME:-unknown stage}" "$((SECONDS-INSTALL_START_TS))" || true
  cp -a "$INSTALL_LOG" "$TX_DIR/pre-rollback-install.log" 2>/dev/null || true
  if [ "${SIYI_ROUTE:-}" = fresh ] && [ "${FRESH_DEPENDENCY_PHASE:-0}" -eq 1 ] && [ "$SNAPSHOT_READY" -eq 0 ] && [ "$TARGET_RELEASE_TREE_MUTATED" -eq 0 ]; then
    printf '%s\n' "$(date -Is) step=${CURRENT_STEP_NAME:-dependencies} exit=$rc" >"$TX_DIR/FRESH_DEPENDENCY_FAILED" 2>/dev/null || true
    ROLLBACK_RESULT="Not required: FlightCore deployment had not started; prepared OS package state retained"
    echo "=== FRESH DEPENDENCY PREPARATION FAILED BEFORE FLIGHTCORE DEPLOYMENT ==="
  elif [ "${SOURCE_PREFLIGHT_PHASE:-0}" -eq 1 ] && [ "$SNAPSHOT_READY" -eq 0 ] && [ "$TARGET_RELEASE_TREE_MUTATED" -eq 0 ]; then
    printf '%s\n' "$(date -Is) step=${CURRENT_STEP_NAME:-source-preflight} exit=$rc" >"$TX_DIR/SOURCE_PREFLIGHT_FAILED" 2>/dev/null || true
    ROLLBACK_RESULT="Not required: target deployment had not started; verified source preflight state retained"
    echo "=== SOURCE PREFLIGHT FAILED BEFORE TARGET DEPLOYMENT ==="
  else
    rollback_transaction "$rc"
  fi
  printf "\n\n" >&3
  echo "========================================" >&3
  echo "❌ FLIGHTCORE INSTALL FAILED" >&3
  echo "========================================" >&3
  echo "Step: ${CURRENT_STEP_NAME:-starting}" >&3
  echo "Exit code: $rc" >&3
  echo "Rollback: $ROLLBACK_RESULT" >&3
  echo "Transaction: $TX_DIR" >&3
  echo "Full log:" >&3
  echo "$INSTALL_LOG" >&3
  echo >&3
  exit "$rc"
}
trap 'on_failure $?' ERR
trap 'on_failure 130' INT
trap 'on_failure 143' TERM

# Canonical 3.1.12 first-install introduction.
echo "=== FlightCore Public Installer $VERSION ==="
echo "Full log: $INSTALL_LOG" >&3
echo >&3
command -v sudo >/dev/null 2>&1 || die "sudo is required."
sudo -v
install -d -o root -g root -m 0755 /var/log/siyi-installer /var/lib/siyi-installer
install -d -o root -g root -m 0700 /var/lib/siyi-installer/transactions
install -d -o root -g root -m 0700 "$TX_DIR" "$TX_DIR/backup-root" "$TX_DIR/marker-backup"
ln -sfn "$INSTALL_LOG" "$TX_LOG"
# Snapshot release markers before route selection or any install changes. This
# guarantees a failed fresh install restores "absent" rather than leaving a
# false 4.2.0 marker that blocks the next recovery run.
sudo python3 - "$TX_DIR/marker-state.json" "$TX_DIR/marker-backup" <<'PYMARKERSNAPSHOT'
import json, os, shutil, sys
state_path, backup_root = sys.argv[1:]
markers = ['/etc/siyi/release_version', '/etc/siyi/release_build', '/etc/siyi/release_status']
state = {}
os.makedirs(backup_root, exist_ok=True)
for path in markers:
    exists = os.path.lexists(path)
    state[path] = {'exists': exists}
    if exists:
        dst = os.path.join(backup_root, path.lstrip('/'))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if os.path.islink(path):
            os.symlink(os.readlink(path), dst)
        elif os.path.isfile(path):
            shutil.copy2(path, dst, follow_symlinks=False)
        else:
            raise SystemExit(f'unsupported release-marker type: {path}')
with open(state_path, 'w', encoding='utf-8') as f:
    json.dump(state, f, indent=2, sort_keys=True)
PYMARKERSNAPSHOT
MARKER_SNAPSHOT_READY=1

progress 5 "Preparing installer"
[ "$(uname -m)" = aarch64 ] || die "4.4.0 supports Raspberry Pi OS 64-bit (aarch64) only."
OS_ID="$(. /etc/os-release; printf '%s' "${ID:-}")"
OS_VERSION_ID="$(. /etc/os-release; printf '%s' "${VERSION_ID:-}")"
case "$OS_ID" in debian|raspbian) ;; *) die "Unsupported OS ${OS_ID:-unknown}" ;; esac
[ "$OS_VERSION_ID" = 13 ] || die "4.4.0 requires Raspberry Pi OS / Debian 13."
[ -r /proc/device-tree/model ] || die "Raspberry Pi hardware was not detected."
model="$(tr -d '\0' </proc/device-tree/model)"
case "$model" in *"Raspberry Pi 3 Model B Plus"*|*"Raspberry Pi 4 Model B"*|*"Raspberry Pi 5"*) ;; *) die "Unsupported Raspberry Pi model: $model" ;; esac
free_kb="$(df -Pk / | awk 'NR==2{print $4}')"
[ "$free_kb" -ge 2097152 ] || die "At least 2 GiB free space is required."
release_marker=/etc/siyi/release_version
read_text_marker() {
  python3 - "$1" <<'PYREADTEXT'
import os,sys
p=sys.argv[1]
try:
    raw=open(p,'rb').read().decode('utf-8-sig','replace')
except FileNotFoundError:
    raw=''
print(raw.replace('\x00','').strip())
PYREADTEXT
}
read_semver_marker() {
  python3 - "$1" <<'PYREADVERSION'
import re,sys
p=sys.argv[1]
try:
    raw=open(p,'rb').read().decode('utf-8-sig','replace').replace('\x00','')
except FileNotFoundError:
    raw=''
m=re.search(r'(?<!\d)(\d+\.\d+\.\d+)(?!\d)',raw)
print(m.group(1) if m else '')
PYREADVERSION
}
interrupted_target_evidence() {
  local meta="/usr/local/share/siyi/releases/4.4.0/release-metadata.json"
  if [ -r "$meta" ]; then
    python3 - "$meta" "$VERSION" <<'PYINTEVIDENCE'
import json,sys
try:
    print(1 if str(json.load(open(sys.argv[1],encoding='utf-8')).get('version','')).strip()==sys.argv[2] else 0)
except Exception:
    print(0)
PYINTEVIDENCE
    return
  fi
  while IFS= read -r marker; do
    tx="${marker%/target-release}"
    if [ "$(tr -d '[:space:]' <"$marker" 2>/dev/null || true)" = "$VERSION" ] && [ -f "$tx/backup-index.json" ]; then
      echo 1
      return
    fi
  done < <(sudo find /var/lib/siyi-installer/transactions -mindepth 2 -maxdepth 2 -type f -name target-release -print 2>/dev/null)
  echo 0
}
# SIYI_4_2_3_COMPLETE_TARGET_MODEL_V44
# SIYI_RUNTIME_STATE_NAMESPACE_MIGRATION_V4
migrate_siyi_runtime_state_artifacts() {
  python3 - <<'PYRUNTIMESTATE'

from pathlib import Path
import os, shutil, time

OLD_BACKUP_DIR = Path('/home/pi/siyi-webui/backups')
NEW_BACKUP_DIR = Path('/home/pi/.local/state/siyi/webui-backups')
OLD_ZT_LOG = Path('/home/pi/siyi_zerotier_setup.log')
NEW_ZT_LOG = Path('/home/pi/.local/state/siyi/zerotier_setup.log')
OLD_VOICE_LOG = Path('/home/pi/siyi_groundstation_native_device_voice_v3.log')
NEW_VOICE_LOG = Path('/home/pi/.local/state/siyi/groundstation_native_device_voice_v3.log')
OLD_VIDEO_PREVIOUS = Path('/etc/siyi/video_source.json.previous')
NEW_VIDEO_PREVIOUS = Path('/home/pi/.local/state/siyi/video-source/video_source.json.previous')
NEW_BRIDGE_BACKUP_DIR = Path('/home/pi/.local/state/siyi/bridge-backups')


def _mapped(root: Path, absolute: Path) -> Path:
    return absolute if root == Path('/') else root / str(absolute).lstrip('/')


def _collision_path(path: Path) -> Path:
    if not path.exists() and not path.is_symlink():
        return path
    stamp = time.strftime('%Y%m%d_%H%M%S')
    for idx in range(1, 1000):
        candidate = path.with_name(path.name + f'.migrated_{stamp}_{idx}')
        if not candidate.exists() and not candidate.is_symlink():
            return candidate
    raise RuntimeError(f'could not allocate collision-safe migration path for {path}')


def _move(src: Path, preferred: Path) -> Path | None:
    if not src.exists() and not src.is_symlink():
        return None
    preferred.parent.mkdir(parents=True, exist_ok=True)
    final = preferred if not preferred.exists() and not preferred.is_symlink() else _collision_path(preferred)
    shutil.move(str(src), str(final))
    return final


def migrate_runtime_state(root: Path = Path('/'), uid: int | None = None, gid: int | None = None) -> dict:
    root = Path(root)
    if uid is None or gid is None:
        if root == Path('/'):
            import pwd, grp
            try:
                uid = pwd.getpwnam('pi').pw_uid
                gid = grp.getgrnam('pi').gr_gid
            except KeyError:
                # A fresh Raspberry Pi OS may use a custom login and have no pi
                # identity yet. There is no RC29 runtime state to migrate in
                # that case; do not create /home/pi before useradd -m runs.
                return {
                    'skipped_missing_pi_identity': True,
                    'legacy_webui_backup_dir_removed': True,
                    'legacy_zerotier_log_removed': True,
                    'legacy_native_voice_log_removed': True,
                    'legacy_video_source_previous_removed': True,
                    'legacy_bridge_backups_removed': True,
                    'moved_backup_files': [],
                    'moved_bridge_backup_files': [],
                    'zerotier_migrated_to': '',
                    'native_voice_migrated_to': '',
                    'video_previous_migrated_to': '',
                    'state_backup_dir': str(NEW_BACKUP_DIR),
                    'state_bridge_backup_dir': str(NEW_BRIDGE_BACKUP_DIR),
                    'state_zerotier_log': str(NEW_ZT_LOG),
                    'state_native_voice_log': str(NEW_VOICE_LOG),
                    'state_video_previous': str(NEW_VIDEO_PREVIOUS),
                }
        else:
            uid = os.getuid(); gid = os.getgid()

    old_backup = _mapped(root, OLD_BACKUP_DIR)
    new_backup = _mapped(root, NEW_BACKUP_DIR)
    old_zt = _mapped(root, OLD_ZT_LOG)
    new_zt = _mapped(root, NEW_ZT_LOG)
    old_voice = _mapped(root, OLD_VOICE_LOG)
    new_voice = _mapped(root, NEW_VOICE_LOG)
    old_video = _mapped(root, OLD_VIDEO_PREVIOUS)
    new_video = _mapped(root, NEW_VIDEO_PREVIOUS)
    home_pi = _mapped(root, Path('/home/pi'))
    new_bridge_backup = _mapped(root, NEW_BRIDGE_BACKUP_DIR)
    state_root = _mapped(root, Path('/home/pi/.local/state/siyi'))
    state_root.mkdir(parents=True, exist_ok=True)
    new_backup.mkdir(parents=True, exist_ok=True)
    new_bridge_backup.mkdir(parents=True, exist_ok=True)
    new_video.parent.mkdir(parents=True, exist_ok=True)

    moved_backups = []
    if old_backup.exists() and old_backup.is_dir() and not old_backup.is_symlink():
        for src in sorted(old_backup.rglob('*'), key=lambda p: (len(p.parts), p.as_posix())):
            rel = src.relative_to(old_backup)
            dst = new_backup / rel
            if src.is_dir() and not src.is_symlink():
                dst.mkdir(parents=True, exist_ok=True)
                continue
            dst.parent.mkdir(parents=True, exist_ok=True)
            final = _collision_path(dst)
            shutil.move(str(src), str(final))
            moved_backups.append(str(final))
        shutil.rmtree(old_backup)
    elif old_backup.exists() or old_backup.is_symlink():
        final = _move(old_backup, new_backup / 'legacy_backups_node')
        if final: moved_backups.append(str(final))

    moved_bridge_backups = []
    if home_pi.exists() and home_pi.is_dir() and not home_pi.is_symlink():
        for src in sorted(home_pi.glob('siyi_mav_button_bridge.py.*'), key=lambda p: p.name):
            final = _move(src, new_bridge_backup / src.name)
            if final:
                moved_bridge_backups.append(str(final))

    zt_target = None
    if old_zt.exists() or old_zt.is_symlink():
        if old_zt.is_file() and new_zt.is_file():
            legacy = old_zt.read_bytes()
            with new_zt.open('ab') as out:
                out.write(b'\n=== migrated legacy ZeroTier transcript ===\n')
                out.write(legacy)
                if legacy and not legacy.endswith(b'\n'): out.write(b'\n')
            old_zt.unlink()
            zt_target = new_zt
        else:
            zt_target = _move(old_zt, new_zt)

    voice_target = None
    if old_voice.exists() or old_voice.is_symlink():
        if old_voice.is_file() and new_voice.is_file():
            legacy = old_voice.read_bytes()
            with new_voice.open('ab') as out:
                out.write(b'\n=== migrated legacy native-voice diagnostic ===\n')
                out.write(legacy)
                if legacy and not legacy.endswith(b'\n'): out.write(b'\n')
            old_voice.unlink()
            voice_target = new_voice
        else:
            voice_target = _move(old_voice, new_voice)

    video_target = None
    if old_video.exists() or old_video.is_symlink():
        preferred = new_video if not old_video.is_dir() or old_video.is_symlink() else new_video.parent / 'legacy_video_source_previous_node'
        video_target = _move(old_video, preferred)
        if video_target and video_target.is_file(): os.chmod(video_target, 0o640)

    for d in [state_root, new_backup, new_bridge_backup, new_zt.parent, new_voice.parent, new_video.parent]:
        d.mkdir(parents=True, exist_ok=True)
        try: os.chown(d, uid, gid)
        except PermissionError: pass
        os.chmod(d, 0o755)
    for p in state_root.rglob('*'):
        try: os.chown(p, uid, gid)
        except PermissionError: pass
        if p.is_dir() and not p.is_symlink(): os.chmod(p, 0o755)
    for log in [new_zt, new_voice]:
        if log.is_file(): os.chmod(log, 0o600)
    for previous in new_video.parent.glob('video_source.json.previous*'):
        if previous.is_file(): os.chmod(previous, 0o640)
    for backup in new_bridge_backup.glob('siyi_mav_button_bridge.py.*'):
        if backup.is_file() and not backup.is_symlink(): os.chmod(backup, 0o600)

    return {
        'legacy_webui_backup_dir_removed': not old_backup.exists(),
        'legacy_zerotier_log_removed': not old_zt.exists(),
        'legacy_native_voice_log_removed': not old_voice.exists(),
        'legacy_video_source_previous_removed': not old_video.exists(),
        'legacy_bridge_backups_removed': not any(home_pi.glob('siyi_mav_button_bridge.py.*')),
        'moved_backup_files': moved_backups,
        'moved_bridge_backup_files': moved_bridge_backups,
        'zerotier_migrated_to': str(zt_target or ''),
        'native_voice_migrated_to': str(voice_target or ''),
        'video_previous_migrated_to': str(video_target or ''),
        'state_backup_dir': str(NEW_BACKUP_DIR),
        'state_bridge_backup_dir': str(NEW_BRIDGE_BACKUP_DIR),
        'state_zerotier_log': str(NEW_ZT_LOG),
        'state_native_voice_log': str(NEW_VOICE_LOG),
        'state_video_previous': str(NEW_VIDEO_PREVIOUS),
    }

import json
root_override = Path(os.environ.get('SIYI_MIGRATION_ROOT', '/'))
result = migrate_runtime_state(root_override)
print(json.dumps(result, indent=2, sort_keys=True))
PYRUNTIMESTATE
}
migrate_siyi_runtime_state_artifacts
current=""
current_build=""
current_status="$(read_text_marker /etc/siyi/release_status)"
if [ "$current_status" = rollback_failed ]; then
  die "A previous rollback is incomplete (release_status=rollback_failed). Manual recovery and evidence review are required before another install."
fi
SIYI_ROUTE="fresh"
SIYI_SOURCE_RELEASE=""
SIYI_SOURCE_BUILD=""
SIYI_SOURCE_VARIANT="clean_os"
# FLIGHTCORE_4_3_0_RC7_V79_GIMBAL_RUNTIME_SOURCE_FINGERPRINT_RACE_FIX_V1
normalize_source_gimbal_runtime_transients() {
  _dst="$TX_DIR/source-runtime-transients"
  sudo mkdir -p "$_dst"
  for _p in /home/pi/siyi_gimbal_state.json.tmp*; do
    [ -e "$_p" ] || continue
    _b="$(basename "$_p")"
    case "$_b" in
      siyi_gimbal_state.json.tmp*)
        sudo mv "$_p" "$_dst/${_b}.$(date +%s%N)" 2>/dev/null || true
        ;;
    esac
  done
}
verify_source_fingerprint_runtime_safe() {
  _log="$1"
  _tries=0
  while [ "$_tries" -lt 4 ]; do
    _tries=$((_tries+1))
    normalize_source_gimbal_runtime_transients
    if sudo /usr/local/sbin/siyi-release-fingerprint --verify >"$_log" 2>&1; then
      return 0
    fi
    if grep -Eq '^unexpected managed paths: .*?/home/pi:siyi_gimbal_state\.json\.tmp' "$_log"; then
      sleep 0.10
      continue
    fi
    cat "$_log" >&2 || true
    return 1
  done
  cat "$_log" >&2 || true
  return 1
}
# FLIGHTCORE_4_3_0_RC16_OWNERSHIP_AWARE_SOURCE_VERIFICATION_V1
# A zero exit status from the live ownership-aware verifier is authoritative.
# Offline --skip-ownership digests remain fixture evidence and are never
# compared with the live verifier output.
# FLIGHTCORE_4_3_0_RC20_REGISTRY_COMPATIBILITY_MATRIX_V1
if [ -e "$release_marker" ]; then
  current="$(read_semver_marker "$release_marker")"
  current_build="$(read_text_marker /etc/siyi/release_build)"
  current_status="$(read_text_marker /etc/siyi/release_status)"
  echo "=== Existing marker: version=${current:-unreadable} build=${current_build:-unknown} status=${current_status:-unknown} ==="
  if [ "$current" = "4.3.0" ] && [ "$current_build" = "FLIGHTCORE_4_3_0_RELEASE_CANDIDATE_V6" ] && [ "$current_status" = accepted ]; then
    current_server_sha="$(sha256sum /home/pi/siyi-webui/server.py 2>/dev/null | awk '{print $1}')"
    current_daemon_sha="$(sha256sum /usr/local/lib/siyi/groundstation/groundstation_daemon.py 2>/dev/null | awk '{print $1}')"
    current_bridge_sha="$(sha256sum /home/pi/siyi_mav_button_bridge.py 2>/dev/null | awk '{print $1}')"
    current_registry_sha="$(sha256sum /usr/local/lib/flightcore/registry_client.py 2>/dev/null | awk '{print $1}')"
    current_registry_cfg_sha="$(sha256sum /usr/local/sbin/flightcore-registry-config 2>/dev/null | awk '{print $1}')"
    current_manifest_sha="$(sha256sum /usr/local/share/siyi/releases/4.3.0/payload-manifest.json 2>/dev/null | awk '{print $1}')"
    [ "$current_server_sha" = "b8904d5ff5c259ede4d4c1b29de3ffa175227c243d2c5b6ac871a602d0415506" ] || die "4.3.0 RC6 / Factory V71 -> RC29 refused: server.py differs ($current_server_sha)."
    [ "$current_daemon_sha" = "dca4392b8ca475ce8cfa595bb8fdd0e1545fbf80ff175c555bd2fa51cf043ce0" ] || die "4.3.0 RC6 / Factory V71 -> RC29 refused: Ground Station daemon differs ($current_daemon_sha)."
    [ "$current_bridge_sha" = "2afea065f2584d85e321ef4b854cb960b59d28a9b0bdc357cd46fd5fe3626c38" ] || die "4.3.0 RC6 / Factory V71 -> RC29 refused: button bridge differs ($current_bridge_sha)."
    [ "$current_registry_sha" = "d16db6b2bc73e67626d033c7c323d3c665389d696e3b65dd5c4299f0700c0be3" ] || die "4.3.0 RC6 / Factory V71 -> RC29 refused: Registry client differs ($current_registry_sha)."
    [ "$current_registry_cfg_sha" = "1cc3d3e25a68a28e10b6cf938e46863856928d8eb971a1f8e0aa3a01e6ed9a9e" ] || die "4.3.0 RC6 / Factory V71 -> RC29 refused: Registry config differs ($current_registry_cfg_sha)."
    [ "$current_manifest_sha" = "29af8df8a2763ebdf8fa8eff79cedc4727318bb94b4cfea624acf0e7026921e0" ] || die "4.3.0 RC6 / Factory V71 -> RC29 refused: payload manifest differs ($current_manifest_sha)."
    [ -x /usr/local/sbin/siyi-release-fingerprint ] || die "4.3.0 RC6 / Factory V71 -> RC29 refused: fingerprint tool missing."
    verify_source_fingerprint_runtime_safe "$TX_DIR/4_3_0_rc6_factory_v71_registry_required-source-fingerprint.txt" || die "4.3.0 RC6 / Factory V71 -> RC29 refused: canonical source fingerprint failed."
    SIYI_ROUTE="upgrade"; SIYI_SOURCE_RELEASE="4.3.0"; SIYI_SOURCE_BUILD="$current_build"; SIYI_SOURCE_VARIANT="4_3_0_rc6_factory_v71_registry_required"
    echo "=== Approved compatibility route: 4.3.0 RC6 / Factory V71 -> FlightCore 4.3.0 RC29 ==="
  elif [ "$current" = "4.3.0" ] && [ "$current_build" = "20260817.222550-31184ef" ] && [ "$current_status" = accepted ]; then
    current_server_sha="$(sha256sum /home/pi/siyi-webui/server.py 2>/dev/null | awk '{print $1}')"
    current_daemon_sha="$(sha256sum /usr/local/lib/siyi/groundstation/groundstation_daemon.py 2>/dev/null | awk '{print $1}')"
    current_bridge_sha="$(sha256sum /home/pi/siyi_mav_button_bridge.py 2>/dev/null | awk '{print $1}')"
    current_registry_sha="$(sha256sum /usr/local/lib/flightcore/registry_client.py 2>/dev/null | awk '{print $1}')"
    current_registry_cfg_sha="$(sha256sum /usr/local/sbin/flightcore-registry-config 2>/dev/null | awk '{print $1}')"
    current_manifest_sha="$(sha256sum /usr/local/share/siyi/releases/4.3.0/payload-manifest.json 2>/dev/null | awk '{print $1}')"
    [ "$current_server_sha" = "abdbcb7b8b78018283e6dbc93528b592934b3731531cf6845fe00c826f01113d" ] || die "4.3.0-rc.17 -> RC29 refused: server.py differs ($current_server_sha)."
    [ "$current_daemon_sha" = "76370699570328fc13239d21e58f0dfcb2b44b24fd20f72c5c6b02d1b994f10b" ] || die "4.3.0-rc.17 -> RC29 refused: Ground Station daemon differs ($current_daemon_sha)."
    [ "$current_bridge_sha" = "774fd4ba3d84a6c6fa80a1ca25f6be47857fea1fdad0bfcc15d0087af379a678" ] || die "4.3.0-rc.17 -> RC29 refused: button bridge differs ($current_bridge_sha)."
    [ "$current_registry_sha" = "a85f5b7646a7697a6506524b3c5eec3b13468883361bbaea8a92c5dcfa7db99c" ] || die "4.3.0-rc.17 -> RC29 refused: Registry client differs ($current_registry_sha)."
    [ "$current_registry_cfg_sha" = "1cc3d3e25a68a28e10b6cf938e46863856928d8eb971a1f8e0aa3a01e6ed9a9e" ] || die "4.3.0-rc.17 -> RC29 refused: Registry config differs ($current_registry_cfg_sha)."
    [ "$current_manifest_sha" = "95a34d56ebcfe2c7aa4ce6b5450be0caaac138801eca263155762094415d3386" ] || die "4.3.0-rc.17 -> RC29 refused: payload manifest differs ($current_manifest_sha)."
    [ -x /usr/local/sbin/siyi-release-fingerprint ] || die "4.3.0-rc.17 -> RC29 refused: fingerprint tool missing."
    verify_source_fingerprint_runtime_safe "$TX_DIR/4_3_0_rc_17_registry_required-source-fingerprint.txt" || die "4.3.0-rc.17 -> RC29 refused: canonical source fingerprint failed."
    SIYI_ROUTE="upgrade"; SIYI_SOURCE_RELEASE="4.3.0"; SIYI_SOURCE_BUILD="$current_build"; SIYI_SOURCE_VARIANT="4_3_0_rc_17_registry_required"
    echo "=== Approved compatibility route: 4.3.0-rc.17 -> FlightCore 4.3.0 RC29 ==="
  elif [ "$current" = "4.3.0" ] && [ "$current_build" = "20260818.234700-562be25" ] && [ "$current_status" = accepted ]; then
    current_server_sha="$(sha256sum /home/pi/siyi-webui/server.py 2>/dev/null | awk '{print $1}')"
    current_daemon_sha="$(sha256sum /usr/local/lib/siyi/groundstation/groundstation_daemon.py 2>/dev/null | awk '{print $1}')"
    current_bridge_sha="$(sha256sum /home/pi/siyi_mav_button_bridge.py 2>/dev/null | awk '{print $1}')"
    current_registry_sha="$(sha256sum /usr/local/lib/flightcore/registry_client.py 2>/dev/null | awk '{print $1}')"
    current_registry_cfg_sha="$(sha256sum /usr/local/sbin/flightcore-registry-config 2>/dev/null | awk '{print $1}')"
    current_manifest_sha="$(sha256sum /usr/local/share/siyi/releases/4.3.0/payload-manifest.json 2>/dev/null | awk '{print $1}')"
    [ "$current_server_sha" = "94a9dd49c4bd8ac690f5541c57fb45b63f7dd4bcfeeabc4896fa534fb1a87497" ] || die "4.3.0-rc.18 -> RC29 refused: server.py differs ($current_server_sha)."
    [ "$current_daemon_sha" = "76370699570328fc13239d21e58f0dfcb2b44b24fd20f72c5c6b02d1b994f10b" ] || die "4.3.0-rc.18 -> RC29 refused: Ground Station daemon differs ($current_daemon_sha)."
    [ "$current_bridge_sha" = "774fd4ba3d84a6c6fa80a1ca25f6be47857fea1fdad0bfcc15d0087af379a678" ] || die "4.3.0-rc.18 -> RC29 refused: button bridge differs ($current_bridge_sha)."
    [ "$current_registry_sha" = "95a771fca871687af0844a4b39237dce2acdb0b6d561b68e58203f22bf28756a" ] || die "4.3.0-rc.18 -> RC29 refused: Registry client differs ($current_registry_sha)."
    [ "$current_registry_cfg_sha" = "1cc3d3e25a68a28e10b6cf938e46863856928d8eb971a1f8e0aa3a01e6ed9a9e" ] || die "4.3.0-rc.18 -> RC29 refused: Registry config differs ($current_registry_cfg_sha)."
    [ "$current_manifest_sha" = "032ff9ee3f1284f6e9a1d7aa3414c1efd2ca9b80b1a15c88412704f8ac52773e" ] || die "4.3.0-rc.18 -> RC29 refused: payload manifest differs ($current_manifest_sha)."
    [ -x /usr/local/sbin/siyi-release-fingerprint ] || die "4.3.0-rc.18 -> RC29 refused: fingerprint tool missing."
    verify_source_fingerprint_runtime_safe "$TX_DIR/4_3_0_rc_18_registry_required-source-fingerprint.txt" || die "4.3.0-rc.18 -> RC29 refused: canonical source fingerprint failed."
    SIYI_ROUTE="upgrade"; SIYI_SOURCE_RELEASE="4.3.0"; SIYI_SOURCE_BUILD="$current_build"; SIYI_SOURCE_VARIANT="4_3_0_rc_18_registry_required"
    echo "=== Approved compatibility route: 4.3.0-rc.18 -> FlightCore 4.3.0 RC29 ==="
  elif [ "$current" = "4.3.0" ] && [ "$current_build" = "20260819.090000-9d3c3b3" ] && [ "$current_status" = accepted ]; then
    current_server_sha="$(sha256sum /home/pi/siyi-webui/server.py 2>/dev/null | awk '{print $1}')"
    current_daemon_sha="$(sha256sum /usr/local/lib/siyi/groundstation/groundstation_daemon.py 2>/dev/null | awk '{print $1}')"
    current_bridge_sha="$(sha256sum /home/pi/siyi_mav_button_bridge.py 2>/dev/null | awk '{print $1}')"
    current_registry_sha="$(sha256sum /usr/local/lib/flightcore/registry_client.py 2>/dev/null | awk '{print $1}')"
    current_registry_cfg_sha="$(sha256sum /usr/local/sbin/flightcore-registry-config 2>/dev/null | awk '{print $1}')"
    current_manifest_sha="$(sha256sum /usr/local/share/siyi/releases/4.3.0/payload-manifest.json 2>/dev/null | awk '{print $1}')"
    [ "$current_server_sha" = "fc81405d558022d40bc499bbd9a91098d27409fa5e9ab3981722e24cf75793b9" ] || die "4.3.0-rc.19 -> RC29 refused: server.py differs ($current_server_sha)."
    [ "$current_daemon_sha" = "76370699570328fc13239d21e58f0dfcb2b44b24fd20f72c5c6b02d1b994f10b" ] || die "4.3.0-rc.19 -> RC29 refused: Ground Station daemon differs ($current_daemon_sha)."
    [ "$current_bridge_sha" = "774fd4ba3d84a6c6fa80a1ca25f6be47857fea1fdad0bfcc15d0087af379a678" ] || die "4.3.0-rc.19 -> RC29 refused: button bridge differs ($current_bridge_sha)."
    [ "$current_registry_sha" = "297ab009b6b3526b451cc66759b1aab3827bd5a6c233465710bb108811cecf53" ] || die "4.3.0-rc.19 -> RC29 refused: Registry client differs ($current_registry_sha)."
    [ "$current_registry_cfg_sha" = "1cc3d3e25a68a28e10b6cf938e46863856928d8eb971a1f8e0aa3a01e6ed9a9e" ] || die "4.3.0-rc.19 -> RC29 refused: Registry config differs ($current_registry_cfg_sha)."
    [ "$current_manifest_sha" = "dfe4d26e43d39af871b84f8395e75d3d3c15cbca8555e169ab60d916d145e0f6" ] || die "4.3.0-rc.19 -> RC29 refused: payload manifest differs ($current_manifest_sha)."
    [ -x /usr/local/sbin/siyi-release-fingerprint ] || die "4.3.0-rc.19 -> RC29 refused: fingerprint tool missing."
    verify_source_fingerprint_runtime_safe "$TX_DIR/4_3_0_rc_19_registry_required-source-fingerprint.txt" || die "4.3.0-rc.19 -> RC29 refused: canonical source fingerprint failed."
    SIYI_ROUTE="upgrade"; SIYI_SOURCE_RELEASE="4.3.0"; SIYI_SOURCE_BUILD="$current_build"; SIYI_SOURCE_VARIANT="4_3_0_rc_19_registry_required"
    echo "=== Approved compatibility route: 4.3.0-rc.19 -> FlightCore 4.3.0 RC29 ==="
  elif [ "$current" = "4.3.0" ] && [ "$current_build" = "20260819.103000-6f8a2c1" ] && [ "$current_status" = accepted ]; then
    current_server_sha="$(sha256sum /home/pi/siyi-webui/server.py 2>/dev/null | awk '{print $1}')"
    current_daemon_sha="$(sha256sum /usr/local/lib/siyi/groundstation/groundstation_daemon.py 2>/dev/null | awk '{print $1}')"
    current_bridge_sha="$(sha256sum /home/pi/siyi_mav_button_bridge.py 2>/dev/null | awk '{print $1}')"
    current_registry_sha="$(sha256sum /usr/local/lib/flightcore/registry_client.py 2>/dev/null | awk '{print $1}')"
    current_registry_cfg_sha="$(sha256sum /usr/local/sbin/flightcore-registry-config 2>/dev/null | awk '{print $1}')"
    current_manifest_sha="$(sha256sum /usr/local/share/siyi/releases/4.3.0/payload-manifest.json 2>/dev/null | awk '{print $1}')"
    [ "$current_server_sha" = "2e1bb0f97fea5693c00c2d64bcf48c4ae3d11503da2c762ceac735a57c80a035" ] || die "4.3.0-rc.20 -> RC29 refused: server.py differs ($current_server_sha)."
    [ "$current_daemon_sha" = "76370699570328fc13239d21e58f0dfcb2b44b24fd20f72c5c6b02d1b994f10b" ] || die "4.3.0-rc.20 -> RC29 refused: Ground Station daemon differs ($current_daemon_sha)."
    [ "$current_bridge_sha" = "774fd4ba3d84a6c6fa80a1ca25f6be47857fea1fdad0bfcc15d0087af379a678" ] || die "4.3.0-rc.20 -> RC29 refused: button bridge differs ($current_bridge_sha)."
    [ "$current_registry_sha" = "6effd6df2eaf41a84f5bfccd1ee8a23108991a60b89b529574658700acb7d2ef" ] || die "4.3.0-rc.20 -> RC29 refused: Registry client differs ($current_registry_sha)."
    [ "$current_registry_cfg_sha" = "1cc3d3e25a68a28e10b6cf938e46863856928d8eb971a1f8e0aa3a01e6ed9a9e" ] || die "4.3.0-rc.20 -> RC29 refused: Registry config differs ($current_registry_cfg_sha)."
    [ "$current_manifest_sha" = "d2102a7bf77c0f59c29d8cb287d4ad2ce7924688bbc6dcc0607bc66438083b4b" ] || die "4.3.0-rc.20 -> RC29 refused: payload manifest differs ($current_manifest_sha)."
    [ -x /usr/local/sbin/siyi-release-fingerprint ] || die "4.3.0-rc.20 -> RC29 refused: fingerprint tool missing."
    verify_source_fingerprint_runtime_safe "$TX_DIR/4_3_0_rc_20_registry_required-source-fingerprint.txt" || die "4.3.0-rc.20 -> RC29 refused: canonical source fingerprint failed."
    SIYI_ROUTE="upgrade"; SIYI_SOURCE_RELEASE="4.3.0"; SIYI_SOURCE_BUILD="$current_build"; SIYI_SOURCE_VARIANT="4_3_0_rc_20_registry_required"
    echo "=== Approved compatibility route: 4.3.0-rc.20 -> FlightCore 4.3.0 RC29 ==="
  elif [ "$current" = "4.3.0" ] && [ "$current_build" = "20260819.190000-21c7a91" ] && [ "$current_status" = accepted ]; then
    current_server_sha="$(sha256sum /home/pi/siyi-webui/server.py 2>/dev/null | awk '{print $1}')"
    current_daemon_sha="$(sha256sum /usr/local/lib/siyi/groundstation/groundstation_daemon.py 2>/dev/null | awk '{print $1}')"
    current_bridge_sha="$(sha256sum /home/pi/siyi_mav_button_bridge.py 2>/dev/null | awk '{print $1}')"
    current_registry_sha="$(sha256sum /usr/local/lib/flightcore/registry_client.py 2>/dev/null | awk '{print $1}')"
    current_registry_cfg_sha="$(sha256sum /usr/local/sbin/flightcore-registry-config 2>/dev/null | awk '{print $1}')"
    current_manifest_sha="$(sha256sum /usr/local/share/siyi/releases/4.3.0/payload-manifest.json 2>/dev/null | awk '{print $1}')"
    [ "$current_server_sha" = "45852887f7e33015994db99c10bff9c98c5289db3f64a5e858ba450cef47a302" ] || die "4.3.0-rc.21 -> RC29 refused: server.py differs ($current_server_sha)."
    [ "$current_daemon_sha" = "ce1adc28b1509b4fc4ab43b956460e2c707edabf42745bf099ddefc62cfff362" ] || die "4.3.0-rc.21 -> RC29 refused: Ground Station daemon differs ($current_daemon_sha)."
    [ "$current_bridge_sha" = "774fd4ba3d84a6c6fa80a1ca25f6be47857fea1fdad0bfcc15d0087af379a678" ] || die "4.3.0-rc.21 -> RC29 refused: button bridge differs ($current_bridge_sha)."
    [ "$current_registry_sha" = "6effd6df2eaf41a84f5bfccd1ee8a23108991a60b89b529574658700acb7d2ef" ] || die "4.3.0-rc.21 -> RC29 refused: Registry client differs ($current_registry_sha)."
    [ "$current_registry_cfg_sha" = "1cc3d3e25a68a28e10b6cf938e46863856928d8eb971a1f8e0aa3a01e6ed9a9e" ] || die "4.3.0-rc.21 -> RC29 refused: Registry config differs ($current_registry_cfg_sha)."
    [ "$current_manifest_sha" = "a538f5517cadd0c1131edf600dd206a277309af6480572b49783d10d07f2abf9" ] || die "4.3.0-rc.21 -> RC29 refused: payload manifest differs ($current_manifest_sha)."
    [ -x /usr/local/sbin/siyi-release-fingerprint ] || die "4.3.0-rc.21 -> RC29 refused: fingerprint tool missing."
    verify_source_fingerprint_runtime_safe "$TX_DIR/4_3_0_rc_21_registry_required-source-fingerprint.txt" || die "4.3.0-rc.21 -> RC29 refused: canonical source fingerprint failed."
    SIYI_ROUTE="upgrade"; SIYI_SOURCE_RELEASE="4.3.0"; SIYI_SOURCE_BUILD="$current_build"; SIYI_SOURCE_VARIANT="4_3_0_rc_21_registry_required"
    echo "=== Approved compatibility route: 4.3.0-rc.21 -> FlightCore 4.3.0 RC29 ==="
  elif [ "$current" = "4.3.0" ] && [ "$current_build" = "20260819.201500-22c8b41" ] && [ "$current_status" = accepted ]; then
    current_server_sha="$(sha256sum /home/pi/siyi-webui/server.py 2>/dev/null | awk '{print $1}')"
    current_daemon_sha="$(sha256sum /usr/local/lib/siyi/groundstation/groundstation_daemon.py 2>/dev/null | awk '{print $1}')"
    current_bridge_sha="$(sha256sum /home/pi/siyi_mav_button_bridge.py 2>/dev/null | awk '{print $1}')"
    current_registry_sha="$(sha256sum /usr/local/lib/flightcore/registry_client.py 2>/dev/null | awk '{print $1}')"
    current_registry_cfg_sha="$(sha256sum /usr/local/sbin/flightcore-registry-config 2>/dev/null | awk '{print $1}')"
    current_manifest_sha="$(sha256sum /usr/local/share/siyi/releases/4.3.0/payload-manifest.json 2>/dev/null | awk '{print $1}')"
    [ "$current_server_sha" = "76c84f82bad9f9e435eb5a0a20fb212eba2e5210c99e879345671d3473cd2877" ] || die "4.3.0-rc.22 -> RC29 refused: server.py differs ($current_server_sha)."
    [ "$current_daemon_sha" = "ce1adc28b1509b4fc4ab43b956460e2c707edabf42745bf099ddefc62cfff362" ] || die "4.3.0-rc.22 -> corrected RC29 refused: Ground Station daemon differs ($current_daemon_sha)."
    [ "$current_bridge_sha" = "774fd4ba3d84a6c6fa80a1ca25f6be47857fea1fdad0bfcc15d0087af379a678" ] || die "4.3.0-rc.22 -> corrected RC29 refused: button bridge differs ($current_bridge_sha)."
    [ "$current_registry_sha" = "6effd6df2eaf41a84f5bfccd1ee8a23108991a60b89b529574658700acb7d2ef" ] || die "4.3.0-rc.22 -> corrected RC29 refused: Registry client differs ($current_registry_sha)."
    [ "$current_registry_cfg_sha" = "1cc3d3e25a68a28e10b6cf938e46863856928d8eb971a1f8e0aa3a01e6ed9a9e" ] || die "4.3.0-rc.22 -> corrected RC29 refused: Registry config differs ($current_registry_cfg_sha)."
    [ "$current_manifest_sha" = "e5a7f43364f7ebcbc8e61cc59edf4feb5935ee282e8d709319ca14bc9f001908" ] || die "4.3.0-rc.22 -> RC29 refused: payload manifest differs ($current_manifest_sha)."
    [ -x /usr/local/sbin/siyi-release-fingerprint ] || die "4.3.0-rc.22 -> corrected RC29 refused: fingerprint tool missing."
    verify_source_fingerprint_runtime_safe "$TX_DIR/4_3_0_rc_22_initial-source-fingerprint.txt" || die "4.3.0-rc.22 -> corrected RC29 refused: canonical source fingerprint failed."
    SIYI_ROUTE="upgrade"; SIYI_SOURCE_RELEASE="4.3.0"; SIYI_SOURCE_BUILD="$current_build"; SIYI_SOURCE_VARIANT="4_3_0_rc_22_initial"
    echo "=== Approved compatibility route: 4.3.0-rc.22 -> FlightCore 4.3.0 RC29 ==="
  elif [ "$current" = "4.3.0" ] && [ "$current_build" = "20260819.214500-23d9c62" ] && [ "$current_status" = accepted ]; then
    current_server_sha="$(sha256sum /home/pi/siyi-webui/server.py 2>/dev/null | awk '{print $1}')"
    current_daemon_sha="$(sha256sum /usr/local/lib/siyi/groundstation/groundstation_daemon.py 2>/dev/null | awk '{print $1}')"
    current_bridge_sha="$(sha256sum /home/pi/siyi_mav_button_bridge.py 2>/dev/null | awk '{print $1}')"
    current_registry_sha="$(sha256sum /usr/local/lib/flightcore/registry_client.py 2>/dev/null | awk '{print $1}')"
    current_registry_cfg_sha="$(sha256sum /usr/local/sbin/flightcore-registry-config 2>/dev/null | awk '{print $1}')"
    current_manifest_sha="$(sha256sum /usr/local/share/siyi/releases/4.3.0/payload-manifest.json 2>/dev/null | awk '{print $1}')"
    [ "$current_server_sha" = "26352d2dd3c59a754dc3a490880d78b73fecbac27ac4b691da68a1d1494621d7" ] || die "4.3.0-rc.23 -> RC29 refused: server.py differs ($current_server_sha)."
    [ "$current_daemon_sha" = "ce1adc28b1509b4fc4ab43b956460e2c707edabf42745bf099ddefc62cfff362" ] || die "4.3.0-rc.23 -> RC29 refused: Ground Station daemon differs ($current_daemon_sha)."
    [ "$current_bridge_sha" = "774fd4ba3d84a6c6fa80a1ca25f6be47857fea1fdad0bfcc15d0087af379a678" ] || die "4.3.0-rc.23 -> RC29 refused: button bridge differs ($current_bridge_sha)."
    [ "$current_registry_sha" = "6effd6df2eaf41a84f5bfccd1ee8a23108991a60b89b529574658700acb7d2ef" ] || die "4.3.0-rc.23 -> RC29 refused: Registry client differs ($current_registry_sha)."
    [ "$current_registry_cfg_sha" = "1cc3d3e25a68a28e10b6cf938e46863856928d8eb971a1f8e0aa3a01e6ed9a9e" ] || die "4.3.0-rc.23 -> RC29 refused: Registry config differs ($current_registry_cfg_sha)."
    [ "$current_manifest_sha" = "787465ec1f088dc5d6dbf1e34f1526f2866e1fea45d922d1f153fbf97bcf17ca" ] || die "4.3.0-rc.23 -> RC29 refused: payload manifest differs ($current_manifest_sha)."
    [ -x /usr/local/sbin/siyi-release-fingerprint ] || die "4.3.0-rc.23 -> RC29 refused: fingerprint tool missing."
    verify_source_fingerprint_runtime_safe "$TX_DIR/4_3_0_rc_23-source-fingerprint.txt" || die "4.3.0-rc.23 -> RC29 refused: canonical source fingerprint failed."
    SIYI_ROUTE="upgrade"; SIYI_SOURCE_RELEASE="4.3.0"; SIYI_SOURCE_BUILD="$current_build"; SIYI_SOURCE_VARIANT="4_3_0_rc_23"
    echo "=== Approved compatibility route: 4.3.0-rc.23 -> FlightCore 4.3.0 RC29 ==="
  elif [ "$current" = "4.3.0" ] && [ "$current_build" = "20260819.220500-24e1d74" ] && [ "$current_status" = accepted ]; then
    current_server_sha="$(sha256sum /home/pi/siyi-webui/server.py 2>/dev/null | awk '{print $1}')"
    current_daemon_sha="$(sha256sum /usr/local/lib/siyi/groundstation/groundstation_daemon.py 2>/dev/null | awk '{print $1}')"
    current_bridge_sha="$(sha256sum /home/pi/siyi_mav_button_bridge.py 2>/dev/null | awk '{print $1}')"
    current_registry_sha="$(sha256sum /usr/local/lib/flightcore/registry_client.py 2>/dev/null | awk '{print $1}')"
    current_registry_cfg_sha="$(sha256sum /usr/local/sbin/flightcore-registry-config 2>/dev/null | awk '{print $1}')"
    current_manifest_sha="$(sha256sum /usr/local/share/siyi/releases/4.3.0/payload-manifest.json 2>/dev/null | awk '{print $1}')"
    [ "$current_server_sha" = "f72366178deaf7dc25959d6a318a30f98742d8428f46e6b95599da0747b0a70e" ] || die "4.3.0-rc.24 -> RC29 refused: server.py differs ($current_server_sha)."
    [ "$current_daemon_sha" = "ce1adc28b1509b4fc4ab43b956460e2c707edabf42745bf099ddefc62cfff362" ] || die "4.3.0-rc.24 -> RC29 refused: Ground Station daemon differs ($current_daemon_sha)."
    [ "$current_bridge_sha" = "774fd4ba3d84a6c6fa80a1ca25f6be47857fea1fdad0bfcc15d0087af379a678" ] || die "4.3.0-rc.24 -> RC29 refused: button bridge differs ($current_bridge_sha)."
    [ "$current_registry_sha" = "6effd6df2eaf41a84f5bfccd1ee8a23108991a60b89b529574658700acb7d2ef" ] || die "4.3.0-rc.24 -> RC29 refused: Registry client differs ($current_registry_sha)."
    [ "$current_registry_cfg_sha" = "1cc3d3e25a68a28e10b6cf938e46863856928d8eb971a1f8e0aa3a01e6ed9a9e" ] || die "4.3.0-rc.24 -> RC29 refused: Registry config differs ($current_registry_cfg_sha)."
    [ "$current_manifest_sha" = "41f23c47bb9baea7aa7a642683a0cd4a5a0d2463e73ee0631f73cf7095312a67" ] || die "4.3.0-rc.24 -> RC29 refused: payload manifest differs ($current_manifest_sha)."
    [ -x /usr/local/sbin/siyi-release-fingerprint ] || die "4.3.0-rc.24 -> RC29 refused: fingerprint tool missing."
    verify_source_fingerprint_runtime_safe "$TX_DIR/4_3_0_rc_24-source-fingerprint.txt" || die "4.3.0-rc.24 -> RC29 refused: canonical source fingerprint failed."
    SIYI_ROUTE="upgrade"; SIYI_SOURCE_RELEASE="4.3.0"; SIYI_SOURCE_BUILD="$current_build"; SIYI_SOURCE_VARIANT="4_3_0_rc_24"
    echo "=== Approved compatibility route: exact 4.3.0-rc.24 build 20260819.220500-24e1d74 -> FlightCore 4.3.0 RC29 ==="
  elif [ "$current" = "4.3.0" ] && [ "$current_build" = "20260819.223000-25f2e84" ] && [ "$current_status" = accepted ]; then
    current_server_sha="$(sha256sum /home/pi/siyi-webui/server.py 2>/dev/null | awk '{print $1}')"
    current_daemon_sha="$(sha256sum /usr/local/lib/siyi/groundstation/groundstation_daemon.py 2>/dev/null | awk '{print $1}')"
    current_bridge_sha="$(sha256sum /home/pi/siyi_mav_button_bridge.py 2>/dev/null | awk '{print $1}')"
    current_registry_sha="$(sha256sum /usr/local/lib/flightcore/registry_client.py 2>/dev/null | awk '{print $1}')"
    current_registry_cfg_sha="$(sha256sum /usr/local/sbin/flightcore-registry-config 2>/dev/null | awk '{print $1}')"
    current_manifest_sha="$(sha256sum /usr/local/share/siyi/releases/4.3.0/payload-manifest.json 2>/dev/null | awk '{print $1}')"
    [ "$current_server_sha" = "57050dd33279a36738e61477fe0772af6c4f613148bac2709a28f5ffec536600" ] || die "4.3.0-rc.25 -> RC29 refused: server.py differs ($current_server_sha)."
    [ "$current_daemon_sha" = "ce1adc28b1509b4fc4ab43b956460e2c707edabf42745bf099ddefc62cfff362" ] || die "4.3.0-rc.25 -> RC29 refused: Ground Station daemon differs ($current_daemon_sha)."
    [ "$current_bridge_sha" = "774fd4ba3d84a6c6fa80a1ca25f6be47857fea1fdad0bfcc15d0087af379a678" ] || die "4.3.0-rc.25 -> RC29 refused: button bridge differs ($current_bridge_sha)."
    [ "$current_registry_sha" = "6effd6df2eaf41a84f5bfccd1ee8a23108991a60b89b529574658700acb7d2ef" ] || die "4.3.0-rc.25 -> RC29 refused: Registry client differs ($current_registry_sha)."
    [ "$current_registry_cfg_sha" = "1cc3d3e25a68a28e10b6cf938e46863856928d8eb971a1f8e0aa3a01e6ed9a9e" ] || die "4.3.0-rc.25 -> RC29 refused: Registry config differs ($current_registry_cfg_sha)."
    [ "$current_manifest_sha" = "0ca73d4608326cd43817d41852f9990def2ffcd317429fe3e496768d5033dd97" ] || die "4.3.0-rc.25 -> RC29 refused: payload manifest differs ($current_manifest_sha)."
    [ -x /usr/local/sbin/siyi-release-fingerprint ] || die "4.3.0-rc.25 -> RC29 refused: fingerprint tool missing."
    verify_source_fingerprint_runtime_safe "$TX_DIR/4_3_0_rc_25-source-fingerprint.txt" || die "4.3.0-rc.25 -> RC29 refused: canonical source fingerprint failed."
    SIYI_ROUTE="upgrade"; SIYI_SOURCE_RELEASE="4.3.0"; SIYI_SOURCE_BUILD="$current_build"; SIYI_SOURCE_VARIANT="4_3_0_rc_25"
    echo "=== Approved compatibility route: exact 4.3.0-rc.25 build 20260819.223000-25f2e84 -> FlightCore 4.3.0 RC29 ==="
  elif [ "$current" = "4.3.0" ] && [ "$current_build" = "20260819.235000-26a3f91" ] && [ "$current_status" = accepted ]; then
    current_server_sha="$(sha256sum /home/pi/siyi-webui/server.py 2>/dev/null | awk '{print $1}')"
    current_daemon_sha="$(sha256sum /usr/local/lib/siyi/groundstation/groundstation_daemon.py 2>/dev/null | awk '{print $1}')"
    current_bridge_sha="$(sha256sum /home/pi/siyi_mav_button_bridge.py 2>/dev/null | awk '{print $1}')"
    current_registry_sha="$(sha256sum /usr/local/lib/flightcore/registry_client.py 2>/dev/null | awk '{print $1}')"
    current_registry_cfg_sha="$(sha256sum /usr/local/sbin/flightcore-registry-config 2>/dev/null | awk '{print $1}')"
    current_manifest_sha="$(sha256sum /usr/local/share/siyi/releases/4.3.0/payload-manifest.json 2>/dev/null | awk '{print $1}')"
    [ "$current_server_sha" = "95f972f1d27cc5383d65e4535670d2a2cdf1cc75865e1788ec1dff00bdffb0d4" ] || die "4.3.0-rc.26 -> RC29 refused: server.py differs ($current_server_sha)."
    [ "$current_daemon_sha" = "ce1adc28b1509b4fc4ab43b956460e2c707edabf42745bf099ddefc62cfff362" ] || die "4.3.0-rc.26 -> RC29 refused: Ground Station daemon differs ($current_daemon_sha)."
    [ "$current_bridge_sha" = "774fd4ba3d84a6c6fa80a1ca25f6be47857fea1fdad0bfcc15d0087af379a678" ] || die "4.3.0-rc.26 -> RC29 refused: button bridge differs ($current_bridge_sha)."
    [ "$current_registry_sha" = "6effd6df2eaf41a84f5bfccd1ee8a23108991a60b89b529574658700acb7d2ef" ] || die "4.3.0-rc.26 -> RC29 refused: Registry client differs ($current_registry_sha)."
    [ "$current_registry_cfg_sha" = "1cc3d3e25a68a28e10b6cf938e46863856928d8eb971a1f8e0aa3a01e6ed9a9e" ] || die "4.3.0-rc.26 -> RC29 refused: Registry config differs ($current_registry_cfg_sha)."
    [ "$current_manifest_sha" = "2db3007021c8790b03636b6742d312f8174b29a8fcdf785b25729e98dc40ac39" ] || die "4.3.0-rc.26 -> RC29 refused: payload manifest differs ($current_manifest_sha)."
    [ -x /usr/local/sbin/siyi-release-fingerprint ] || die "4.3.0-rc.26 -> RC29 refused: fingerprint tool missing."
    verify_source_fingerprint_runtime_safe "$TX_DIR/4_3_0_rc_26-source-fingerprint.txt" || die "4.3.0-rc.26 -> RC29 refused: canonical source fingerprint failed."
    SIYI_ROUTE="upgrade"; SIYI_SOURCE_RELEASE="4.3.0"; SIYI_SOURCE_BUILD="$current_build"; SIYI_SOURCE_VARIANT="4_3_0_rc_26"
    echo "=== Approved compatibility route: exact 4.3.0-rc.26 build 20260819.235000-26a3f91 -> FlightCore 4.3.0 RC29 ==="
  elif [ "$current" = "4.3.0" ] && [ "$current_build" = "20260820.201500-29d9a23" ] && [ "$current_status" = accepted ]; then
    current_server_sha="$(sha256sum /home/pi/siyi-webui/server.py 2>/dev/null | awk '{print $1}')"
    current_daemon_sha="$(sha256sum /usr/local/lib/siyi/groundstation/groundstation_daemon.py 2>/dev/null | awk '{print $1}')"
    current_bridge_sha="$(sha256sum /home/pi/siyi_mav_button_bridge.py 2>/dev/null | awk '{print $1}')"
    current_registry_sha="$(sha256sum /usr/local/lib/flightcore/registry_client.py 2>/dev/null | awk '{print $1}')"
    current_registry_cfg_sha="$(sha256sum /usr/local/sbin/flightcore-registry-config 2>/dev/null | awk '{print $1}')"
    current_manifest_sha="$(sha256sum /usr/local/share/siyi/releases/4.3.0/payload-manifest.json 2>/dev/null | awk '{print $1}')"
    [ "$current_server_sha" = "18b9cea4ff8a6b1b43edda485a80d9424353b32a6e926060ad7b36cfa5435304" ] || die "4.3.0-rc.29 -> RC31 refused: server.py differs ($current_server_sha)."
    [ "$current_daemon_sha" = "ce1adc28b1509b4fc4ab43b956460e2c707edabf42745bf099ddefc62cfff362" ] || die "4.3.0-rc.29 -> RC31 refused: Ground Station daemon differs ($current_daemon_sha)."
    [ "$current_bridge_sha" = "774fd4ba3d84a6c6fa80a1ca25f6be47857fea1fdad0bfcc15d0087af379a678" ] || die "4.3.0-rc.29 -> RC31 refused: button bridge differs ($current_bridge_sha)."
    [ "$current_registry_sha" = "6effd6df2eaf41a84f5bfccd1ee8a23108991a60b89b529574658700acb7d2ef" ] || die "4.3.0-rc.29 -> RC31 refused: Registry client differs ($current_registry_sha)."
    [ "$current_registry_cfg_sha" = "1cc3d3e25a68a28e10b6cf938e46863856928d8eb971a1f8e0aa3a01e6ed9a9e" ] || die "4.3.0-rc.29 -> RC31 refused: Registry config differs ($current_registry_cfg_sha)."
    [ "$current_manifest_sha" = "17fd0755b0839eba04df339186a875c1fdf5f947a3784d2a294b102ff6aac67a" ] || die "4.3.0-rc.29 -> RC31 refused: payload manifest differs ($current_manifest_sha)."
    [ -x /usr/local/sbin/siyi-release-fingerprint ] || die "4.3.0-rc.29 -> RC31 refused: fingerprint tool missing."
    verify_source_fingerprint_runtime_safe "$TX_DIR/4_3_0_rc_29-source-fingerprint.txt" || die "4.3.0-rc.29 -> RC31 refused: canonical source fingerprint failed."
    SIYI_ROUTE="upgrade"; SIYI_SOURCE_RELEASE="4.3.0"; SIYI_SOURCE_BUILD="$current_build"; SIYI_SOURCE_VARIANT="4_3_0_rc_29"
    echo "=== Approved compatibility route: exact 4.3.0-rc.29 build 20260820.201500-29d9a23 -> FlightCore 4.3.0 RC31 ==="
  elif [ "$current" = "4.3.0" ] && [ "$current_build" = "20260821.111225-30b7e41" ] && [ "$current_status" = accepted ]; then
    current_server_sha="$(sha256sum /home/pi/siyi-webui/server.py 2>/dev/null | awk '{print $1}')"
    current_daemon_sha="$(sha256sum /usr/local/lib/siyi/groundstation/groundstation_daemon.py 2>/dev/null | awk '{print $1}')"
    current_bridge_sha="$(sha256sum /home/pi/siyi_mav_button_bridge.py 2>/dev/null | awk '{print $1}')"
    current_registry_sha="$(sha256sum /usr/local/lib/flightcore/registry_client.py 2>/dev/null | awk '{print $1}')"
    current_registry_cfg_sha="$(sha256sum /usr/local/sbin/flightcore-registry-config 2>/dev/null | awk '{print $1}')"
    current_manifest_sha="$(sha256sum /usr/local/share/siyi/releases/4.3.0/payload-manifest.json 2>/dev/null | awk '{print $1}')"
    [ "$current_server_sha" = "c4bba669e5293fed387182eeb7f39a30be7c7a3b55ef4e938b19d81064ba6949" ] || die "4.3.0-rc.30 -> RC31 refused: server.py differs ($current_server_sha)."
    [ "$current_daemon_sha" = "ce1adc28b1509b4fc4ab43b956460e2c707edabf42745bf099ddefc62cfff362" ] || die "4.3.0-rc.30 -> RC31 refused: Ground Station daemon differs ($current_daemon_sha)."
    [ "$current_bridge_sha" = "774fd4ba3d84a6c6fa80a1ca25f6be47857fea1fdad0bfcc15d0087af379a678" ] || die "4.3.0-rc.30 -> RC31 refused: button bridge differs ($current_bridge_sha)."
    [ "$current_registry_sha" = "66c7c650425a4273dff561092d38fd5898cb228531a3530f1422909a8712605d" ] || die "4.3.0-rc.30 -> RC31 refused: Registry client differs ($current_registry_sha)."
    [ "$current_registry_cfg_sha" = "1cc3d3e25a68a28e10b6cf938e46863856928d8eb971a1f8e0aa3a01e6ed9a9e" ] || die "4.3.0-rc.30 -> RC31 refused: Registry config differs ($current_registry_cfg_sha)."
    [ "$current_manifest_sha" = "ffc521c56b0058c2d307133e9d006d900b869c6885e470b8c61f276c02c9dfde" ] || die "4.3.0-rc.30 -> RC31 refused: payload manifest differs ($current_manifest_sha)."
    [ -x /usr/local/sbin/siyi-release-fingerprint ] || die "4.3.0-rc.30 -> RC31 refused: fingerprint tool missing."
    verify_source_fingerprint_runtime_safe "$TX_DIR/4_3_0_rc_30-source-fingerprint.txt" || die "4.3.0-rc.30 -> RC31 refused: canonical source fingerprint failed."
    SIYI_ROUTE="upgrade"; SIYI_SOURCE_RELEASE="4.3.0"; SIYI_SOURCE_BUILD="$current_build"; SIYI_SOURCE_VARIANT="4_3_0_rc_30"
    echo "=== Approved compatibility route: exact 4.3.0-rc.30 build 20260821.111225-30b7e41 -> FlightCore 4.3.0 RC31 ==="
  elif [ "$current" = "4.3.0" ] && [ "$current_build" = "20260821.133000-31c8f52" ] && [ "$current_status" = accepted ]; then
    current_server_sha="$(sha256sum /home/pi/siyi-webui/server.py 2>/dev/null | awk '{print $1}')"
    current_daemon_sha="$(sha256sum /usr/local/lib/siyi/groundstation/groundstation_daemon.py 2>/dev/null | awk '{print $1}')"
    current_bridge_sha="$(sha256sum /home/pi/siyi_mav_button_bridge.py 2>/dev/null | awk '{print $1}')"
    current_registry_sha="$(sha256sum /usr/local/lib/flightcore/registry_client.py 2>/dev/null | awk '{print $1}')"
    current_registry_cfg_sha="$(sha256sum /usr/local/sbin/flightcore-registry-config 2>/dev/null | awk '{print $1}')"
    current_manifest_sha="$(sha256sum /usr/local/share/siyi/releases/4.3.0/payload-manifest.json 2>/dev/null | awk '{print $1}')"
    [ "$current_server_sha" = "e1c88093c12a8473beacb785ab291d9f10a500d7ed34188ea97c12df1c0a21b5" ] || die "4.3.0-rc.31 -> RC32 refused: server.py differs ($current_server_sha)."
    [ "$current_daemon_sha" = "ce1adc28b1509b4fc4ab43b956460e2c707edabf42745bf099ddefc62cfff362" ] || die "4.3.0-rc.31 -> RC32 refused: Ground Station daemon differs ($current_daemon_sha)."
    [ "$current_bridge_sha" = "774fd4ba3d84a6c6fa80a1ca25f6be47857fea1fdad0bfcc15d0087af379a678" ] || die "4.3.0-rc.31 -> RC32 refused: button bridge differs ($current_bridge_sha)."
    [ "$current_registry_sha" = "66c7c650425a4273dff561092d38fd5898cb228531a3530f1422909a8712605d" ] || die "4.3.0-rc.31 -> RC32 refused: Registry client differs ($current_registry_sha)."
    [ "$current_registry_cfg_sha" = "1cc3d3e25a68a28e10b6cf938e46863856928d8eb971a1f8e0aa3a01e6ed9a9e" ] || die "4.3.0-rc.31 -> RC32 refused: Registry config differs ($current_registry_cfg_sha)."
    [ "$current_manifest_sha" = "2a9932e5e3b108a36bb24b85fc563d2c47645b6a1a4c10766848fb9b2f054508" ] || die "4.3.0-rc.31 -> RC32 refused: payload manifest differs ($current_manifest_sha)."
    [ -x /usr/local/sbin/siyi-release-fingerprint ] || die "4.3.0-rc.31 -> RC32 refused: fingerprint tool missing."
    verify_source_fingerprint_runtime_safe "$TX_DIR/4_3_0_rc_31-source-fingerprint.txt" || die "4.3.0-rc.31 -> RC32 refused: canonical source fingerprint failed."
    SIYI_ROUTE="upgrade"; SIYI_SOURCE_RELEASE="4.3.0"; SIYI_SOURCE_BUILD="$current_build"; SIYI_SOURCE_VARIANT="4_3_0_rc_31"
    echo "=== Approved compatibility route: exact 4.3.0-rc.31 build 20260821.133000-31c8f52 -> FlightCore 4.3.0 RC32 ==="
  elif [ "$current" = "4.3.0" ] && [ "$current_build" = "20260821.163000-32e7a64" ] && [ "$current_status" = accepted ]; then
    current_server_sha="$(sha256sum /home/pi/siyi-webui/server.py 2>/dev/null | awk '{print $1}')"
    current_daemon_sha="$(sha256sum /usr/local/lib/siyi/groundstation/groundstation_daemon.py 2>/dev/null | awk '{print $1}')"
    current_bridge_sha="$(sha256sum /home/pi/siyi_mav_button_bridge.py 2>/dev/null | awk '{print $1}')"
    current_registry_sha="$(sha256sum /usr/local/lib/flightcore/registry_client.py 2>/dev/null | awk '{print $1}')"
    current_registry_cfg_sha="$(sha256sum /usr/local/sbin/flightcore-registry-config 2>/dev/null | awk '{print $1}')"
    current_manifest_sha="$(sha256sum /usr/local/share/siyi/releases/4.3.0/payload-manifest.json 2>/dev/null | awk '{print $1}')"
    [ "$current_server_sha" = "ce4880cac57ec255b2fca822644fbe0fab52bef637763aba3d528620438ba93e" ] || die "4.3.0-rc.32 -> RC33 refused: server.py differs ($current_server_sha)."
    [ "$current_daemon_sha" = "ce1adc28b1509b4fc4ab43b956460e2c707edabf42745bf099ddefc62cfff362" ] || die "4.3.0-rc.32 -> RC33 refused: Ground Station daemon differs ($current_daemon_sha)."
    [ "$current_bridge_sha" = "774fd4ba3d84a6c6fa80a1ca25f6be47857fea1fdad0bfcc15d0087af379a678" ] || die "4.3.0-rc.32 -> RC33 refused: button bridge differs ($current_bridge_sha)."
    [ "$current_registry_sha" = "66c7c650425a4273dff561092d38fd5898cb228531a3530f1422909a8712605d" ] || die "4.3.0-rc.32 -> RC33 refused: Registry client differs ($current_registry_sha)."
    [ "$current_registry_cfg_sha" = "1cc3d3e25a68a28e10b6cf938e46863856928d8eb971a1f8e0aa3a01e6ed9a9e" ] || die "4.3.0-rc.32 -> RC33 refused: Registry config differs ($current_registry_cfg_sha)."
    [ "$current_manifest_sha" = "e5cee417b558e0b9a31fd03e0a0a0ff276bf92ee6de460089342d9e8b80a078a" ] || die "4.3.0-rc.32 -> RC33 refused: payload manifest differs ($current_manifest_sha)."
    [ -x /usr/local/sbin/siyi-release-fingerprint ] || die "4.3.0-rc.32 -> RC33 refused: fingerprint tool missing."
    verify_source_fingerprint_runtime_safe "$TX_DIR/4_3_0_rc_32-source-fingerprint.txt" || die "4.3.0-rc.32 -> RC33 refused: canonical source fingerprint failed."
    SIYI_ROUTE="upgrade"; SIYI_SOURCE_RELEASE="4.3.0"; SIYI_SOURCE_BUILD="$current_build"; SIYI_SOURCE_VARIANT="4_3_0_rc_32"
    echo "=== Approved compatibility route: exact 4.3.0-rc.32 build 20260821.163000-32e7a64 -> FlightCore 4.3.0 RC33 ==="
  elif [ "$current" = "4.3.0" ] && [ "$current_build" = "20260821.170000-33f4b76" ] && [ "$current_status" = accepted ]; then
    current_server_sha="$(sha256sum /home/pi/siyi-webui/server.py 2>/dev/null | awk '{print $1}')"
    current_daemon_sha="$(sha256sum /usr/local/lib/siyi/groundstation/groundstation_daemon.py 2>/dev/null | awk '{print $1}')"
    current_bridge_sha="$(sha256sum /home/pi/siyi_mav_button_bridge.py 2>/dev/null | awk '{print $1}')"
    current_registry_sha="$(sha256sum /usr/local/lib/flightcore/registry_client.py 2>/dev/null | awk '{print $1}')"
    current_registry_cfg_sha="$(sha256sum /usr/local/sbin/flightcore-registry-config 2>/dev/null | awk '{print $1}')"
    current_manifest_sha="$(sha256sum /usr/local/share/siyi/releases/4.3.0/payload-manifest.json 2>/dev/null | awk '{print $1}')"
    [ "$current_server_sha" = "e8d5e69da03ce52eb498976c9a02ebb50734a8cdd75edf5e3eced762247845c8" ] || die "4.3.0-rc.33 -> RC34 refused: server.py differs ($current_server_sha)."
    [ "$current_daemon_sha" = "ce1adc28b1509b4fc4ab43b956460e2c707edabf42745bf099ddefc62cfff362" ] || die "4.3.0-rc.33 -> RC34 refused: Ground Station daemon differs ($current_daemon_sha)."
    [ "$current_bridge_sha" = "774fd4ba3d84a6c6fa80a1ca25f6be47857fea1fdad0bfcc15d0087af379a678" ] || die "4.3.0-rc.33 -> RC34 refused: button bridge differs ($current_bridge_sha)."
    [ "$current_registry_sha" = "66c7c650425a4273dff561092d38fd5898cb228531a3530f1422909a8712605d" ] || die "4.3.0-rc.33 -> RC34 refused: Registry client differs ($current_registry_sha)."
    [ "$current_registry_cfg_sha" = "1cc3d3e25a68a28e10b6cf938e46863856928d8eb971a1f8e0aa3a01e6ed9a9e" ] || die "4.3.0-rc.33 -> RC34 refused: Registry config differs ($current_registry_cfg_sha)."
    [ "$current_manifest_sha" = "4f938b88c92d68fc0c39bc7d3d1f003654e379a4636a05532405021fb36bfcb4" ] || die "4.3.0-rc.33 -> RC34 refused: payload manifest differs ($current_manifest_sha)."
    [ -x /usr/local/sbin/siyi-release-fingerprint ] || die "4.3.0-rc.33 -> RC34 refused: fingerprint tool missing."
    verify_source_fingerprint_runtime_safe "$TX_DIR/4_3_0_rc_33-source-fingerprint.txt" || die "4.3.0-rc.33 -> RC34 refused: canonical source fingerprint failed."
    SIYI_ROUTE="upgrade"; SIYI_SOURCE_RELEASE="4.3.0"; SIYI_SOURCE_BUILD="$current_build"; SIYI_SOURCE_VARIANT="4_3_0_rc_33"
    echo "=== Approved compatibility route: exact 4.3.0-rc.33 build 20260821.170000-33f4b76 -> FlightCore 4.3.0 RC34 ==="
  elif [ "$current" = "4.3.0" ] && [ "$current_build" = "20260821.223000-34c7e19" ] && [ "$current_status" = accepted ]; then
    current_server_sha="$(sha256sum /home/pi/siyi-webui/server.py 2>/dev/null | awk '{print $1}')"
    current_daemon_sha="$(sha256sum /usr/local/lib/siyi/groundstation/groundstation_daemon.py 2>/dev/null | awk '{print $1}')"
    current_bridge_sha="$(sha256sum /home/pi/siyi_mav_button_bridge.py 2>/dev/null | awk '{print $1}')"
    current_registry_sha="$(sha256sum /usr/local/lib/flightcore/registry_client.py 2>/dev/null | awk '{print $1}')"
    current_registry_cfg_sha="$(sha256sum /usr/local/sbin/flightcore-registry-config 2>/dev/null | awk '{print $1}')"
    current_manifest_sha="$(sha256sum /usr/local/share/siyi/releases/4.3.0/payload-manifest.json 2>/dev/null | awk '{print $1}')"
    [ "$current_server_sha" = "46cc12d259d43354f0d0d1ec823436a0eb52e9baac82f5edd3ecec61a89e8b41" ] || die "4.3.0-rc.34 -> RC36 refused: server.py differs ($current_server_sha)."
    [ "$current_daemon_sha" = "ce1adc28b1509b4fc4ab43b956460e2c707edabf42745bf099ddefc62cfff362" ] || die "4.3.0-rc.34 -> RC36 refused: Ground Station daemon differs ($current_daemon_sha)."
    [ "$current_bridge_sha" = "774fd4ba3d84a6c6fa80a1ca25f6be47857fea1fdad0bfcc15d0087af379a678" ] || die "4.3.0-rc.34 -> RC36 refused: button bridge differs ($current_bridge_sha)."
    [ "$current_registry_sha" = "66c7c650425a4273dff561092d38fd5898cb228531a3530f1422909a8712605d" ] || die "4.3.0-rc.34 -> RC36 refused: Registry client differs ($current_registry_sha)."
    [ "$current_registry_cfg_sha" = "1cc3d3e25a68a28e10b6cf938e46863856928d8eb971a1f8e0aa3a01e6ed9a9e" ] || die "4.3.0-rc.34 -> RC36 refused: Registry config differs ($current_registry_cfg_sha)."
    [ "$current_manifest_sha" = "37ae67a60a126d290351d5c004bf5eae201daf53a3922a4bdd672a9d0d2a55bd" ] || die "4.3.0-rc.34 -> RC36 refused: payload manifest differs ($current_manifest_sha)."
    [ -x /usr/local/sbin/siyi-release-fingerprint ] || die "4.3.0-rc.34 -> RC36 refused: fingerprint tool missing."
    verify_source_fingerprint_runtime_safe "$TX_DIR/4_3_0_rc_34-source-fingerprint.txt" || die "4.3.0-rc.34 -> RC36 refused: canonical source fingerprint failed."
    SIYI_ROUTE="upgrade"; SIYI_SOURCE_RELEASE="4.3.0"; SIYI_SOURCE_BUILD="$current_build"; SIYI_SOURCE_VARIANT="4_3_0_rc_34"
    echo "=== Approved compatibility route: exact 4.3.0-rc.34 build 20260821.223000-34c7e19 -> FlightCore 4.3.0 RC37 ==="
  elif [ "$current" = "4.3.0" ] && [ "$current_build" = "20260822.003000-36f2c18" ] && [ "$current_status" = accepted ]; then
    current_server_sha="$(sha256sum /home/pi/siyi-webui/server.py 2>/dev/null | awk '{print $1}')"
    current_daemon_sha="$(sha256sum /usr/local/lib/siyi/groundstation/groundstation_daemon.py 2>/dev/null | awk '{print $1}')"
    current_bridge_sha="$(sha256sum /home/pi/siyi_mav_button_bridge.py 2>/dev/null | awk '{print $1}')"
    current_registry_sha="$(sha256sum /usr/local/lib/flightcore/registry_client.py 2>/dev/null | awk '{print $1}')"
    current_registry_cfg_sha="$(sha256sum /usr/local/sbin/flightcore-registry-config 2>/dev/null | awk '{print $1}')"
    current_manifest_sha="$(sha256sum /usr/local/share/siyi/releases/4.3.0/payload-manifest.json 2>/dev/null | awk '{print $1}')"
    [ "$current_server_sha" = "c66dbd8dea0eb055e65716a026170837e499dfef3a35f2a45689642a55aa5b1f" ] || die "4.3.0-rc.36 -> 4.4.0 RC2 refused: server.py differs ($current_server_sha)."
    [ "$current_daemon_sha" = "ce1adc28b1509b4fc4ab43b956460e2c707edabf42745bf099ddefc62cfff362" ] || die "4.3.0-rc.36 -> 4.4.0 RC2 refused: Ground Station daemon differs ($current_daemon_sha)."
    [ "$current_bridge_sha" = "774fd4ba3d84a6c6fa80a1ca25f6be47857fea1fdad0bfcc15d0087af379a678" ] || die "4.3.0-rc.36 -> 4.4.0 RC2 refused: button bridge differs ($current_bridge_sha)."
    [ "$current_registry_sha" = "66c7c650425a4273dff561092d38fd5898cb228531a3530f1422909a8712605d" ] || die "4.3.0-rc.36 -> 4.4.0 RC2 refused: Registry client differs ($current_registry_sha)."
    [ "$current_registry_cfg_sha" = "1cc3d3e25a68a28e10b6cf938e46863856928d8eb971a1f8e0aa3a01e6ed9a9e" ] || die "4.3.0-rc.36 -> 4.4.0 RC2 refused: Registry config differs ($current_registry_cfg_sha)."
    [ "$current_manifest_sha" = "c5c3b23867e92f099113a526b385b4cb585cac01db8a657c9bee99a0f7b6c52b" ] || die "4.3.0-rc.36 -> 4.4.0 RC2 refused: payload manifest differs ($current_manifest_sha)."
    [ -x /usr/local/sbin/siyi-release-fingerprint ] || die "4.3.0-rc.36 -> 4.4.0 RC2 refused: fingerprint tool missing."
    verify_source_fingerprint_runtime_safe "$TX_DIR/4_3_0_rc_36-source-fingerprint.txt" || die "4.3.0-rc.36 -> 4.4.0 RC2 refused: canonical source fingerprint failed."
    SIYI_ROUTE="upgrade"; SIYI_SOURCE_RELEASE="4.3.0"; SIYI_SOURCE_BUILD="$current_build"; SIYI_SOURCE_VARIANT="4_3_0_rc_36"
    echo "=== Approved compatibility route: exact 4.3.0-rc.36 build 20260822.003000-36f2c18 -> FlightCore 4.4.0 RC2 ==="
  elif [ "$current" = "4.3.0" ] && [ "$current_build" = "20260822.132718-085b92b" ] && [ "$current_status" = accepted ]; then
    current_server_sha="$(sha256sum /home/pi/siyi-webui/server.py 2>/dev/null | awk '{print $1}')"
    current_daemon_sha="$(sha256sum /usr/local/lib/siyi/groundstation/groundstation_daemon.py 2>/dev/null | awk '{print $1}')"
    current_bridge_sha="$(sha256sum /home/pi/siyi_mav_button_bridge.py 2>/dev/null | awk '{print $1}')"
    current_registry_sha="$(sha256sum /usr/local/lib/flightcore/registry_client.py 2>/dev/null | awk '{print $1}')"
    current_registry_cfg_sha="$(sha256sum /usr/local/sbin/flightcore-registry-config 2>/dev/null | awk '{print $1}')"
    current_manifest_sha="$(sha256sum /usr/local/share/siyi/releases/4.3.0/payload-manifest.json 2>/dev/null | awk '{print $1}')"
    [ "$current_server_sha" = "085b92bb4ca25a8b2024a848ee7b1cba93831ed424b5c075535e6c7314222722" ] || die "4.3.0-rc.37 -> 4.4.0 RC2 refused: server.py differs ($current_server_sha)."
    [ "$current_daemon_sha" = "ce1adc28b1509b4fc4ab43b956460e2c707edabf42745bf099ddefc62cfff362" ] || die "4.3.0-rc.37 -> 4.4.0 RC2 refused: Ground Station daemon differs ($current_daemon_sha)."
    [ "$current_bridge_sha" = "774fd4ba3d84a6c6fa80a1ca25f6be47857fea1fdad0bfcc15d0087af379a678" ] || die "4.3.0-rc.37 -> 4.4.0 RC2 refused: button bridge differs ($current_bridge_sha)."
    [ "$current_registry_sha" = "66c7c650425a4273dff561092d38fd5898cb228531a3530f1422909a8712605d" ] || die "4.3.0-rc.37 -> 4.4.0 RC2 refused: Registry client differs ($current_registry_sha)."
    [ "$current_registry_cfg_sha" = "1cc3d3e25a68a28e10b6cf938e46863856928d8eb971a1f8e0aa3a01e6ed9a9e" ] || die "4.3.0-rc.37 -> 4.4.0 RC2 refused: Registry config differs ($current_registry_cfg_sha)."
    [ "$current_manifest_sha" = "71e5b5c655b5348f403224147924c6c11a54176ab0e191b99af06b08cff1e7be" ] || die "4.3.0-rc.37 -> 4.4.0 RC2 refused: payload manifest differs ($current_manifest_sha)."
    [ -x /usr/local/sbin/siyi-release-fingerprint ] || die "4.3.0-rc.37 -> 4.4.0 RC2 refused: fingerprint tool missing."
    verify_source_fingerprint_runtime_safe "$TX_DIR/4_3_0_rc_37-source-fingerprint.txt" || die "4.3.0-rc.37 -> 4.4.0 RC2 refused: canonical source fingerprint failed."
    SIYI_ROUTE="upgrade"; SIYI_SOURCE_RELEASE="4.3.0"; SIYI_SOURCE_BUILD="$current_build"; SIYI_SOURCE_VARIANT="4_3_0_rc_37"
    echo "=== Approved compatibility route: exact 4.3.0-rc.37 build 20260822.132718-085b92b -> FlightCore 4.4.0 RC2 ==="
  # Exact accepted 4.3.0 RC41 parent retained by the 4.4.0 RC2 factory build.
  elif [ "$current" = "4.3.0" ] && [ "$current_build" = "20260825.082059-3face99" ] && [ "$current_status" = accepted ]; then
    current_server_sha="$(sha256sum /home/pi/siyi-webui/server.py 2>/dev/null | awk '{print $1}')"
    current_daemon_sha="$(sha256sum /usr/local/lib/siyi/groundstation/groundstation_daemon.py 2>/dev/null | awk '{print $1}')"
    current_bridge_sha="$(sha256sum /home/pi/siyi_mav_button_bridge.py 2>/dev/null | awk '{print $1}')"
    current_registry_sha="$(sha256sum /usr/local/lib/flightcore/registry_client.py 2>/dev/null | awk '{print $1}')"
    current_registry_cfg_sha="$(sha256sum /usr/local/sbin/flightcore-registry-config 2>/dev/null | awk '{print $1}')"
    current_manifest_sha="$(sha256sum /usr/local/share/siyi/releases/4.3.0/payload-manifest.json 2>/dev/null | awk '{print $1}')"
    [ "$current_server_sha" = "dd985475e3d8f02e305e6c82d7c742723d612ab2aeae86d8d9d97c8742d3512f" ] || die "4.3.0-rc.41 -> 4.4.0-rc.2 refused: server.py differs ($current_server_sha)."
    [ "$current_daemon_sha" = "fd21ca671771e9d701f8803071c459970b48020bf3a20ddc4ac10adbfe026f68" ] || die "4.3.0-rc.41 -> 4.4.0-rc.2 refused: Ground Station daemon differs ($current_daemon_sha)."
    [ "$current_bridge_sha" = "774fd4ba3d84a6c6fa80a1ca25f6be47857fea1fdad0bfcc15d0087af379a678" ] || die "4.3.0-rc.41 -> 4.4.0-rc.2 refused: button bridge differs ($current_bridge_sha)."
    [ "$current_registry_sha" = "66c7c650425a4273dff561092d38fd5898cb228531a3530f1422909a8712605d" ] || die "4.3.0-rc.41 -> 4.4.0-rc.2 refused: Registry client differs ($current_registry_sha)."
    [ "$current_registry_cfg_sha" = "1cc3d3e25a68a28e10b6cf938e46863856928d8eb971a1f8e0aa3a01e6ed9a9e" ] || die "4.3.0-rc.41 -> 4.4.0-rc.2 refused: Registry config differs ($current_registry_cfg_sha)."
    [ "$current_manifest_sha" = "fd8bc3fff4e6c21fe5d8130d7e3e8b7efc8da636c8bb34475792995fb4801e96" ] || die "4.3.0-rc.41 -> 4.4.0-rc.2 refused: payload manifest differs ($current_manifest_sha)."
    [ -x /usr/local/sbin/siyi-release-fingerprint ] || die "4.3.0-rc.41 -> 4.4.0-rc.2 refused: fingerprint tool missing."
    verify_source_fingerprint_runtime_safe "$TX_DIR/4_3_0_rc_41-source-fingerprint.txt" || die "4.3.0-rc.41 -> 4.4.0-rc.2 refused: canonical source fingerprint failed."
    SIYI_ROUTE="upgrade"; SIYI_SOURCE_RELEASE="4.3.0-rc.41"; SIYI_SOURCE_BUILD="$current_build"; SIYI_SOURCE_VARIANT="4_3_0_rc_41"
    echo "=== Approved compatibility route: exact accepted 4.3.0-rc.41 -> FlightCore 4.4.0 RC2 ==="
  # read_semver_marker intentionally normalizes prerelease markers such as
  # 4.3.0-rc.38 to 4.3.0. Route identity is then made exact by the immutable
  # build ID, managed-file hashes and canonical installed fingerprint below.
  elif [ "$current" = "4.3.0" ] && [ "$current_build" = "20260824.182435-dd98547" ] && [ "$current_status" = accepted ]; then
    current_server_sha="$(sha256sum /home/pi/siyi-webui/server.py 2>/dev/null | awk '{print $1}')"
    current_daemon_sha="$(sha256sum /usr/local/lib/siyi/groundstation/groundstation_daemon.py 2>/dev/null | awk '{print $1}')"
    current_bridge_sha="$(sha256sum /home/pi/siyi_mav_button_bridge.py 2>/dev/null | awk '{print $1}')"
    current_registry_sha="$(sha256sum /usr/local/lib/flightcore/registry_client.py 2>/dev/null | awk '{print $1}')"
    current_registry_cfg_sha="$(sha256sum /usr/local/sbin/flightcore-registry-config 2>/dev/null | awk '{print $1}')"
    current_manifest_sha="$(sha256sum /usr/local/share/siyi/releases/4.3.0/payload-manifest.json 2>/dev/null | awk '{print $1}')"
    [ "$current_server_sha" = "dd985475e3d8f02e305e6c82d7c742723d612ab2aeae86d8d9d97c8742d3512f" ] || die "4.3.0-rc.38 -> 4.4.0 RC2 refused: server.py differs ($current_server_sha)."
    [ "$current_daemon_sha" = "ce1adc28b1509b4fc4ab43b956460e2c707edabf42745bf099ddefc62cfff362" ] || die "4.3.0-rc.38 -> 4.4.0 RC2 refused: Ground Station daemon differs ($current_daemon_sha)."
    [ "$current_bridge_sha" = "774fd4ba3d84a6c6fa80a1ca25f6be47857fea1fdad0bfcc15d0087af379a678" ] || die "4.3.0-rc.38 -> 4.4.0 RC2 refused: button bridge differs ($current_bridge_sha)."
    [ "$current_registry_sha" = "66c7c650425a4273dff561092d38fd5898cb228531a3530f1422909a8712605d" ] || die "4.3.0-rc.38 -> 4.4.0 RC2 refused: Registry client differs ($current_registry_sha)."
    [ "$current_registry_cfg_sha" = "1cc3d3e25a68a28e10b6cf938e46863856928d8eb971a1f8e0aa3a01e6ed9a9e" ] || die "4.3.0-rc.38 -> 4.4.0 RC2 refused: Registry config differs ($current_registry_cfg_sha)."
    [ "$current_manifest_sha" = "4678cc7738e6b6ee5cfaf2dfae895f5efd71ebf70068ef5e299c458866718b61" ] || die "4.3.0-rc.38 -> 4.4.0 RC2 refused: payload manifest differs ($current_manifest_sha)."
    [ -x /usr/local/sbin/siyi-release-fingerprint ] || die "4.3.0-rc.38 -> 4.4.0 RC2 refused: fingerprint tool missing."
    verify_source_fingerprint_runtime_safe "$TX_DIR/4_3_0_rc_38-source-fingerprint.txt" || die "4.3.0-rc.38 -> 4.4.0 RC2 refused: canonical source fingerprint failed."
    SIYI_ROUTE="upgrade"; SIYI_SOURCE_RELEASE="4.3.0-rc.38"; SIYI_SOURCE_BUILD="$current_build"; SIYI_SOURCE_VARIANT="4_3_0_rc_38"
    echo "=== Approved compatibility route: exact 4.3.0-rc.38 build 20260824.182435-dd98547 -> FlightCore 4.4.0 RC2 ==="
  # FLIGHTCORE_4_4_0_RC8_RC7_EXACT_ROUTE_V1
  # Exact accepted 4.4.0 RC7 parent. The semantic marker is normalized to
  # 4.4.0; build, status, managed hashes and canonical fingerprint make this
  # route byte-exact.
  elif [ "$current" = "4.4.0" ] && [ "$current_build" = "20260827.002638-bf1d2c6" ] && [ "$current_status" = accepted ]; then
    current_server_sha="$(sha256sum /home/pi/siyi-webui/server.py 2>/dev/null | awk '{print $1}')"
    current_daemon_sha="$(sha256sum /usr/local/lib/siyi/groundstation/groundstation_daemon.py 2>/dev/null | awk '{print $1}')"
    current_bridge_sha="$(sha256sum /home/pi/siyi_mav_button_bridge.py 2>/dev/null | awk '{print $1}')"
    current_registry_sha="$(sha256sum /usr/local/lib/flightcore/registry_client.py 2>/dev/null | awk '{print $1}')"
    current_registry_cfg_sha="$(sha256sum /usr/local/sbin/flightcore-registry-config 2>/dev/null | awk '{print $1}')"
    current_manifest_sha="$(sha256sum /usr/local/share/siyi/releases/4.4.0/payload-manifest.json 2>/dev/null | awk '{print $1}')"
    [ "$current_server_sha" = "36dea88068ca61cdd3268f19e57d21c4d202e280f51e1cb950df0edc589d1d08" ] || die "4.4.0-rc.7 -> 4.4.0-rc.8 refused: server.py differs ($current_server_sha)."
    [ "$current_daemon_sha" = "cce38247ba6c7093a3f73781fb27ddf9b3c47f37ab88510e9aec42bc8a163535" ] || die "4.4.0-rc.7 -> 4.4.0-rc.8 refused: Ground Station daemon differs ($current_daemon_sha)."
    [ "$current_bridge_sha" = "6c5fcddbfdf2ef0ccb94e0063f9c62043ae2b48edd2c7828929aae43d842a3f3" ] || die "4.4.0-rc.7 -> 4.4.0-rc.8 refused: button bridge differs ($current_bridge_sha)."
    [ "$current_registry_sha" = "81bbe475c9146a4d6436ba91f17d279d3ff0b57742d3c62ef8fe145dd6dcaa0d" ] || die "4.4.0-rc.7 -> 4.4.0-rc.8 refused: Registry client differs ($current_registry_sha)."
    [ "$current_registry_cfg_sha" = "1cc3d3e25a68a28e10b6cf938e46863856928d8eb971a1f8e0aa3a01e6ed9a9e" ] || die "4.4.0-rc.7 -> 4.4.0-rc.8 refused: Registry config differs ($current_registry_cfg_sha)."
    [ "$current_manifest_sha" = "1825a2d38abfedbef8a395f7ec0520f186602b31a09ec5aab0b5719a0f57b7fb" ] || die "4.4.0-rc.7 -> 4.4.0-rc.8 refused: payload manifest differs ($current_manifest_sha)."
    [ -x /usr/local/sbin/siyi-release-fingerprint ] || die "4.4.0-rc.7 -> 4.4.0-rc.8 refused: fingerprint tool missing."
    verify_source_fingerprint_runtime_safe "$TX_DIR/4_4_0_rc_7-source-fingerprint.txt" || die "4.4.0-rc.7 -> 4.4.0-rc.8 refused: canonical source fingerprint failed."
    SIYI_ROUTE="upgrade"; SIYI_SOURCE_RELEASE="4.4.0-rc.7"; SIYI_SOURCE_BUILD="$current_build"; SIYI_SOURCE_VARIANT="4_4_0_rc_7"
    echo "=== Approved compatibility route: exact accepted 4.4.0-rc.7 -> FlightCore 4.4.0 RC8 ==="
  # FLIGHTCORE_4_4_0_RC7_RC6_EXACT_ROUTE_V1
  # Exact accepted 4.4.0 RC6 parent. The semantic marker is normalized to
  # 4.4.0; build, status, managed hashes and canonical fingerprint make this
  # route byte-exact.
  elif [ "$current" = "4.4.0" ] && [ "$current_build" = "20260826.213509-1fd2743" ] && [ "$current_status" = accepted ]; then
    current_server_sha="$(sha256sum /home/pi/siyi-webui/server.py 2>/dev/null | awk '{print $1}')"
    current_daemon_sha="$(sha256sum /usr/local/lib/siyi/groundstation/groundstation_daemon.py 2>/dev/null | awk '{print $1}')"
    current_bridge_sha="$(sha256sum /home/pi/siyi_mav_button_bridge.py 2>/dev/null | awk '{print $1}')"
    current_registry_sha="$(sha256sum /usr/local/lib/flightcore/registry_client.py 2>/dev/null | awk '{print $1}')"
    current_registry_cfg_sha="$(sha256sum /usr/local/sbin/flightcore-registry-config 2>/dev/null | awk '{print $1}')"
    current_manifest_sha="$(sha256sum /usr/local/share/siyi/releases/4.4.0/payload-manifest.json 2>/dev/null | awk '{print $1}')"
    [ "$current_server_sha" = "36dea88068ca61cdd3268f19e57d21c4d202e280f51e1cb950df0edc589d1d08" ] || die "4.4.0-rc.6 -> 4.4.0-rc.7 refused: server.py differs ($current_server_sha)."
    [ "$current_daemon_sha" = "cce38247ba6c7093a3f73781fb27ddf9b3c47f37ab88510e9aec42bc8a163535" ] || die "4.4.0-rc.6 -> 4.4.0-rc.7 refused: Ground Station daemon differs ($current_daemon_sha)."
    [ "$current_bridge_sha" = "6c5fcddbfdf2ef0ccb94e0063f9c62043ae2b48edd2c7828929aae43d842a3f3" ] || die "4.4.0-rc.6 -> 4.4.0-rc.7 refused: button bridge differs ($current_bridge_sha)."
    [ "$current_registry_sha" = "81bbe475c9146a4d6436ba91f17d279d3ff0b57742d3c62ef8fe145dd6dcaa0d" ] || die "4.4.0-rc.6 -> 4.4.0-rc.7 refused: Registry client differs ($current_registry_sha)."
    [ "$current_registry_cfg_sha" = "1cc3d3e25a68a28e10b6cf938e46863856928d8eb971a1f8e0aa3a01e6ed9a9e" ] || die "4.4.0-rc.6 -> 4.4.0-rc.7 refused: Registry config differs ($current_registry_cfg_sha)."
    [ "$current_manifest_sha" = "45b11b2b8f1ec066fdfc664fe3b7d148826e90b6636528b4f247af486dc9abea" ] || die "4.4.0-rc.6 -> 4.4.0-rc.7 refused: payload manifest differs ($current_manifest_sha)."
    [ -x /usr/local/sbin/siyi-release-fingerprint ] || die "4.4.0-rc.6 -> 4.4.0-rc.7 refused: fingerprint tool missing."
    verify_source_fingerprint_runtime_safe "$TX_DIR/4_4_0_rc_6-source-fingerprint.txt" || die "4.4.0-rc.6 -> 4.4.0-rc.7 refused: canonical source fingerprint failed."
    SIYI_ROUTE="upgrade"; SIYI_SOURCE_RELEASE="4.4.0-rc.6"; SIYI_SOURCE_BUILD="$current_build"; SIYI_SOURCE_VARIANT="4_4_0_rc_6"
    echo "=== Approved compatibility route: exact accepted 4.4.0-rc.6 -> FlightCore 4.4.0 RC7 ==="
  # FLIGHTCORE_4_4_0_RC6_RC4_EXACT_ROUTE_V1
  # Exact flight-tested 4.4.0 RC4 parent. The semantic marker is normalized to
  # 4.4.0; build, status, managed hashes and canonical fingerprint make this
  # route byte-exact.
  elif [ "$current" = "4.4.0" ] && [ "$current_build" = "20260826.160745-5b68f7c" ] && [ "$current_status" = accepted ]; then
    current_server_sha="$(sha256sum /home/pi/siyi-webui/server.py 2>/dev/null | awk '{print $1}')"
    current_daemon_sha="$(sha256sum /usr/local/lib/siyi/groundstation/groundstation_daemon.py 2>/dev/null | awk '{print $1}')"
    current_bridge_sha="$(sha256sum /home/pi/siyi_mav_button_bridge.py 2>/dev/null | awk '{print $1}')"
    current_registry_sha="$(sha256sum /usr/local/lib/flightcore/registry_client.py 2>/dev/null | awk '{print $1}')"
    current_registry_cfg_sha="$(sha256sum /usr/local/sbin/flightcore-registry-config 2>/dev/null | awk '{print $1}')"
    current_manifest_sha="$(sha256sum /usr/local/share/siyi/releases/4.4.0/payload-manifest.json 2>/dev/null | awk '{print $1}')"
    [ "$current_server_sha" = "dd985475e3d8f02e305e6c82d7c742723d612ab2aeae86d8d9d97c8742d3512f" ] || die "4.4.0-rc.4 -> 4.4.0-rc.7 refused: server.py differs ($current_server_sha)."
    [ "$current_daemon_sha" = "6232971bf810e3650bf5fd3e9f164cbb6f453b3be45f10bb272155d62ac8e2ac" ] || die "4.4.0-rc.4 -> 4.4.0-rc.7 refused: Ground Station daemon differs ($current_daemon_sha)."
    [ "$current_bridge_sha" = "774fd4ba3d84a6c6fa80a1ca25f6be47857fea1fdad0bfcc15d0087af379a678" ] || die "4.4.0-rc.4 -> 4.4.0-rc.7 refused: button bridge differs ($current_bridge_sha)."
    [ "$current_registry_sha" = "66c7c650425a4273dff561092d38fd5898cb228531a3530f1422909a8712605d" ] || die "4.4.0-rc.4 -> 4.4.0-rc.7 refused: Registry client differs ($current_registry_sha)."
    [ "$current_registry_cfg_sha" = "1cc3d3e25a68a28e10b6cf938e46863856928d8eb971a1f8e0aa3a01e6ed9a9e" ] || die "4.4.0-rc.4 -> 4.4.0-rc.7 refused: Registry config differs ($current_registry_cfg_sha)."
    [ "$current_manifest_sha" = "92d93b3d3b4ff41895488f0d8c8643767e100e1bad4c3f08bc02b71bea1fbf9e" ] || die "4.4.0-rc.4 -> 4.4.0-rc.7 refused: payload manifest differs ($current_manifest_sha)."
    [ -x /usr/local/sbin/siyi-release-fingerprint ] || die "4.4.0-rc.4 -> 4.4.0-rc.7 refused: fingerprint tool missing."
    verify_source_fingerprint_runtime_safe "$TX_DIR/4_4_0_rc_4-source-fingerprint.txt" || die "4.4.0-rc.4 -> 4.4.0-rc.7 refused: canonical source fingerprint failed."
    SIYI_ROUTE="upgrade"; SIYI_SOURCE_RELEASE="4.4.0-rc.4"; SIYI_SOURCE_BUILD="$current_build"; SIYI_SOURCE_VARIANT="4_4_0_rc_4"
    echo "=== Approved compatibility route: exact accepted 4.4.0-rc.4 -> FlightCore 4.4.0 RC7 ==="
  # Retained exact 4.4.0 RC3 compatibility route.
  # Exact immutable 4.4.0 RC3 parent. The semantic marker is normalized to
  # 4.4.0; build, status, managed hashes and canonical fingerprint make this
  # route byte-exact.
  elif [ "$current" = "4.4.0" ] && [ "$current_build" = "20260826.111317-2cb17b2" ] && [ "$current_status" = accepted ]; then
    current_server_sha="$(sha256sum /home/pi/siyi-webui/server.py 2>/dev/null | awk '{print $1}')"
    current_daemon_sha="$(sha256sum /usr/local/lib/siyi/groundstation/groundstation_daemon.py 2>/dev/null | awk '{print $1}')"
    current_bridge_sha="$(sha256sum /home/pi/siyi_mav_button_bridge.py 2>/dev/null | awk '{print $1}')"
    current_registry_sha="$(sha256sum /usr/local/lib/flightcore/registry_client.py 2>/dev/null | awk '{print $1}')"
    current_registry_cfg_sha="$(sha256sum /usr/local/sbin/flightcore-registry-config 2>/dev/null | awk '{print $1}')"
    current_manifest_sha="$(sha256sum /usr/local/share/siyi/releases/4.4.0/payload-manifest.json 2>/dev/null | awk '{print $1}')"
    [ "$current_server_sha" = "dd985475e3d8f02e305e6c82d7c742723d612ab2aeae86d8d9d97c8742d3512f" ] || die "4.4.0-rc.3 -> 4.4.0-rc.4 refused: server.py differs ($current_server_sha)."
    [ "$current_daemon_sha" = "6cbbf1fc4fe92d82b47a56732f26323aace26163a4a98007fbc0f9a2125e1476" ] || die "4.4.0-rc.3 -> 4.4.0-rc.4 refused: Ground Station daemon differs ($current_daemon_sha)."
    [ "$current_bridge_sha" = "774fd4ba3d84a6c6fa80a1ca25f6be47857fea1fdad0bfcc15d0087af379a678" ] || die "4.4.0-rc.3 -> 4.4.0-rc.4 refused: button bridge differs ($current_bridge_sha)."
    [ "$current_registry_sha" = "66c7c650425a4273dff561092d38fd5898cb228531a3530f1422909a8712605d" ] || die "4.4.0-rc.3 -> 4.4.0-rc.4 refused: Registry client differs ($current_registry_sha)."
    [ "$current_registry_cfg_sha" = "1cc3d3e25a68a28e10b6cf938e46863856928d8eb971a1f8e0aa3a01e6ed9a9e" ] || die "4.4.0-rc.3 -> 4.4.0-rc.4 refused: Registry config differs ($current_registry_cfg_sha)."
    [ "$current_manifest_sha" = "d1105c824026cc43425790df7977149f5cfcaf966d5e3794e067311bb4a75888" ] || die "4.4.0-rc.3 -> 4.4.0-rc.4 refused: payload manifest differs ($current_manifest_sha)."
    [ -x /usr/local/sbin/siyi-release-fingerprint ] || die "4.4.0-rc.3 -> 4.4.0-rc.4 refused: fingerprint tool missing."
    verify_source_fingerprint_runtime_safe "$TX_DIR/4_4_0_rc_3-source-fingerprint.txt" || die "4.4.0-rc.3 -> 4.4.0-rc.4 refused: canonical source fingerprint failed."
    SIYI_ROUTE="upgrade"; SIYI_SOURCE_RELEASE="4.4.0-rc.3"; SIYI_SOURCE_BUILD="$current_build"; SIYI_SOURCE_VARIANT="4_4_0_rc_3"
    echo "=== Approved compatibility route: exact accepted 4.4.0-rc.3 -> FlightCore 4.4.0 RC4 ==="
  # Retained exact 4.4.0 RC2 compatibility route.
  # Exact immutable 4.4.0 RC2 parent. The semantic marker is normalized to
  # 4.4.0; build, status, managed hashes and canonical fingerprint make this
  # route byte-exact.
  elif [ "$current" = "4.4.0" ] && [ "$current_build" = "20260826.062713-41d1901" ] && [ "$current_status" = accepted ]; then
    current_server_sha="$(sha256sum /home/pi/siyi-webui/server.py 2>/dev/null | awk '{print $1}')"
    current_daemon_sha="$(sha256sum /usr/local/lib/siyi/groundstation/groundstation_daemon.py 2>/dev/null | awk '{print $1}')"
    current_bridge_sha="$(sha256sum /home/pi/siyi_mav_button_bridge.py 2>/dev/null | awk '{print $1}')"
    current_registry_sha="$(sha256sum /usr/local/lib/flightcore/registry_client.py 2>/dev/null | awk '{print $1}')"
    current_registry_cfg_sha="$(sha256sum /usr/local/sbin/flightcore-registry-config 2>/dev/null | awk '{print $1}')"
    current_manifest_sha="$(sha256sum /usr/local/share/siyi/releases/4.4.0/payload-manifest.json 2>/dev/null | awk '{print $1}')"
    [ "$current_server_sha" = "dd985475e3d8f02e305e6c82d7c742723d612ab2aeae86d8d9d97c8742d3512f" ] || die "4.4.0-rc.2 -> 4.4.0-rc.3 refused: server.py differs ($current_server_sha)."
    [ "$current_daemon_sha" = "0dc02b4d8c48e1b95dcdff43649fd89017d27be25d9c237d91caec385550bd09" ] || die "4.4.0-rc.2 -> 4.4.0-rc.3 refused: Ground Station daemon differs ($current_daemon_sha)."
    [ "$current_bridge_sha" = "774fd4ba3d84a6c6fa80a1ca25f6be47857fea1fdad0bfcc15d0087af379a678" ] || die "4.4.0-rc.2 -> 4.4.0-rc.3 refused: button bridge differs ($current_bridge_sha)."
    [ "$current_registry_sha" = "66c7c650425a4273dff561092d38fd5898cb228531a3530f1422909a8712605d" ] || die "4.4.0-rc.2 -> 4.4.0-rc.3 refused: Registry client differs ($current_registry_sha)."
    [ "$current_registry_cfg_sha" = "1cc3d3e25a68a28e10b6cf938e46863856928d8eb971a1f8e0aa3a01e6ed9a9e" ] || die "4.4.0-rc.2 -> 4.4.0-rc.3 refused: Registry config differs ($current_registry_cfg_sha)."
    [ "$current_manifest_sha" = "049e2e13094f6fc1a3d59e291b94a5474d93574e4df409ba452e34030df66faf" ] || die "4.4.0-rc.2 -> 4.4.0-rc.3 refused: payload manifest differs ($current_manifest_sha)."
    [ -x /usr/local/sbin/siyi-release-fingerprint ] || die "4.4.0-rc.2 -> 4.4.0-rc.3 refused: fingerprint tool missing."
    verify_source_fingerprint_runtime_safe "$TX_DIR/4_4_0_rc_2-source-fingerprint.txt" || die "4.4.0-rc.2 -> 4.4.0-rc.3 refused: canonical source fingerprint failed."
    SIYI_ROUTE="upgrade"; SIYI_SOURCE_RELEASE="4.4.0-rc.2"; SIYI_SOURCE_BUILD="$current_build"; SIYI_SOURCE_VARIANT="4_4_0_rc_2"
    echo "=== Approved compatibility route: exact accepted 4.4.0-rc.2 -> FlightCore 4.4.0 RC3 ==="
  # Retained exact 4.4.0 RC1 compatibility route.
  # Exact accepted and successfully flight-tested 4.4.0 RC1 parent. The
  # semantic marker is normalized to 4.4.0; build, status, managed hashes and
  # the installed canonical fingerprint make this route byte-exact.
  elif [ "$current" = "4.4.0" ] && [ "$current_build" = "20260825.185436-44a1c01" ] && [ "$current_status" = accepted ]; then
    current_server_sha="$(sha256sum /home/pi/siyi-webui/server.py 2>/dev/null | awk '{print $1}')"
    current_daemon_sha="$(sha256sum /usr/local/lib/siyi/groundstation/groundstation_daemon.py 2>/dev/null | awk '{print $1}')"
    current_bridge_sha="$(sha256sum /home/pi/siyi_mav_button_bridge.py 2>/dev/null | awk '{print $1}')"
    current_registry_sha="$(sha256sum /usr/local/lib/flightcore/registry_client.py 2>/dev/null | awk '{print $1}')"
    current_registry_cfg_sha="$(sha256sum /usr/local/sbin/flightcore-registry-config 2>/dev/null | awk '{print $1}')"
    current_manifest_sha="$(sha256sum /usr/local/share/siyi/releases/4.4.0/payload-manifest.json 2>/dev/null | awk '{print $1}')"
    [ "$current_server_sha" = "dd985475e3d8f02e305e6c82d7c742723d612ab2aeae86d8d9d97c8742d3512f" ] || die "4.4.0-rc.1 -> 4.4.0-rc.2 refused: server.py differs ($current_server_sha)."
    [ "$current_daemon_sha" = "338ee697feaffa11091781ab559b55de13e809dddbf5651d3f7f6b9bb3c76a5a" ] || die "4.4.0-rc.1 -> 4.4.0-rc.2 refused: Ground Station daemon differs ($current_daemon_sha)."
    [ "$current_bridge_sha" = "774fd4ba3d84a6c6fa80a1ca25f6be47857fea1fdad0bfcc15d0087af379a678" ] || die "4.4.0-rc.1 -> 4.4.0-rc.2 refused: button bridge differs ($current_bridge_sha)."
    [ "$current_registry_sha" = "66c7c650425a4273dff561092d38fd5898cb228531a3530f1422909a8712605d" ] || die "4.4.0-rc.1 -> 4.4.0-rc.2 refused: Registry client differs ($current_registry_sha)."
    [ "$current_registry_cfg_sha" = "1cc3d3e25a68a28e10b6cf938e46863856928d8eb971a1f8e0aa3a01e6ed9a9e" ] || die "4.4.0-rc.1 -> 4.4.0-rc.2 refused: Registry config differs ($current_registry_cfg_sha)."
    [ "$current_manifest_sha" = "a68f9c5662012a7b048f092934d326630a3474ecc7e473b3f19d95041e259880" ] || die "4.4.0-rc.1 -> 4.4.0-rc.2 refused: payload manifest differs ($current_manifest_sha)."
    [ -x /usr/local/sbin/siyi-release-fingerprint ] || die "4.4.0-rc.1 -> 4.4.0-rc.2 refused: fingerprint tool missing."
    verify_source_fingerprint_runtime_safe "$TX_DIR/4_4_0_rc_1-source-fingerprint.txt" || die "4.4.0-rc.1 -> 4.4.0-rc.2 refused: canonical source fingerprint failed."
    SIYI_ROUTE="upgrade"; SIYI_SOURCE_RELEASE="4.4.0-rc.1"; SIYI_SOURCE_BUILD="$current_build"; SIYI_SOURCE_VARIANT="4_4_0_rc_1"
    echo "=== Approved compatibility route: exact accepted 4.4.0-rc.1 -> FlightCore 4.4.0 RC2 ==="
  elif [ "$REPAIR" -eq 1 ] && [ "$current" = "$VERSION" ] && [ "$current_build" = "$BUILD_ID" ]; then
    SIYI_ROUTE="repair"; SIYI_SOURCE_RELEASE="$VERSION"; SIYI_SOURCE_BUILD="$current_build"; SIYI_SOURCE_VARIANT="same_version_repair"
  elif [ "$current" = "$VERSION" ] && [ "$current_build" = "$BUILD_ID" ] && { [ "$current_status" = accepted ] || [ "$current_status" = core_accepted_hardware_pending ]; }; then
    die "$VERSION/$BUILD_ID is already installed. Use --repair for a verified reinstall."
  elif [ "$current" = "$VERSION" ] && [ "$(interrupted_target_evidence)" = 1 ]; then
    SIYI_ROUTE="recovery"; SIYI_SOURCE_RELEASE="$VERSION"; SIYI_SOURCE_BUILD="$current_build"; SIYI_SOURCE_VARIANT="interrupted_target_recovery"
  else
    die "Upgrade from ${current:-invalid-marker}/${current_build:-unknown} is unsupported by 4.4.0-rc.8. Authorized compatibility sources include exact accepted 4.4.0 RC7, RC6, RC4, RC3, RC2, RC1, RC41, RC38, RC36, Registry-required RC6 and retained clean historical routes. A modified/hotfixed source must first be restored to exact clean bytes."
  fi
elif [ -e /home/pi/siyi-webui/server.py ] || sudo systemctl list-unit-files 'siyi-*.service' --no-legend 2>/dev/null | grep -q .; then
  [ "$(interrupted_target_evidence)" = 1 ] || die "An unversioned existing FlightCore installation was detected. Fresh install requires a freshly flashed OS."
  SIYI_ROUTE="recovery";SIYI_SOURCE_RELEASE="$VERSION";SIYI_SOURCE_VARIANT="unversioned_target_recovery"
fi
export SIYI_ROUTE SIYI_SOURCE_RELEASE SIYI_SOURCE_BUILD SIYI_SOURCE_VARIANT

# FLIGHTCORE_4_3_0_RC2_FRESH_INSTALL_WEBUI_ROUTE_CONFIRM_V1
if [ "$SIYI_ROUTE" = fresh ] && [ "${SIYI_FRESH_INSTALL_UI:-0}" = "1" ]; then
  siyi_write_fresh_install_ui_state 5 "Preparing installer" starting ""
elif [ "$SIYI_ROUTE" != fresh ] && [ "${SIYI_FRESH_INSTALL_UI:-0}" = "1" ]; then
  kill "${SIYI_FRESH_INSTALL_UI_PID:-}" >/dev/null 2>&1 || true
  SIYI_FRESH_INSTALL_UI=0
fi

echo "$VERSION" >"$TX_DIR/target-release"
echo "$SIYI_ROUTE" >"$TX_DIR/install-route"
echo "$SIYI_SOURCE_RELEASE" >"$TX_DIR/source-release"
echo "$SIYI_SOURCE_BUILD" >"$TX_DIR/source-build"
echo "$SIYI_SOURCE_VARIANT" >"$TX_DIR/source-variant"
echo "$current_status" >"$TX_DIR/source-status"
echo "$PRESERVE_CSV" >"$TX_DIR/preserve-groups"
echo "$REMEMBER_SELECTION" >"$TX_DIR/preserve-remember"
if [ -n "$SIYI_SOURCE_RELEASE" ] && [ -d "/usr/local/share/siyi/releases/$SIYI_SOURCE_RELEASE" ]; then
  rm -rf "$TX_DIR/source-release-tree.partial" "$TX_DIR/source-release-tree"
  cp -a "/usr/local/share/siyi/releases/$SIYI_SOURCE_RELEASE" "$TX_DIR/source-release-tree.partial"
  mv "$TX_DIR/source-release-tree.partial" "$TX_DIR/source-release-tree"
  touch "$TX_DIR/source-release-tree.ready"
fi
sudo install -o root -g root -m 0644 "$MANIFEST" "$TX_DIR/target-payload-manifest.json"
sudo install -o root -g root -m 0644 "$MANIFEST" "$TX_DIR/payload-manifest.json"
sudo install -o root -g root -m 0644 "$SCRIPT_DIR/release-metadata.json" "$TX_DIR/release-metadata.json"
sudo install -o root -g root -m 0700 "$SCRIPT_DIR/health-check.sh" "$TX_DIR/health-check.sh"

[ -f "$SCRIPT_DIR/transaction-backup.py" ] || die "Transaction backup helper is missing."
[ -f "$SCRIPT_DIR/transaction-restore.py" ] || die "Transaction restore helper is missing."
[ -f "$PAYLOAD/usr/local/sbin/siyi-rollback-transaction" ] || die "Rollback engine is missing from the target payload."
install -o root -g root -m 0600 "$SCRIPT_DIR/transaction-restore.py" "$TX_DIR/transaction-restore.py"
install -o root -g root -m 0700 "$PAYLOAD/usr/local/sbin/siyi-rollback-transaction" "$TX_DIR/siyi-rollback-transaction"
printf '%s  %s\n' "$(sha256sum "$TX_DIR/transaction-restore.py" | awk '{print $1}')" transaction-restore.py >"$TX_DIR/recovery-helper.sha256"
printf '%s  %s\n' "$(sha256sum "$TX_DIR/siyi-rollback-transaction" | awk '{print $1}')" siyi-rollback-transaction >>"$TX_DIR/recovery-helper.sha256"
printf '%s  %s\n' "$(sha256sum "$TX_DIR/payload-manifest.json" | awk '{print $1}')" payload-manifest.json >>"$TX_DIR/recovery-helper.sha256"
printf '%s  %s\n' "$(sha256sum "$TX_DIR/release-metadata.json" | awk '{print $1}')" release-metadata.json >>"$TX_DIR/recovery-helper.sha256"
printf '%s  %s\n' "$(sha256sum "$TX_DIR/health-check.sh" | awk '{print $1}')" health-check.sh >>"$TX_DIR/recovery-helper.sha256"
python3 - "$PAYLOAD" "$MANIFEST" <<'PYVERIFY'
import hashlib,json,os,sys
root,manifest=sys.argv[1:]
data=json.load(open(manifest,encoding='utf-8'))
for item in data['files']:
    p=os.path.join(root,item['path'].lstrip('/'))
    if item['type']=='directory':
        if not os.path.isdir(p): raise SystemExit('missing directory '+item['path'])
    elif item['type']=='symlink':
        if not os.path.islink(p): raise SystemExit('missing symlink '+item['path'])
        if hashlib.sha256(os.readlink(p).encode()).hexdigest()!=item['sha256']: raise SystemExit('symlink checksum mismatch '+item['path'])
    else:
        if not os.path.isfile(p): raise SystemExit('missing file '+item['path'])
        if hashlib.sha256(open(p,'rb').read()).hexdigest()!=item['sha256']: raise SystemExit('checksum mismatch '+item['path'])
PYVERIFY

# SIYI_4_2_1_FRESH_DEPENDENCY_BASELINE_V1
# Fresh-OS dependencies are prepared before the FlightCore transaction baseline is
# captured. Package upgrades explicitly required by the dependency solver are
# valid OS preparation, not target-deployment drift. A later FlightCore rollback
# therefore returns to this prepared clean-OS baseline rather than trying to
# downgrade repository packages that may no longer be available.
progress 10 "Validating operating-system dependencies"
export DEBIAN_FRONTEND=noninteractive APT_LISTCHANGES_FRONTEND=none
mapfile -t packages < <(grep -Ev '^($|#)' "$SCRIPT_DIR/apt-packages.txt")
if [ "$SIYI_ROUTE" = upgrade ] || [ "$SIYI_ROUTE" = repair ]; then
  missing=()
  for package in "${packages[@]}" zerotier-one; do dpkg-query -W -f='${db:Status-Abbrev}' "$package" 2>/dev/null | grep -q '^ii ' || missing+=("$package"); done
  [ "${#missing[@]}" -eq 0 ] || die "Approved-source dependency drift detected; missing packages: ${missing[*]}"
else
  FRESH_DEPENDENCY_PHASE=1
  dpkg-query -W -f='${binary:Package}\t${Version}\n' 2>/dev/null | sort -u >"$TX_DIR/packages-pre-provision.tsv"
  sudo install -D -o root -g root -m 0644 "$PAYLOAD/usr/share/keyrings/zerotier-debian-package-key.gpg" /usr/share/keyrings/zerotier-debian-package-key.gpg
  sudo install -D -o root -g root -m 0644 "$PAYLOAD/etc/apt/sources.list.d/zerotier.list" /etc/apt/sources.list.d/zerotier.list
  # FLIGHTCORE_4_3_0_RC13_ZEROTIER_FRESH_APT_RELIABILITY_V1
  # A fresh public install must tolerate a transient repository-index race, but
  # it must never continue into FlightCore deployment without proving that APT
  # can resolve the exact ZeroTier package. Recovery is bounded and deletes
  # only the cached list files owned by the configured ZeroTier repository.
  zerotier_apt_evidence() {
    local out="$TX_DIR/zerotier-apt-evidence.txt"
    {
      echo "captured_at=$(date -Is)"
      echo "architecture=$(dpkg --print-architecture 2>/dev/null || true)"
      echo "foreign_architectures=$(dpkg --print-foreign-architectures 2>/dev/null | tr '\n' ' ')"
      echo "source=$(tr -d '\r' </etc/apt/sources.list.d/zerotier.list 2>/dev/null || true)"
      echo "key_fingerprints:"
      gpg --show-keys --with-colons /usr/share/keyrings/zerotier-debian-package-key.gpg 2>/dev/null | awk -F: '$1=="fpr"{print $10}' || true
      echo "apt_policy:"
      apt-cache policy zerotier-one 2>&1 || true
      echo "zerotier_list_files:"
      find /var/lib/apt/lists -maxdepth 1 -type f -name 'download.zerotier.com_debian_trixie_*' -printf '%f %s bytes\n' 2>/dev/null | sort || true
    } >"$out"
  }
  zerotier_apt_update() {
    local attempt delay
    for attempt in 1 2 3; do
      if run_logged "Updating package indexes (attempt $attempt/3)" sudo -E apt-get \
          -o Dpkg::Use-Pty=0 -o APT::Color=0 -o Acquire::Retries=3 \
          -o Acquire::https::Timeout=20 -o Acquire::http::Timeout=20 update; then
        return 0
      fi
      delay=$((attempt * 3))
      [ "$attempt" -ge 3 ] || sleep "$delay"
    done
    return 1
  }
  zerotier_apt_resolves() {
    local candidate
    candidate="$(apt-cache policy zerotier-one 2>/dev/null | awk '/Candidate:/{print $2;exit}')"
    [ -n "$candidate" ] && [ "$candidate" != "(none)" ] && apt-cache show zerotier-one >/dev/null 2>&1
  }

  zerotier_apt_update || {
    zerotier_apt_evidence
    die "Fresh dependency preparation failed: package-index update did not succeed after 3 bounded attempts. Evidence: $TX_DIR/zerotier-apt-evidence.txt"
  }
  if ! zerotier_apt_resolves; then
    zerotier_apt_evidence
    sudo find /var/lib/apt/lists -maxdepth 1 -type f -name 'download.zerotier.com_debian_trixie_*' -delete
    zerotier_apt_update || {
      zerotier_apt_evidence
      die "Fresh ZeroTier repository recovery failed during package-index refresh. Evidence: $TX_DIR/zerotier-apt-evidence.txt"
    }
  fi
  zerotier_apt_resolves || {
    zerotier_apt_evidence
    die "Fresh dependency preparation failed: APT cannot resolve zerotier-one after targeted recovery. Evidence: $TX_DIR/zerotier-apt-evidence.txt"
  }
  zerotier_apt_evidence
  sudo -E apt-get -o Dpkg::Use-Pty=0 -o APT::Color=0 -s --no-upgrade install -y --no-install-recommends "${packages[@]}" zerotier-one >"$TX_DIR/apt-install-simulation.txt"
  python3 - "$TX_DIR/packages-pre-provision.tsv" "$TX_DIR/apt-install-simulation.txt" "$TX_DIR/apt-provision-plan.json" <<'PYAPTPLAN'
import json,re,sys
before,simulation,out=sys.argv[1:]
installed={}
for line in open(before,encoding='utf-8',errors='replace'):
    parts=line.rstrip('\n').split('\t',1)
    if len(parts)==2: installed[parts[0].split(':',1)[0]]=parts[1]
planned=[]
for line in open(simulation,encoding='utf-8',errors='replace'):
    if not line.startswith('Inst '): continue
    package=line.split()[1].split(':',1)[0]
    if package not in planned: planned.append(package)
json.dump({'schema_version':1,'installed_before':len(installed),'planned_package_actions':planned},open(out,'w'),indent=2,sort_keys=True)
open(out,'a').write('\n')
PYAPTPLAN
  run_logged "Installing required operating-system packages" sudo -E apt-get -o Dpkg::Use-Pty=0 -o APT::Color=0 --no-upgrade install -y --no-install-recommends "${packages[@]}"
  progress 25 "Installing ZeroTier"
  run_logged "Installing ZeroTier" sudo -E apt-get -o Dpkg::Use-Pty=0 -o APT::Color=0 --no-upgrade install -y --no-install-recommends zerotier-one
  dpkg-query -W -f='${binary:Package}\t${Version}\n' 2>/dev/null | sort -u >"$TX_DIR/packages-provisioned.tsv"
  python3 - "$TX_DIR/packages-pre-provision.tsv" "$TX_DIR/packages-provisioned.tsv" "$TX_DIR/apt-provision-plan.json" "$TX_DIR/apt-provision-result.json" <<'PYPACKAGES'
import json,sys
before,after,plan_path,out=sys.argv[1:]
def read(p):
    d={}
    for line in open(p,encoding='utf-8',errors='replace'):
        parts=line.rstrip('\n').split('\t',1)
        if len(parts)==2:d[parts[0]]=parts[1]
    return d
b,a=read(before),read(after)
new=sorted(set(a)-set(b)); removed=sorted(set(b)-set(a))
upgraded=sorted(({'package':p,'before':b[p],'after':a[p]} for p in b if p in a and b[p]!=a[p]),key=lambda x:x['package'])
planned=set(json.load(open(plan_path,encoding='utf-8'))['planned_package_actions'])
unplanned=sorted(({p.split(':',1)[0] for p in new}|{x['package'].split(':',1)[0] for x in upgraded})-planned)
result={'schema_version':1,'new_packages':new,'upgraded_packages':upgraded,'removed_packages':removed,'unplanned_changes':unplanned}
json.dump(result,open(out,'w'),indent=2,sort_keys=True); open(out,'a').write('\n')
if removed: raise SystemExit('dependency provisioning removed pre-existing packages: '+','.join(removed))
if unplanned: raise SystemExit('dependency provisioning made unplanned package changes: '+','.join(unplanned))
PYPACKAGES
  for package in "${packages[@]}" zerotier-one; do dpkg-query -W -f='${db:Status-Abbrev}' "$package" 2>/dev/null | grep -q '^ii ' || die "Dependency provisioning incomplete: $package"; done
fi
# This is the package baseline for every subsequent FlightCore mutation and rollback.
dpkg-query -W -f='${binary:Package}\t${Version}\n' 2>/dev/null | sort -u >"$TX_DIR/packages-before.tsv"
run_logged "Verifying MAVLink Router systemd build metadata" pkg-config --exists systemd
FRESH_DEPENDENCY_PHASE=0

 : >"$TX_DIR/managed-active-units.txt"
: >"$TX_DIR/managed-enabled-units.txt"
: >"$TX_DIR/unit-state.tsv"
STATE_TRACKED_UNITS=("${SIYI_MANAGED_UNITS[@]}" NetworkManager.service zerotier-one.service serial-getty@serial0.service serial-getty@ttyS0.service serial-getty@ttyAMA0.service)
for unit in "${SIYI_MANAGED_UNITS[@]}"; do
  sudo systemctl is-active --quiet "$unit" 2>/dev/null && echo "$unit" >>"$TX_DIR/managed-active-units.txt" || true
  sudo systemctl is-enabled --quiet "$unit" 2>/dev/null && echo "$unit" >>"$TX_DIR/managed-enabled-units.txt" || true
done
for unit in "${STATE_TRACKED_UNITS[@]}"; do
  enabled="$(sudo systemctl is-enabled "$unit" 2>/dev/null || true)"; [ -n "$enabled" ] || enabled=unknown
  active="$(sudo systemctl is-active "$unit" 2>/dev/null || true)"; [ -n "$active" ] || active=unknown
  case "$enabled" in enabled|enabled-runtime|disabled|masked|masked-runtime|static|indirect|generated|transient|alias|not-found) ;; *) die "Source unit state cannot be restored exactly: $unit enabled=$enabled";; esac
  case "$active" in active|inactive) ;; *) die "Source unit state cannot be restored exactly: $unit active=$active";; esac
  printf '%s\t%s\t%s\n' "$unit" "$enabled" "$active" >>"$TX_DIR/unit-state.tsv"
done
UNIT_STATE_READY=1
SERVICE_STATE_READY=1
if [ "${SIYI_WEBUI_UPGRADE:-0}" = "1" ]; then
  SIYI_STOP_UNITS=()
  for unit in "${SIYI_MANAGED_UNITS[@]}"; do [ "$unit" = "siyi-webui.service" ] || SIYI_STOP_UNITS+=("$unit"); done
  sudo systemctl stop "${SIYI_STOP_UNITS[@]}" >/dev/null 2>&1 || true
else
  sudo systemctl stop "${SIYI_MANAGED_UNITS[@]}" >/dev/null 2>&1 || true
fi
sudo python3 "$SCRIPT_DIR/transaction-backup.py" "$MANIFEST" "$TX_DIR/backup-index.json" "$TX_DIR/backup-root"
SNAPSHOT_READY=1
sudo install -d -o root -g root -m 0700 "$TX_DIR/preserve-root"
sudo python3 - "$SCRIPT_DIR/preservation-model.json" "$TX_DIR/preserve-root" "$TX_DIR/preserve-plan.json" "$SIYI_ROUTE" "$PRESERVE_CSV" <<'PYPRESERVESNAPSHOT'
import hashlib,json,os,shutil,stat,sys
model_path,backup_root,plan_path,route,csv=sys.argv[1:]
model=json.load(open(model_path,encoding='utf-8'))
selected=[x for x in csv.split(',') if x]
unknown=set(selected)-set(model.get('legacy_accepted_groups',[]))
if unknown: raise SystemExit('unknown legacy preservation groups: '+','.join(sorted(unknown)))
paths=list(model.get('mandatory_preserve_paths',[])) if route!='fresh' else []
directories=list(model.get('mandatory_preserve_directories',[])) if route!='fresh' else []
entries=[]
os.makedirs(backup_root,exist_ok=True)
for path in dict.fromkeys(paths):
  if not os.path.lexists(path): continue
  st=os.lstat(path); dst=os.path.join(backup_root,path.lstrip('/')); os.makedirs(os.path.dirname(dst),exist_ok=True)
  if stat.S_ISLNK(st.st_mode): os.symlink(os.readlink(path),dst); kind='symlink'; digest=hashlib.sha256(os.readlink(path).encode()).hexdigest()
  elif stat.S_ISREG(st.st_mode): shutil.copy2(path,dst,follow_symlinks=False); kind='file'; digest=hashlib.sha256(open(path,'rb').read()).hexdigest()
  else: raise SystemExit('unsupported preserved path type: '+path)
  entries.append({'path':path,'type':kind,'uid':st.st_uid,'gid':st.st_gid,'mode':stat.S_IMODE(st.st_mode),'sha256':digest})
def tree_digest(path):
  h=hashlib.sha256(); members=[]
  for root,dirs,files in os.walk(path,topdown=True,followlinks=False):
    dirs.sort(); files.sort()
    for name in ['.']+dirs+files:
      item=root if name=='.' else os.path.join(root,name)
      rel=os.path.relpath(item,path); st=os.lstat(item)
      if stat.S_ISLNK(st.st_mode): kind='symlink'; payload=os.readlink(item).encode()
      elif stat.S_ISDIR(st.st_mode): kind='directory'; payload=b''
      elif stat.S_ISREG(st.st_mode): kind='file'; payload=open(item,'rb').read()
      else: raise SystemExit('unsupported preserved directory member: '+item)
      h.update(rel.encode()+b'\0'+kind.encode()+b'\0'+payload+b'\0')
      members.append({'relative':rel,'type':kind,'uid':st.st_uid,'gid':st.st_gid,'mode':stat.S_IMODE(st.st_mode)})
  return h.hexdigest(),members
for path in dict.fromkeys(directories):
  if not os.path.isdir(path) or os.path.islink(path): continue
  dst=os.path.join(backup_root,path.lstrip('/')); os.makedirs(os.path.dirname(dst),exist_ok=True)
  shutil.copytree(path,dst,symlinks=True,copy_function=shutil.copy2)
  digest,members=tree_digest(path)
  entries.append({'path':path,'type':'directory','uid':os.lstat(path).st_uid,'gid':os.lstat(path).st_gid,'mode':stat.S_IMODE(os.lstat(path).st_mode),'sha256':digest,'members':members})
plan={'schema_version':2,'route':route,'policy':'mandatory_all_user_configuration','legacy_requested_groups':selected,'files':entries}
json.dump(plan,open(plan_path,'w'),indent=2,sort_keys=True); open(plan_path,'a').write('\n')
PYPRESERVESNAPSHOT



progress 35 "Installing FlightCore configuration"
if id pi >/dev/null 2>&1; then
  touch "$TX_DIR/pi-user-existed"
  id -Gn pi | tr ' ' '\n' | grep -vx "$(id -gn pi)" | sort -u >"$TX_DIR/pi-supplementary-groups-before" || true
fi
if ! getent group pi >/dev/null 2>&1; then groupadd pi; touch "$TX_DIR/pi-group-created"; fi
if ! id pi >/dev/null 2>&1; then useradd -m -g pi -s /bin/bash pi; touch "$TX_DIR/pi-user-created"; fi
for group in dialout input video render netdev; do getent group "$group" >/dev/null && usermod -a -G "$group" pi; done
touch "$TX_DIR/target-release-tree-mutated"
TARGET_RELEASE_TREE_MUTATED=1
python3 - "$PAYLOAD" "$MANIFEST" <<'PYDEPLOY'
import grp,json,os,pwd,shutil,stat,sys,tempfile
root,manifest=sys.argv[1:]
data=json.load(open(manifest,encoding='utf-8'))
for item in sorted(data['files'],key=lambda x:(x['type']!='directory',x['path'].count('/'),x['path'])):
    src=os.path.join(root,item['path'].lstrip('/')); dst=item['path']
    if dst in {'/etc/siyi/release_version','/etc/siyi/release_build','/etc/siyi/release_status'}: continue
    if dst == '/var/lib/siyi-upgrade/state.json' and os.path.lexists(dst): continue
    if item['type']=='directory': os.makedirs(dst,exist_ok=True)
    elif item['type']=='symlink':
        os.makedirs(os.path.dirname(dst),exist_ok=True)
        if os.path.lexists(dst):
            if os.path.isdir(dst) and not os.path.islink(dst): shutil.rmtree(dst)
            else: os.unlink(dst)
        os.symlink(os.readlink(src),dst)
    else:
        os.makedirs(os.path.dirname(dst),exist_ok=True)
        fd,tmp=tempfile.mkstemp(prefix='.siyi421.',dir=os.path.dirname(dst)); os.close(fd)
        shutil.copy2(src,tmp,follow_symlinks=False); os.replace(tmp,dst)
    uid=pwd.getpwnam(item['owner']).pw_uid; gid=grp.getgrnam(item['group']).gr_gid
    if item['type']=='symlink': os.lchown(dst,uid,gid)
    else:
        os.chown(dst,uid,gid)
        os.chmod(dst,int(item['mode'],8))
for p in data.get('obsolete_paths',[]):
    if os.path.isdir(p) and not os.path.islink(p): shutil.rmtree(p)
    elif os.path.lexists(p): os.unlink(p)
    if os.path.lexists(p): raise SystemExit('obsolete path remained '+p)
PYDEPLOY
# SIYI_4_2_1_PARAM_IMPORT_STORAGE_GATE_V3
# Directory modes are declarative target state. `install -d -m` does not reliably
# remove pre-existing special mode bits, so creation, ownership and chmod are
# deliberately separate operations and the exact state is verified afterwards.
sudo install -d /var/backups /var/lib/siyi-param-import /var/lib/siyi-param-import/sessions /var/backups/siyi-param-import
sudo chown root:root /var/backups
sudo chmod a-s,u=rwx,g=rx,o=rx /var/backups
for _siyi_dir in /var/lib/siyi-param-import /var/lib/siyi-param-import/sessions /var/backups/siyi-param-import; do
  sudo chown pi:pi "$_siyi_dir"
  sudo chmod a-s,u=rwx,g=rwx,o=rx "$_siyi_dir"
  [ "$(stat -c '%U:%G:%a' "$_siyi_dir")" = "pi:pi:775" ] || die "Parameter import directory ownership/mode failed: $_siyi_dir"
  sudo -u pi test -w "$_siyi_dir" || die "Parameter import directory is not writable by pi: $_siyi_dir"
done
sudo install -d -o pi -g pi -m 0775 /home/pi/.config/siyi /var/lib/siyi-user-config/groundstation
sudo install -d -o root -g pi -m 0775 /var/lib/siyi-upgrade /var/backups/siyi-upgrade /var/lib/siyi-installer
for dst in /home/pi/.config/siyi/telemetry_canvas.json /var/lib/siyi-user-config/groundstation/telemetry_canvas.json; do
  [ -e "$dst" ] || sudo install -o pi -g pi -m 0664 /usr/local/share/siyi/defaults/telemetry_canvas.json "$dst"
done
sudo install -o root -g pi -m 0664 /usr/local/share/siyi/defaults/upgrade_preserve_preferences.json /var/lib/siyi-upgrade/preserve_preferences.json
# FLIGHTCORE_4_3_0_RC1_DEVICE_REGISTRY_AUTO_ENROLL_INSTALL_V1
# Generate/preserve only the permanent Unit ID before acceptance. Registry
# config migration, credential enrollment and first check-in are deferred until
# the transaction has been accepted after reboot. That keeps failed upgrades
# byte-clean with respect to existing RC13 registry configuration/credentials.
[ -e /etc/flightcore/device-id ] || touch "$TX_DIR/flightcore-device-id-created"
[ -d /var/lib/flightcore ] || touch "$TX_DIR/flightcore-registry-state-dir-created"
[ -d /var/lib/flightcore/flight-logs ] || touch "$TX_DIR/flightcore-flight-logs-dir-created"
sudo /usr/local/lib/flightcore/registry_client.py --ensure-id >/dev/null
sudo install -d -o root -g root -m 0755 /var/lib/flightcore
sudo install -d -o pi -g pi -m 0755 /var/lib/flightcore/flight-logs
sudo systemctl disable --now flightcore-registry.service flightcore-registry.timer >/dev/null 2>&1 || true
sudo python3 - "$TX_DIR/preserve-root" "$TX_DIR/preserve-plan.json" <<'PYPRESERVERESTORE'
import hashlib,json,os,shutil,stat,sys,tempfile
backup_root,plan_path=sys.argv[1:]
plan=json.load(open(plan_path,encoding='utf-8'))
def tree_digest(path):
  h=hashlib.sha256()
  for root,dirs,files in os.walk(path,topdown=True,followlinks=False):
    dirs.sort(); files.sort()
    for name in ['.']+dirs+files:
      item=root if name=='.' else os.path.join(root,name); rel=os.path.relpath(item,path); st=os.lstat(item)
      if stat.S_ISLNK(st.st_mode): kind='symlink'; payload=os.readlink(item).encode()
      elif stat.S_ISDIR(st.st_mode): kind='directory'; payload=b''
      elif stat.S_ISREG(st.st_mode): kind='file'; payload=open(item,'rb').read()
      else: raise SystemExit('unsupported restored directory member: '+item)
      h.update(rel.encode()+b'\0'+kind.encode()+b'\0'+payload+b'\0')
  return h.hexdigest()
for item in plan.get('files',[]):
  path=item['path']; src=os.path.join(backup_root,path.lstrip('/')); os.makedirs(os.path.dirname(path),exist_ok=True)
  if os.path.isdir(path) and not os.path.islink(path): shutil.rmtree(path)
  elif os.path.lexists(path): os.unlink(path)
  if item['type']=='directory':
    shutil.copytree(src,path,symlinks=True,copy_function=shutil.copy2)
    for member in sorted(item.get('members',[]),key=lambda x:x['relative'].count('/'),reverse=True):
      target=path if member['relative']=='.' else os.path.join(path,member['relative'])
      if member['type']=='symlink': os.lchown(target,int(member['uid']),int(member['gid']))
      else: os.chmod(target,int(member['mode'])); os.chown(target,int(member['uid']),int(member['gid']))
    digest=tree_digest(path)
  # FLIGHTCORE_4_3_0_RC17_PRESERVED_TOP_LEVEL_SYMLINK_OWNERSHIP_V1
  elif item['type']=='symlink':
    os.symlink(os.readlink(src),path)
    os.lchown(path,int(item['uid']),int(item['gid']))
    digest=hashlib.sha256(os.readlink(path).encode()).hexdigest()
  else:
    fd,tmp=tempfile.mkstemp(prefix='.siyi-preserve.',dir=os.path.dirname(path)); os.close(fd)
    shutil.copy2(src,tmp,follow_symlinks=False); os.replace(tmp,path); digest=hashlib.sha256(open(path,'rb').read()).hexdigest()
  if digest!=item['sha256']: raise SystemExit('preservation checksum mismatch: '+path)
  if item['type']!='directory' and not os.path.islink(path): os.chmod(path,int(item['mode'])); os.chown(path,int(item['uid']),int(item['gid']))
PYPRESERVERESTORE

# FLIGHTCORE_4_3_0_RC13_CONFIGURATION_SCHEMA_MIGRATION_V2
# Migrations run only after the mandatory byte-for-byte preservation restore.
# They are idempotent, retain all recognized user values, and record only file
# names/status (never credentials or secret values) in the migration receipt.
sudo python3 - "$SIYI_ROUTE" <<'PYCONFIGMIGRATE'
import grp,json,os,pwd,tempfile,time,sys
route=sys.argv[1]; changed=[]
def load(path):
  try:
    value=json.load(open(path,encoding='utf-8'))
    return value if isinstance(value,dict) else None
  except FileNotFoundError:return None
  except Exception as exc: raise SystemExit(f'configuration migration refused invalid JSON {path}: {exc}')
def write(path,value):
  st=os.stat(path); fd,tmp=tempfile.mkstemp(prefix='.flightcore-migrate.',dir=os.path.dirname(path),text=True)
  with os.fdopen(fd,'w',encoding='utf-8') as handle: json.dump(value,handle,indent=2,sort_keys=True); handle.write('\n')
  os.chmod(tmp,st.st_mode & 0o7777); os.chown(tmp,st.st_uid,st.st_gid); os.replace(tmp,path); changed.append(path)
def migrate(path,fn):
  value=load(path)
  if value is None:return
  target=fn(dict(value))
  if target!=value:write(path,target)
def schema2(value):value['schema_version']=2;return value
def flaps(value):
  value.pop('current_position',None); value['schema_version']=2
  value.setdefault('enabled',False); value.setdefault('left_servo',9); value.setdefault('right_servo',10)
  return value
def legacy_optional(value):
  # Existing files retain the RC12 meaning of an absent enabled field. Only a
  # genuine fresh install receives RC13's safe-off payload defaults.
  value['schema_version']=2; value.setdefault('enabled',True); return value
for path,fn in (
  ('/etc/siyi/flaps.json',flaps),
  ('/etc/siyi/video_source.json',schema2),
  ('/home/pi/siyi-config.json',schema2),
  ('/var/lib/siyi-user-config/groundstation/battery_settings.json',legacy_optional),
  ('/home/pi/.config/siyi/battery_settings.json',legacy_optional),
  ('/var/lib/siyi-user-config/groundstation/turn_home.json',legacy_optional),
  ('/var/lib/siyi-user-config/groundstation/lte_health.json',legacy_optional),
  ('/var/lib/siyi-user-config/groundstation/airspeed_status.json',schema2),
  ('/var/lib/siyi-user-config/groundstation/telemetry_sync_snapshot.json',schema2),
):migrate(path,fn)
receipt={'schema_version':2,'route':route,'policy':'mandatory_all_user_configuration','changed_files':changed,'completed_at':time.strftime('%Y-%m-%dT%H:%M:%S%z')}
path='/var/lib/siyi-upgrade/config-migration-receipt.json';os.makedirs(os.path.dirname(path),exist_ok=True)
fd,tmp=tempfile.mkstemp(prefix='.config-migration.',dir=os.path.dirname(path),text=True)
with os.fdopen(fd,'w',encoding='utf-8') as handle:json.dump(receipt,handle,indent=2,sort_keys=True);handle.write('\n')
os.chmod(tmp,0o640);os.chown(tmp,0,grp.getgrnam('pi').gr_gid);os.replace(tmp,path)
PYCONFIGMIGRATE
sudo chown pi:pi /home/pi/siyi-config.json 2>/dev/null || true
sudo chmod 0664 /home/pi/siyi-config.json 2>/dev/null || true
# mediamtx.yml is generated runtime state. Rebuild it from the target default or
# the preserved /etc/siyi/video_source.json after every route.
/usr/local/sbin/siyi-video-source-control configure
[ "$(stat -c '%U:%G:%a' /usr/local/etc/mediamtx/mediamtx.yml 2>/dev/null || true)" = "root:root:600" ] || die "Generated MediaMTX configuration ownership/mode verification failed."
/usr/local/sbin/siyi-release-fingerprint --manifest "$MANIFEST" --clean-managed-extras --clean-managed-extras-only --allow-release "$SIYI_SOURCE_RELEASE" >/dev/null
# SIYI_4_2_1_GROUP_PRESERVATION_MODEL_V1

progress 45 "Installing Web UI"
test -f /home/pi/siyi-webui/server.py
test -f /home/pi/siyi-webui/wifi_passwords.json
sudo chown -R pi:pi /home/pi/siyi-webui /home/pi/siyi-joystick

progress 50 "Configuring camera Ethernet"
if ip link show eth0 >/dev/null 2>&1; then
  if nmcli -t -f NAME connection show --active 2>/dev/null | grep -Fxq cam-eth0; then touch "$TX_DIR/cam-profile-was-active"; fi
  existing_cam="$(nmcli -t -f NAME connection show 2>/dev/null | awk '$0=="cam-eth0"{print;exit}')"
  if [ -z "$existing_cam" ]; then
    sudo nmcli connection add type ethernet ifname eth0 con-name cam-eth0 >/dev/null
    CAM_PROFILE_CREATED=1; touch "$TX_DIR/cam-profile-created"
  else
    : >"$TX_DIR/cam-profile-state.tsv"
    for _siyi_nm_key in connection.interface-name connection.autoconnect connection.autoconnect-priority ipv4.method ipv4.addresses ipv4.gateway ipv4.dns ipv4.never-default ipv6.method; do
      printf '%s\t%s\n' "$_siyi_nm_key" "$(nmcli -g "$_siyi_nm_key" connection show cam-eth0 2>/dev/null || true)" >>"$TX_DIR/cam-profile-state.tsv"
    done
  fi
  camera_eth_ip="$(python3 - /home/pi/siyi-config.json <<'PYCAMERAIP'
import json,sys
try: value=str(json.load(open(sys.argv[1],encoding='utf-8')).get('camera_eth_ip','')).strip()
except Exception: value=''
print(value or '192.168.144.20/24')
PYCAMERAIP
)"
  [[ "$camera_eth_ip" =~ ^[0-9a-fA-F:.]+/[0-9]+$ ]] || die "Invalid camera_eth_ip in /home/pi/siyi-config.json: $camera_eth_ip"
  sudo nmcli connection modify cam-eth0 connection.interface-name eth0 connection.autoconnect yes connection.autoconnect-priority 100 ipv4.method manual ipv4.addresses "$camera_eth_ip" ipv4.gateway "" ipv4.dns "" ipv4.never-default yes ipv6.method disabled
fi

progress 58 "Preparing Python environment"
sudo rm -rf /home/pi/siyi-bridge-venv.new
run_logged "Creating Python virtual environment" python3 -m venv /home/pi/siyi-bridge-venv.new
run_logged "Updating Python package installer" env -u PIP_INDEX_URL -u PIP_EXTRA_INDEX_URL -u PIP_FIND_LINKS PIP_CONFIG_FILE=/dev/null /home/pi/siyi-bridge-venv.new/bin/pip install --disable-pip-version-check --no-cache-dir --index-url https://pypi.org/simple --retries 2 --timeout 12 --upgrade pip
run_logged "Installing pinned Python dependencies" env -u PIP_INDEX_URL -u PIP_EXTRA_INDEX_URL -u PIP_FIND_LINKS PIP_CONFIG_FILE=/dev/null /home/pi/siyi-bridge-venv.new/bin/pip install --disable-pip-version-check --no-cache-dir --index-url https://pypi.org/simple --retries 2 --timeout 12 --requirement "$SCRIPT_DIR/requirements.txt"
run_logged "Checking Python dependency consistency" /home/pi/siyi-bridge-venv.new/bin/pip check
/home/pi/siyi-bridge-venv.new/bin/python - <<'PYIMPORT'
from pymavlink import mavutil
import fastcrc,future,lxml,numpy,serial,requests,psutil,aiohttp,websockets,yaml
PYIMPORT
if [ "${SIYI_WEBUI_UPGRADE:-0}" != "1" ]; then
  if [ -d /home/pi/siyi-bridge-venv ]; then sudo mv /home/pi/siyi-bridge-venv "$TX_DIR/siyi-bridge-venv.previous"; fi
  sudo mv /home/pi/siyi-bridge-venv.new /home/pi/siyi-bridge-venv
  VENV_SWAPPED=1
  touch "$TX_DIR/venv-swapped"
  sudo chown -R pi:pi /home/pi/siyi-bridge-venv
fi

progress 65 "Installing system services"
boot_dir=""
[ ! -d /boot/firmware ] || boot_dir=/boot/firmware
[ -n "$boot_dir" ] || [ ! -d /boot ] || boot_dir=/boot
[ -n "$boot_dir" ] || die "Boot configuration directory not found."
cmdline="$boot_dir/cmdline.txt"; config="$boot_dir/config.txt"
[ -f "$cmdline" ] || die "$cmdline not found."
sudo python3 - "$cmdline" <<'PYCMD'
import pathlib,re,sys
p=pathlib.Path(sys.argv[1]); tokens=p.read_text().strip().split()
tokens=[t for t in tokens if not re.fullmatch(r'console=(serial0|ttyS0|ttyAMA0),.*',t)]
p.write_text(' '.join(tokens)+'\n')
PYCMD
sudo touch "$config"
sudo python3 - "$config" <<'PYCONFIG'
import pathlib,re,sys
p=pathlib.Path(sys.argv[1]); s=p.read_text()
if re.search(r'(?m)^enable_uart=',s): s=re.sub(r'(?m)^enable_uart=.*$','enable_uart=1',s)
else: s=s.rstrip()+'\n\nenable_uart=1\n'
p.write_text(s)
PYCONFIG
sudo systemctl disable --now serial-getty@serial0.service serial-getty@ttyS0.service serial-getty@ttyAMA0.service 2>/dev/null || true
sudo systemctl mask serial-getty@serial0.service serial-getty@ttyS0.service serial-getty@ttyAMA0.service 2>/dev/null || true
mkdir -p "$TX_DIR/pycache"
SIYI_COMPILE_PYTHON=/home/pi/siyi-bridge-venv/bin/python
[ "${SIYI_WEBUI_UPGRADE:-0}" != "1" ] || SIYI_COMPILE_PYTHON=/home/pi/siyi-bridge-venv.new/bin/python
PYTHONPYCACHEPREFIX="$TX_DIR/pycache" "$SIYI_COMPILE_PYTHON" -m py_compile /home/pi/siyi-webui/server.py /home/pi/siyi_mav_button_bridge.py /home/pi/siyi-battery-cache.py /home/pi/siyi-joystick/joystickd.py /usr/local/lib/siyi/groundstation/groundstation_daemon.py /usr/local/bin/siyi-paramd /usr/local/bin/siyi-video-source /usr/local/bin/siyi-video-udp-forward /usr/local/sbin/siyi-video-source-control
sudo visudo -cf /etc/sudoers.d/siyi-webui
sudo chmod 0600 /home/pi/siyi-webui/wifi_passwords.json /etc/siyi/maptiler.json
sudo chmod 0660 /etc/siyi/video_source.json /etc/siyi/zerotier_config.json
# All release metadata except the self-describing payload-manifest.json is
# already part of the complete target payload and immutable manifest. Install
# only the manifest itself here; a manifest cannot hash its own bytes.
sudo install -d -o root -g root -m 0755 /usr/local/share/siyi/releases/4.4.0
sudo install -o root -g root -m 0644 "$SCRIPT_DIR/payload-manifest.json" /usr/local/share/siyi/releases/4.4.0/payload-manifest.json

progress 70 "Configuring MAVLink router"
sudo install -d -o root -g root -m 0755 /etc/mavlink-router
[ -f /etc/mavlink-router/main.conf ] || die "MAVLink router configuration is missing after preservation restore."
sudo chown root:root /etc/mavlink-router/main.conf
sudo chmod 0644 /etc/mavlink-router/main.conf
sudo install -o pi -g pi -m 0755 "$PAYLOAD/home/pi/apply_siyi_endpoints.sh" /home/pi/apply_siyi_endpoints.sh
# Do not regenerate main.conf here: target defaults or the selected MAVLink snapshot are authoritative.
# Endpoint application remains available to the UI but is not run during release deployment.

progress 76 "Installing camera time sync"
test -x /usr/local/bin/siyi_proxy_socket_time_sync.sh
test -f /etc/systemd/system/siyi-camera-time-sync.service

# SIYI_4_2_0_MAPTILER_CACHE_SUCCESS_PATH_V21
if sudo test -d /var/cache/siyi-maptiler; then
  sudo stat -c '%u %g %a' /var/cache/siyi-maptiler >"$TX_DIR/maptiler-cache-state"
else
  printf '%s\n' absent >"$TX_DIR/maptiler-cache-state"
fi
MAPTILER_CACHE_STATE_READY=1
sudo install -d -o pi -g pi -m 0755 /var/cache/siyi-maptiler
[ "$(stat -c '%U:%G:%a' /var/cache/siyi-maptiler)" = "pi:pi:755" ] || die "MapTiler cache ownership or mode verification failed."
sudo -u pi test -w /var/cache/siyi-maptiler || die "MapTiler cache is not writable by pi."

progress 82 "Enabling FlightCore services"
sudo systemctl daemon-reload
sudo systemctl enable NetworkManager.service zerotier-one.service
units=(mavlink-router.service mediamtx.service flightcore-siyi-ingest.service siyi-battery-cache.service siyi-button-bridge.service siyi-camera-time-sync.service siyi-groundstation.service siyi-joystickd.service siyi-paramd.service siyi-rec-proxy.service siyi-rec-redirect.service siyi-rtsp-redirect.service siyi-telemetry-canvas.service siyi-video-dual.service siyi-video-source.service siyi-webui.service flightcore-status-cache.service flightcore-flightlog-cloud-sync.timer flightcore-flightlog-cloud-sync.path siyi-postinstall-verify.service)
sudo systemctl enable "${units[@]}"

readarray -t mav < <(python3 - "$SOURCE_LOCK" <<'PYMAV'
import json,sys
m=json.load(open(sys.argv[1]))['mavlink-router']
print(m['repository']); print(m['commit']); print(m['submodules']['modules/mavlink_c_library_v2']); print(m['expected_version'])
PYMAV
)
if ! command -v mavlink-routerd >/dev/null 2>&1 || ! mavlink-routerd --version 2>/dev/null | grep -Fq "${mav[3]}"; then
  echo "=== Build mavlink-router ==="
  rm -rf /home/pi/mavlink-router-build
  git clone "${mav[0]}" /home/pi/mavlink-router-build
  cd /home/pi/mavlink-router-build
  git -c advice.detachedHead=false checkout --detach "${mav[1]}"
  [ "$(git rev-parse HEAD)" = "${mav[1]}" ] || die "MAVLink Router commit verification failed."
  git submodule update --init --recursive
  [ "$(git -C modules/mavlink_c_library_v2 rev-parse HEAD)" = "${mav[2]}" ] || die "MAVLink C submodule verification failed."
  meson setup build .
  ninja -C build
  sudo ninja -C build install
  cd "$SCRIPT_DIR"
fi
command -v mavlink-routerd >/dev/null 2>&1 || die "MAVLink Router was not installed."
mavlink-routerd --version 2>&1 | grep -Fq "${mav[3]}" || die "MAVLink Router version verification failed."
sudo systemctl enable mavlink-router
sudo rm -rf /home/pi/mavlink-router-build

progress 88 "Installing MediaMTX"
readarray -t media < <(python3 - "$SOURCE_LOCK" <<'PYMEDIA'
import json,sys
m=json.load(open(sys.argv[1]))['mediamtx']
print(m['embedded_path']); print(m['archive_sha256']); print(m['binary_sha256']); print(m['version'])
PYMEDIA
)
media_embedded="$SCRIPT_DIR/${media[0]}"; media_archive_sha="${media[1]}"; media_binary_sha="${media[2]}"; media_version="${media[3]}"
if ! { [ -x /usr/local/bin/mediamtx ] && [ "$(sha256sum /usr/local/bin/mediamtx | awk '{print $1}')" = "$media_binary_sha" ]; }; then
  media_dir="/tmp/siyi-mediamtx-$TX"
  rm -rf "$media_dir"; mkdir -p "$media_dir"
  [ -f "$media_embedded" ] || die "Embedded FlightCore MediaMTX archive is missing."
  cp "$media_embedded" "$media_dir/mediamtx.tar.gz"
  echo "$media_archive_sha  $media_dir/mediamtx.tar.gz" | sha256sum -c -
  tar -xzf "$media_dir/mediamtx.tar.gz" -C "$media_dir" mediamtx
  echo "$media_binary_sha  $media_dir/mediamtx" | sha256sum -c -
  sudo install -m 0755 "$media_dir/mediamtx" /usr/local/bin/mediamtx
fi
[ "$(sha256sum /usr/local/bin/mediamtx | awk '{print $1}')" = "$media_binary_sha" ] || die "MediaMTX binary checksum verification failed."
/usr/local/bin/mediamtx --version 2>&1 | grep -Fq "$media_version" || die "MediaMTX version verification failed."
sudo systemctl daemon-reload
sudo systemctl enable mediamtx.service siyi-rtsp-redirect.service
cleanup_target_transients "${SIYI_WEBUI_UPGRADE:-0}"

progress 94 "Finalising runtime and restarting WebUI"
if [ "${SIYI_WEBUI_UPGRADE:-0}" = "1" ]; then
  [ -x /home/pi/siyi-bridge-venv.new/bin/python ] || die "Staged Python environment is missing before final swap."
  sudo systemctl stop siyi-webui.service
  if [ -d /home/pi/siyi-bridge-venv ]; then sudo mv /home/pi/siyi-bridge-venv "$TX_DIR/siyi-bridge-venv.previous"; fi
  sudo mv /home/pi/siyi-bridge-venv.new /home/pi/siyi-bridge-venv
  VENV_SWAPPED=1
  touch "$TX_DIR/venv-swapped"
  sudo chown -R pi:pi /home/pi/siyi-bridge-venv
  sudo systemctl daemon-reload
  sudo systemctl start siyi-webui.service
  for _siyi_wait in $(seq 1 30); do
    if curl -fsS --max-time 2 http://127.0.0.1:8080/software_update_status >/dev/null 2>&1; then break; fi
    sleep 1
  done
  curl -fsS --max-time 3 http://127.0.0.1:8080/software_update_status >/dev/null || die "Target WebUI did not return after final runtime swap."
fi
progress 96 "Validating staged installation"

# SIYI_4_2_0_RELEASE_DUPLICATE_CONSISTENCY_GATE_V23
top_health_sha="$(sha256sum "$SCRIPT_DIR/health-check.sh" | awk '{print $1}')"
payload_health_sha="$(sha256sum "$PAYLOAD/usr/local/share/siyi/releases/4.4.0/health-check.sh" | awk '{print $1}')"
[ "$top_health_sha" = "$payload_health_sha" ] || die "Release health-check copies differ."
top_restore_sha="$(sha256sum "$SCRIPT_DIR/transaction-restore.py" | awk '{print $1}')"
payload_restore_sha="$(sha256sum "$PAYLOAD/usr/local/share/siyi/releases/4.4.0/transaction-restore.py" | awk '{print $1}')"
[ "$top_restore_sha" = "$payload_restore_sha" ] || die "Transaction-restore copies differ."
for file in release-metadata.json supported-sources.json supported-source-releases.json source-lock.json preservation-model.json requirements.txt apt-packages.txt release-notes.md feature-parity-checklist.md SIYI_4.2.x_RELEASE_MODEL.md; do
  [ "$(sha256sum "$SCRIPT_DIR/$file" | awk '{print $1}')" = "$(sha256sum "/usr/local/share/siyi/releases/4.4.0/$file" | awk '{print $1}')" ] || die "Installed release metadata copy differs: $file"
done

printf '%s\n' "$VERSION" >"$TX_DIR/release_version"
printf '%s\n' "$BUILD_ID" >"$TX_DIR/release_build"
printf '%s\n' pending_reboot >"$TX_DIR/release_status"
sudo install -d -o pi -g pi -m 0775 /etc/siyi
sudo install -o root -g root -m 0644 "$TX_DIR/release_version" /etc/siyi/release_version
sudo install -o root -g root -m 0644 "$TX_DIR/release_build" /etc/siyi/release_build
sudo install -o root -g root -m 0644 "$TX_DIR/release_status" /etc/siyi/release_status
[ "$(tr -d '[:space:]' </etc/siyi/release_version)" = "$VERSION" ] || die "Release-version marker write verification failed."
[ "$(tr -d '[:space:]' </etc/siyi/release_build)" = "$BUILD_ID" ] || die "Release-build marker write verification failed."
/usr/local/sbin/siyi-release-fingerprint --verify --allow-release "$SIYI_SOURCE_RELEASE" >/dev/null
# SIYI_HEALTH_CHECK_NOEXEC_SAFE_V1
sudo /bin/bash "$SCRIPT_DIR/health-check.sh" --pre-reboot --allow-release "$SIYI_SOURCE_RELEASE"
python3 - "$MANIFEST" <<'PYFINAL'
import grp,hashlib,json,os,pwd,stat,sys
m=json.load(open(sys.argv[1],encoding='utf-8'))
for item in m['files']:
    if item.get('persistent') or item['path']=='/usr/local/share/siyi/releases/4.4.0/payload-manifest.json': continue
    p=item['path']
    if not os.path.lexists(p): raise SystemExit('missing '+p)
    st=os.lstat(p)
    actual='symlink' if stat.S_ISLNK(st.st_mode) else 'directory' if stat.S_ISDIR(st.st_mode) else 'file' if stat.S_ISREG(st.st_mode) else 'other'
    if actual!=item['type']: raise SystemExit('type mismatch '+p)
    if st.st_uid!=pwd.getpwnam(item['owner']).pw_uid or st.st_gid!=grp.getgrnam(item['group']).gr_gid: raise SystemExit('ownership mismatch '+p)
    if actual!='symlink' and stat.S_IMODE(st.st_mode)!=int(item['mode'],8): raise SystemExit('mode mismatch '+p)
    if actual=='file' and hashlib.sha256(open(p,'rb').read()).hexdigest()!=item['sha256']: raise SystemExit('checksum mismatch '+p)
    if actual=='symlink' and hashlib.sha256(os.readlink(p).encode()).hexdigest()!=item['sha256']: raise SystemExit('symlink mismatch '+p)
for p in m.get('obsolete_paths',[]):
    if os.path.lexists(p): raise SystemExit('obsolete path remained '+p)
PYFINAL
touch "$TX_DIR/INSTALL_STAGED"
printf '%s\n' "$TX_DIR" >"$TX_DIR/pending-transaction"
sudo install -d -o root -g root -m 0755 /var/lib/siyi-installer
sudo install -o root -g root -m 0644 "$TX_DIR/pending-transaction" /var/lib/siyi-installer/pending-transaction
SUCCESS=1
trap - ERR INT TERM
# Select the user-reachable LAN address before publishing completion so the
# progress WebUI can transition directly to First Setup after reboot.
PRIMARY_IP="$(siyi_select_primary_webui_ip)"
progress 100 "Install complete"
if [ "${SIYI_FRESH_INSTALL_UI:-0}" = "1" ]; then
  python3 - "$SIYI_FRESH_INSTALL_UI_STATE" "$INSTALL_LOG" "$PRIMARY_IP" <<'PYFC423RC13COMPLETE'
import datetime,json,os,sys,tempfile
path,log,ip=sys.argv[1:]
try: data=json.load(open(path,encoding='utf-8'))
except Exception: data={}
data.update({'status':'complete','progress':100,'stage':'Install complete','error':'','log_path':log,'next_url':f'http://{ip}:8080/first_setup','elapsed_seconds':max(0,int(data.get('elapsed_seconds') or 0)),'updated_at':datetime.datetime.now().astimezone().isoformat(timespec='seconds')})
os.makedirs(os.path.dirname(path),exist_ok=True); fd,tmp=tempfile.mkstemp(prefix='.state.',dir=os.path.dirname(path))
with os.fdopen(fd,'w',encoding='utf-8') as f: json.dump(data,f,indent=2); f.write('\n'); f.flush(); os.fsync(f.fileno())
os.chmod(tmp,0o644); os.replace(tmp,path)
PYFC423RC13COMPLETE
  echo "Fresh-install WebUI: Install complete; next_url=http://${PRIMARY_IP}:8080/first_setup"
fi
cat >&3 <<EOF

========================================
✅ FLIGHTCORE INSTALL COMPLETE
========================================

=== OPEN WEB UI ===
http://${PRIMARY_IP}:8080

👉 Connect Mac or PC to the same local network as the Pi and use the above URL for local access to the Web client. From there, configure ZeroTier and Hosts.

Full install log:
$INSTALL_LOG
EOF

if [ "$NO_REBOOT" -eq 0 ]; then
  cat >&3 <<EOF

The Raspberry Pi will reboot automatically in 5 seconds.
Post-reboot acceptance will be written to:
/etc/siyi/release_status
EOF
  sleep 5
  sudo systemctl reboot
else
  cat >&3 <<EOF

Reboot required. Run:
sudo reboot
EOF
fi
