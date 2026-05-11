#!/bin/bash
set -e


SIYI_INSTALL_VERSION="2.2.0"
INSTALL_LOG="/home/pi/siyi_install_${SIYI_INSTALL_VERSION}_$(date +%Y%m%d_%H%M%S).log"

SIYI_BLUE=$'\033[0;94m'
SIYI_GREEN=$'[1;32m'
SIYI_RESET=$'[0m'
SIYI_PROGRESS_HEADING_PRINTED=0
exec 3>&1 4>&2
exec >>"$INSTALL_LOG" 2>&1
CURRENT_STEP="starting"
INSTALL_START_TS="$SECONDS"

PROGRESS_ANIM_PID=""
PROGRESS_LAST=0

progress_next_target() {
  case "$1" in
    5) echo 9 ;;
    10) echo 24 ;;
    25) echo 34 ;;
    35) echo 44 ;;
    45) echo 49 ;;
    50) echo 57 ;;
    58) echo 64 ;;
    65) echo 69 ;;
    70) echo 75 ;;
    76) echo 81 ;;
    82) echo 87 ;;
    88) echo 94 ;;
    95) echo 99 ;;
    *) echo "$1" ;;
  esac
}

draw_progress() {
  local pct="$1"
  local msg="$2"
  local elapsed="${3:-0}"

  local width=20
  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))

  local bar=""
  local i

  local spin='|/-\\'
  local idx=$(( SECONDS % 4 ))
  local sp="${spin:$idx:1}"

  local timer=""
  if [ "$elapsed" -gt 0 ]; then
    mins=$(( elapsed / 60 ))
    secs=$(( elapsed % 60 ))
    timer=$(printf " (%02dm %02ds)" "$mins" "$secs")
  fi

  for ((i=0; i<filled; i++)); do
    bar+="█"
  done

  for ((i=0; i<empty; i++)); do
    bar+="░"
  done

  if [ "${SIYI_PROGRESS_HEADING_PRINTED:-0}" -eq 0 ]; then
    printf "%sInstalling, SIYI PI Control System%s\n\n" "$SIYI_BLUE" "$SIYI_RESET" >&3
    SIYI_PROGRESS_HEADING_PRINTED=1
  fi

  printf "\r\033[2K%s%s [%s] %3d%%  %s%s%s" \
    "$SIYI_GREEN" "$sp" "$bar" "$pct" "$msg" "$timer" "$SIYI_RESET" >&3
}

stop_progress_anim() {
  if [ -n "${PROGRESS_ANIM_PID:-}" ]; then
    kill "$PROGRESS_ANIM_PID" >/dev/null 2>&1 || true
    wait "$PROGRESS_ANIM_PID" >/dev/null 2>&1 || true
    PROGRESS_ANIM_PID=""
  fi
}

progress() {
  local pct="$1"
  local msg="$2"
  local target
  local cur

  stop_progress_anim

  CURRENT_STEP_NAME="$msg"
  PROGRESS_LAST="$pct"

  draw_progress "$pct" "$msg" "$((SECONDS - INSTALL_START_TS))"

  target="$(progress_next_target "$pct")"

  (
    cur="$pct"

    while true; do
      sleep 1

      elapsed=$((SECONDS - INSTALL_START_TS))

      if [ "$cur" -lt "$target" ]; then
        cur=$((cur + 1))
      fi

      draw_progress "$cur" "$msg" "$elapsed"
    done
  ) &

  PROGRESS_ANIM_PID="$!"

  if [ "$pct" -ge 100 ]; then
    stop_progress_anim
    draw_progress 100 "$msg" "$((SECONDS - INSTALL_START_TS))"
    printf "\n" >&3
  fi
}

fail_screen() {
  stop_progress_anim || true
  printf "\n\n" >&3
  echo "========================================" >&3
  echo "❌ SIYI INSTALL FAILED" >&3
  echo "========================================" >&3
  echo "Step: ${CURRENT_STEP_NAME:-starting}" >&3
  echo "Exit code: $?" >&3
  echo "Full log:" >&3
  echo "$INSTALL_LOG" >&3
  echo >&3
  echo "Nothing was intentionally rolled back automatically." >&3
  echo "Inspect the log before retrying." >&3
}

trap fail_screen ERR

echo "=== SIYI Public Installer $SIYI_INSTALL_VERSION ==="
echo "Full log: $INSTALL_LOG" >&3

