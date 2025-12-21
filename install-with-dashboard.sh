#!/bin/bash
# ==================================================
# Xray + Dashboard Complete Installer
# Supported: Ubuntu 20.04+, Debian 10+, CentOS 7+
# Components:
#   - Xray (VLESS + REALITY + Vision)
#   - FastAPI Dashboard (Python 3.11+)
#   - Systemd services
#   - Optional Nginx reverse proxy
# ==================================================

set -euo pipefail

# Configuration
XRAY_CONFIG_DIR="/usr/local/etc/xray"
DASHBOARD_DIR="/opt/xray-dashboard"
DASHBOARD_PORT=8080
LOG_DIR="/var/log/xray"
BBR_CONF="/etc/sysctl.d/99-bbr.conf"

# Colors
Color_Off='\033[0m'
BGreen='\033[1;32m'
BYellow='\033[1;33m'
BRed='\033[1;31m'
BCyan='\033[1;36m'

log_info() { echo -e "${BCyan}[INFO] $1${Color_Off}"; }
log_warn() { echo -e "${BYellow}[WARN] $1${Color_Off}"; }
log_error() { echo -e "${BRed}[ERROR] $1${Color_Off}"; exit 1; }
log_success() { echo -e "${BGreen}[SUCCESS] $1${Color_Off}"; }

# Root check
if [[ "$EUID" -ne 0 ]]; then
  log_error "This script must be run as root (sudo)"
fi

log_info "=================================================="
log_info " Xray + Dashboard Installation"
log_info "=================================================="
echo ""

# ==================================================
# 1. DETECT OS
# ==================================================
log_info "Detecting operating system..."

if [[ ! -f /etc/os-release ]]; then
    log_error "/etc/os-release not found"
fi

. /etc/os-release
OS="$ID"
VERSION_ID="${VERSION_ID:-unknown}"

log_info "Detected: $OS $VERSION_ID"

case $OS in
    ubuntu|debian|linuxmint)
        PKG_MANAGER="apt"
        PYTHON_PKG="python3.11"
        ;;
    centos|almalinux|rocky|rhel|fedora)
        PKG_MANAGER="yum"
        if command -v dnf &> /dev/null; then
            PKG_MANAGER="dnf"
        fi
        PYTHON_PKG="python3.11"
        ;;
    *)
        log_error "Unsupported OS: $OS"
        ;;
esac

# ==================================================
# 2. INSTALL DEPENDENCIES
# ==================================================
log_info "Installing system dependencies..."

case $OS in
    ubuntu|debian|linuxmint)
        apt update -y || log_error "apt update failed"
        apt install -y curl wget unzip socat qrencode jq git \
            software-properties-common build-essential || log_error "Dependency installation failed"
        
        # Python 3.11 from deadsnakes PPA
        if ! command -v python3.11 &> /dev/null; then
            log_info "Adding deadsnakes PPA for Python 3.11..."
            add-apt-repository -y ppa:deadsnakes/ppa
            apt update -y
            apt install -y python3.11 python3.11-venv python3.11-dev
        fi
        ;;
    centos|almalinux|rocky|rhel|fedora)
        $PKG_MANAGER update -y || log_warn "Update failed"
        $PKG_MANAGER install -y curl wget unzip socat qrencode jq git \
            gcc make openssl-devel bzip2-devel libffi-devel zlib-devel || log_error "Dependency installation failed"
        
        # Python 3.11 from source if not available
        if ! command -v python3.11 &> /dev/null; then
            log_info "Building Python 3.11 from source (this may take 5-10 minutes)..."
            cd /tmp
            wget -q https://www.python.org/ftp/python/3.11.7/Python-3.11.7.tgz
            tar -xzf Python-3.11.7.tgz
            cd Python-3.11.7
            ./configure --enable-optimizations --with-ensurepip=install
            make -j$(nproc)
            make altinstall
            cd /tmp
            rm -rf Python-3.11.7*
        fi
        ;;
esac

log_success "Dependencies installed"

# ==================================================
# 3. INSTALL XRAY CORE
# ==================================================
log_info "Installing Xray core..."

if command -v xray &> /dev/null; then
    log_info "Xray already installed: $(xray version | head -n1)"