echo "Sudo check: enter the Pi password if asked." >&3
sudo -v

progress 5 "Preparing installer"

apt_lock_guard() {
  echo "=== APT LOCK GUARD ==="

  # Do not delete apt/dpkg lock files. Wait for the owning processes to finish.
  timeout 10s sudo systemctl stop packagekit.service 2>/dev/null || echo "[APT_LOCK] packagekit stop timed out; continuing to lock check"

  local locks=(/var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock)
  local max_wait=300
  local waited=0

  while true; do
    local lock_busy=0
    if sudo fuser "${locks[@]}" >/dev/null 2>&1; then
      lock_busy=1
    fi

    if pgrep -x apt >/dev/null 2>&1 || \
       pgrep -x apt-get >/dev/null 2>&1 || \
       pgrep -x dpkg >/dev/null 2>&1 || \
       pgrep -x unattended-upgrade >/dev/null 2>&1 || \
       pgrep -x packagekitd >/dev/null 2>&1; then
      lock_busy=1
    fi

    if [ "$lock_busy" -eq 0 ]; then
      break
    fi

    if [ "$waited" -ge "$max_wait" ]; then
      echo "[APT_LOCK] ERROR: apt/dpkg/packagekit still busy after ${max_wait}s"
      ps -eo pid,ppid,stat,comm,args | grep -Ei 'apt|dpkg|packagekit|unattended' | grep -v grep || true
      return 1
    fi

    echo "[APT_LOCK] waiting... ${waited}/${max_wait}s"
    sleep 5
    waited=$((waited + 5))
  done

  sudo dpkg --configure -a
}

apt_lock_guard


progress 10 "Installing base dependencies"
echo "=== SIYI Public Installer ==="

sudo apt update
sudo apt-get install -y \
  python3 \
  python3-venv \
  python3-pip \
  network-manager \
  iproute2 \
  psmisc \
  jq \
  git \
  meson \
  ninja-build \
  pkg-config \
  gcc \
  g++ \
  libsystemd-dev \
  systemd-dev \
  iptables \
  curl \
  systemd-dev \
  curl


progress 25 "Installing ZeroTier"
echo "=== Install ZeroTier ==="
apt_lock_guard
if ! command -v zerotier-cli >/dev/null 2>&1; then
  curl -s https://install.zerotier.com | sudo bash
fi
sudo systemctl enable zerotier-one
sudo systemctl start zerotier-one

progress 35 "Installing SIYI configuration"
echo "=== Copy config ==="
cp config/siyi-config.json /home/pi/siyi-config.json
cp config/button_map.csv /home/pi/button_map.csv
sudo mkdir -p /etc/siyi
if [ -f config/button_safety.json ] && [ ! -f /etc/siyi/button_safety.json ]; then
  sudo cp config/button_safety.json /etc/siyi/button_safety.json
  sudo chmod 644 /etc/siyi/button_safety.json
fi
echo "$SIYI_INSTALL_VERSION" | sudo tee /etc/siyi/release_version >/dev/null
sudo chmod 644 /etc/siyi/release_version

echo "=== Copy scripts ==="
sudo cp scripts/siyi-battery-cache.py /home/pi/siyi-battery-cache.py
sudo chmod +x /home/pi/siyi-battery-cache.py
cp scripts/siyi_mav_button_bridge.py /home/pi/siyi_mav_button_bridge.py
cp scripts/siyi_tcp_proxy_inject.py /home/pi/siyi_tcp_proxy_inject.py
chmod +x /home/pi/siyi_mav_button_bridge.py /home/pi/siyi_tcp_proxy_inject.py

progress 45 "Installing Web UI"
echo "=== Copy webui ==="
sudo rm -rf /home/pi/siyi-webui
sudo mkdir -p /home/pi/siyi-webui
sudo cp -a siyi-webui/. /home/pi/siyi-webui/
sudo chown -R pi:pi /home/pi/siyi-webui

progress 50 "Configuring camera Ethernet"
echo "=== Configure camera eth0 ==="
sudo nmcli connection delete cam-eth0 2>/dev/null || true
sudo nmcli connection add type ethernet ifname eth0 con-name cam-eth0 ipv4.addresses $(jq -r .camera_eth_ip /home/pi/siyi-config.json 2>/dev/null || echo 192.168.144.20/24) ipv4.method manual ipv6.method ignore
sudo nmcli connection up cam-eth0 || true

progress 58 "Preparing Python environment"
echo "=== Python venv ==="
python3 -m venv /home/pi/siyi-bridge-venv
/home/pi/siyi-bridge-venv/bin/pip install --upgrade pip
/home/pi/siyi-bridge-venv/bin/pip install pymavlink numpy future pyserial

progress 65 "Installing system services"
echo "=== Copy services ==="
sudo cp services/siyi-webui.service /etc/systemd/system/
sudo cp services/siyi-rec-proxy.service /etc/systemd/system/
sudo cp services/siyi-button-bridge.service /etc/systemd/system/
sudo cp services/siyi-battery-cache.service /etc/systemd/system/
sudo cp services/mavlink-router.service /etc/systemd/system/ 2>/dev/null || true

progress 70 "Configuring MAVLink router"
echo "=== MAVLink config ==="
sudo mkdir -p /etc/mavlink-router
sudo tee /etc/mavlink-router/main.conf >/dev/null <<'EOL'
[General]
TcpServerPort=5760
ReportStats=false

[UartEndpoint fc]
Device=/dev/serial0
Baud=57600

[UdpEndpoint button_safety]
Mode=Normal
Address=127.0.0.1
Port=14600

[UdpEndpoint webui_status_monitor]
Mode=Normal
Address=127.0.0.1
Port=14601
EOL



echo "=== Install endpoint apply script ==="
cp scripts/apply_siyi_endpoints.sh /home/pi/apply_siyi_endpoints.sh
chmod +x /home/pi/apply_siyi_endpoints.sh
chown pi:pi /home/pi/apply_siyi_endpoints.sh


echo "=== Install REC redirect service ==="
sudo cp services/siyi-rec-redirect.service /etc/systemd/system/siyi-rec-redirect.service
sudo chmod 644 /etc/systemd/system/siyi-rec-redirect.service
sudo systemctl daemon-reload
sudo systemctl enable siyi-rec-redirect.service
sudo systemctl restart siyi-rec-redirect.service
\
progress 76 "Installing camera time sync"
echo "=== Install camera time sync ==="
sudo cp scripts/siyi_set_camera_time.sh /usr/local/bin/siyi_set_camera_time.sh
sudo chmod +x /usr/local/bin/siyi_set_camera_time.sh
sudo cp scripts/siyi_proxy_socket_time_sync.sh /usr/local/bin/siyi_proxy_socket_time_sync.sh
sudo chmod +x /usr/local/bin/siyi_proxy_socket_time_sync.sh
sudo cp scripts/siyi_direct_camera_time_sync.py /usr/local/bin/siyi_direct_camera_time_sync.py
sudo chmod +x /usr/local/bin/siyi_direct_camera_time_sync.py
sudo cp scripts/siyi_verified_camera_time_sync.sh /usr/local/bin/siyi_verified_camera_time_sync.sh
sudo chmod +x /usr/local/bin/siyi_verified_camera_time_sync.sh || echo "[WARN] Camera time sync not verified during install; camera may be disconnected. Will retry at boot/runtime."
sudo cp services/siyi-camera-time-sync.service /etc/systemd/system/siyi-camera-time-sync.service
sudo chmod 644 /etc/systemd/system/siyi-camera-time-sync.service
sudo systemctl daemon-reload
sudo systemctl enable siyi-camera-time-sync.service

progress 82 "Enabling SIYI services"
echo "=== Enable services ==="

# Install button bridge startup ordering override.
# This lets the public installer work before ZeroTier is configured:
# the bridge will keep retrying until a zt* interface exists, then start automatically.
sudo mkdir -p /etc/systemd/system/siyi-button-bridge.service.d
sudo cp systemd-overrides/siyi-button-bridge.service.d/wait-for-zt.conf /etc/systemd/system/siyi-button-bridge.service.d/wait-for-zt.conf

sudo systemctl daemon-reload
sudo systemctl enable siyi-webui
sudo systemctl enable siyi-rec-proxy
sudo systemctl enable siyi-button-bridge
sudo systemctl enable siyi-battery-cache

if ! command -v mavlink-routerd >/dev/null 2>&1; then
  echo "=== Build mavlink-router ==="
  rm -rf /home/pi/mavlink-router-build
  git clone https://github.com/mavlink-router/mavlink-router.git /home/pi/mavlink-router-build
  cd /home/pi/mavlink-router-build
  git submodule update --init --recursive
  meson setup build .
  ninja -C build
  sudo ninja -C build install
  cd /home/pi