else
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install || log_error "Xray installation failed"
    log_success "Xray installed: $(xray version | head -n1)"
fi

# ==================================================
# 4. ENABLE TCP BBR
# ==================================================
log_info "Enabling TCP BBR..."

if ! grep -q "net.core.default_qdisc=fq" "$BBR_CONF" 2>/dev/null; then
    echo "net.core.default_qdisc=fq" | tee "$BBR_CONF" > /dev/null
fi

if ! grep -q "net.ipv4.tcp_congestion_control=bbr" "$BBR_CONF" 2>/dev/null; then
    echo "net.ipv4.tcp_congestion_control=bbr" | tee -a "$BBR_CONF" > /dev/null
fi

sysctl -p "$BBR_CONF" || log_warn "BBR enable failed (kernel < 4.9?)"

# ==================================================
# 5. CONFIGURE XRAY (REALITY)
# ==================================================
log_info "Configuring Xray with REALITY..."

# Generate keys
set +e
KEYS_OUTPUT=$(/usr/local/bin/xray x25519 2>&1)
set -e

PRIVATE_KEY=$(echo "$KEYS_OUTPUT" | grep -E "^(PrivateKey|Private key):" | awk '{print $NF}' | tr -d '\r\n')
PUBLIC_KEY=$(echo "$KEYS_OUTPUT" | grep -E "^(Password|Public key):" | awk '{print $NF}' | tr -d '\r\n')

if [[ -z "$PRIVATE_KEY" || -z "$PUBLIC_KEY" ]]; then
    log_error "Failed to generate x25519 keys"
fi

USER_UUID=$(xray uuid)
SHORT_ID=$(openssl rand -hex 8)
SNI_HOST="www.microsoft.com"
VLESS_PORT=443

log_info "UUID: $USER_UUID"
log_info "ShortID: $SHORT_ID"

# Create config
mkdir -p "$LOG_DIR"
mkdir -p "$XRAY_CONFIG_DIR"

cat > "${XRAY_CONFIG_DIR}/config.json" << EOF
{
  "log": {
    "loglevel": "warning",
    "access": "${LOG_DIR}/access.log",
    "error": "${LOG_DIR}/error.log"
  },
  "inbounds": [
    {
      "port": ${VLESS_PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${USER_UUID}",
            "flow": "xtls-rprx-vision",
            "email": "admin@localhost"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "${SNI_HOST}:443",
          "xver": 0,
          "serverNames": ["${SNI_HOST}"],
          "privateKey": "${PRIVATE_KEY}",
          "shortIds": ["${SHORT_ID}", ""]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"]
      }
    }
  ],
  "outbounds": [
    {"protocol": "freedom", "tag": "direct"},
    {"protocol": "blackhole", "tag": "block"}
  ],
  "routing": {
    "rules": [
      {"type": "field", "ip": ["geoip:private"], "outboundTag": "block"}
    ]
  }
}
EOF

# Validate config
xray -test -config "${XRAY_CONFIG_DIR}/config.json" || log_error "Invalid Xray config"

log_success "Xray configured"

# ==================================================
# 6. INSTALL DASHBOARD
# ==================================================
log_info "Installing Dashboard..."

# Clone or copy repository
if [[ ! -d "$DASHBOARD_DIR" ]]; then
    mkdir -p "$DASHBOARD_DIR"
    
    # Copy files from current directory if running from repo
    if [[ -f "./backend/main.py" ]]; then
        log_info "Copying dashboard files from repository..."
        cp -r backend "$DASHBOARD_DIR/"
        cp -r frontend "$DASHBOARD_DIR/"
        cp pyproject.toml "$DASHBOARD_DIR/" 2>/dev/null || true
    else
        log_info "Downloading dashboard from GitHub..."
        cd /tmp
        wget -q https://github.com/Nerve11/Xray-Vless-auto-Deploy/archive/refs/heads/feature/dashboard-mvp.tar.gz
        tar -xzf dashboard-mvp.tar.gz
        cp -r Xray-Vless-auto-Deploy-feature-dashboard-mvp/backend "$DASHBOARD_DIR/"
        cp -r Xray-Vless-auto-Deploy-feature-dashboard-mvp/frontend "$DASHBOARD_DIR/"
        cp Xray-Vless-auto-Deploy-feature-dashboard-mvp/pyproject.toml "$DASHBOARD_DIR/" 2>/dev/null || true
        rm -rf Xray-Vless-auto-Deploy-feature-dashboard-mvp*
    fi
fi

# Create virtual environment
log_info "Setting up Python virtual environment..."
python3.11 -m venv "$DASHBOARD_DIR/venv"
source "$DASHBOARD_DIR/venv/bin/activate"

# Install dependencies
pip install --upgrade pip setuptools wheel
pip install fastapi uvicorn[standard] pydantic aiofiles httpx qrcode[pil] || log_error "Python dependencies installation failed"

deactivate

log_success "Dashboard installed"

# ==================================================
# 7. SETUP SYSTEMD SERVICES
# ==================================================
log_info "Configuring systemd services..."

# Xray service (already exists from install script)
systemctl enable xray
systemctl restart xray

# Dashboard service
if [[ -f "./systemd/xray-dashboard.service" ]]; then
    cp ./systemd/xray-dashboard.service /etc/systemd/system/
else
    wget -q -O /etc/systemd/system/xray-dashboard.service \
        https://raw.githubusercontent.com/Nerve11/Xray-Vless-auto-Deploy/feature/dashboard-mvp/systemd/xray-dashboard.service
fi

systemctl daemon-reload
systemctl enable xray-dashboard
systemctl start xray-dashboard

log_success "Services started"

# ==================================================
# 8. CONFIGURE FIREWALL
# ==================================================
log_info "Configuring firewall..."

if command -v ufw &> /dev/null; then
    ufw allow $VLESS_PORT/tcp
    ufw allow $DASHBOARD_PORT/tcp
    ufw status | grep -qw active && ufw reload
elif command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-port=$VLESS_PORT/tcp
    firewall-cmd --permanent --add-port=$DASHBOARD_PORT/tcp
    firewall-cmd --reload
fi

# ==================================================
# 9. GET SERVER IP
# ==================================================
SERVER_IP=$(curl -s4 https://ifconfig.me || echo "YOUR_SERVER_IP")

# ==================================================
# 10. GENERATE VLESS LINK
# ==================================================
VLESS_LINK="vless://${USER_UUID}@${SERVER_IP}:${VLESS_PORT}?type=tcp&security=reality&pbk=${PUBLIC_KEY}&fp=chrome&sni=${SNI_HOST}&sid=${SHORT_ID}&flow=xtls-rprx-vision#Xray-Reality"

# ==================================================
# INSTALLATION COMPLETE
# ==================================================
echo ""
log_success "=================================================="
log_success " Installation Complete!"
log_success "=================================================="
echo ""
echo -e "${BCyan}Server IP:${Color_Off} $SERVER_IP"
echo -e "${BCyan}Xray Port:${Color_Off} $VLESS_PORT"
echo -e "${BCyan}Dashboard:${Color_Off} http://${SERVER_IP}:${DASHBOARD_PORT}"
echo ""
echo -e "${BGreen}Initial VLESS Profile:${Color_Off}"
echo -e "${BYellow}UUID:${Color_Off} $USER_UUID"
echo -e "${BYellow}Email:${Color_Off} admin@localhost"
echo ""
echo -e "${BGreen}Connection Link:${Color_Off}"
echo -e "${VLESS_LINK}"
echo ""
echo -e "${BCyan}Service Management:${Color_Off}"
echo -e "  Xray:      ${BYellow}systemctl status xray${Color_Off}"
echo -e "  Dashboard: ${BYellow}systemctl status xray-dashboard${Color_Off}"
echo ""
echo -e "${BCyan}Logs:${Color_Off}"
echo -e "  Xray:      ${BYellow}journalctl -u xray -f${Color_Off}"
echo -e "  Dashboard: ${BYellow}journalctl -u xray-dashboard -f${Color_Off}"
echo ""
echo -e "${BYellow}Next Steps:${Color_Off}"
echo -e "  1. Open dashboard: http://${SERVER_IP}:${DASHBOARD_PORT}"
echo -e "  2. Create additional profiles via web interface"
echo -e "  3. (Optional) Setup Nginx reverse proxy for HTTPS"
echo ""
log_info "Installation completed successfully!"

exit 0