fi

sudo systemctl enable mavlink-router

sudo systemctl restart siyi-webui

echo "=== Start REC proxy before verified camera time sync ==="
sudo systemctl restart siyi-rec-proxy
sleep 3

echo "=== Proxy socket camera time sync ==="
sudo /usr/local/bin/siyi_proxy_socket_time_sync.sh

echo "=== Restart MAVLink router before button bridge ==="
sudo systemctl reset-failed mavlink-router.service siyi-button-bridge.service || true
sudo systemctl restart mavlink-router
sudo systemctl restart siyi-battery-cache
sleep 3

echo "=== Start button bridge last ==="
sudo systemctl restart siyi-button-bridge




progress 88 "Installing MediaMTX video relay"
echo "=== Install MediaMTX ==="
ARCH="$(uname -m)"
case "$ARCH" in
  aarch64) ASSET="linux_arm64.tar.gz" ;;
  armv7l|armv6l) ASSET="linux_armv7.tar.gz" ;;
  *) echo "Unsupported arch"; exit 1 ;;
esac

URL=$(curl -s https://api.github.com/repos/bluenviron/mediamtx/releases/latest | jq -r '.assets[].browser_download_url' | grep $ASSET | head -n1)

rm -rf /tmp/mediamtx
mkdir -p /tmp/mediamtx
cd /tmp/mediamtx
curl -L $URL -o mediamtx.tar.gz
tar -xzf mediamtx.tar.gz

sudo systemctl stop mediamtx 2>/dev/null || true
sudo pkill -f '/usr/local/bin/mediamtx' 2>/dev/null || true
sleep 1
sudo rm -f /usr/local/bin/mediamtx
sudo systemctl stop mediamtx 2>/dev/null || true
sudo pkill -f '/usr/local/bin/mediamtx' 2>/dev/null || true
sleep 1
sudo rm -f /usr/local/bin/mediamtx
sudo cp mediamtx /usr/local/bin/

sudo mkdir -p /usr/local/etc/mediamtx
sudo tee /usr/local/etc/mediamtx/mediamtx.yml >/dev/null <<EOF
logLevel: info
rtspAddress: :8554
rtspTransports: [tcp]

paths:
  main.264:
    source: rtsp://192.168.144.25:8554/main.264
    sourceProtocol: tcp
    sourceOnDemand: yes
EOF

sudo tee /etc/systemd/system/mediamtx.service >/dev/null <<EOF
[Unit]
Description=MediaMTX RTSP relay
After=network.target

[Service]
ExecStart=/usr/local/bin/mediamtx /usr/local/etc/mediamtx/mediamtx.yml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable mediamtx
sudo systemctl restart mediamtx


progress 95 "Finalizing RTSP redirect"
echo "=== RTSP Redirect ==="
sudo sysctl -w net.ipv4.ip_forward=1

sudo iptables -t nat -A PREROUTING -i zt+ -d 192.168.144.25 -p tcp --dport 8554 -j REDIRECT --to-ports 8554
sudo iptables -t nat -A PREROUTING -i wlan0 -d 192.168.144.25 -p tcp --dport 8554 -j REDIRECT --to-ports 8554

sudo tee /etc/systemd/system/siyi-rtsp-redirect.service >/dev/null <<EOF
[Unit]
Description=RTSP redirect
After=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'iptables -t nat -A PREROUTING -i zt+ -d 192.168.144.25 -p tcp --dport 8554 -j REDIRECT --to-ports 8554; iptables -t nat -A PREROUTING -i wlan0 -d 192.168.144.25 -p tcp --dport 8554 -j REDIRECT --to-ports 8554'

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable siyi-rtsp-redirect
sudo systemctl start siyi-rtsp-redirect


echo

echo
progress 100 "Install complete"
true
cat >&3 <<EOF

========================================
✅ SIYI INSTALL COMPLETE
========================================

=== OPEN WEB UI ===
http://$(hostname -I | tr " " "\n" | grep -E "^192\.168\.0\." | head -n1):8080

👉 Connect Mac or PC to the same WiFi as the PI and use the above URL for local access to the Web client, from there configure Zero Tier and Hosts.

Full install log:
$INSTALL_LOG
EOF

