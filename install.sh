#!/usr/bin/env bash
# RedProxy installer
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/thedarkkness/RedProxy/main/install.sh)
set -euo pipefail

REPO_URL="https://github.com/thedarkkness/RedProxy.git"
INSTALL_DIR="/opt/redproxy"
VERSION="0.0.1"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info() { echo -e "${BLUE}[i]${NC} $*"; }
ok()   { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*" >&2; }

if [[ "$EUID" -ne 0 ]]; then
    err "Run as root: sudo bash <(curl -fsSL https://raw.githubusercontent.com/thedarkkness/RedProxy/main/install.sh)"
    exit 1
fi

echo -e "${CYAN}"
cat <<'BANNER'
 ____          _ ____
|  _ \ ___  __| |  _ \ _ __ _____  ___   _
| |_) / _ \/ _` | |_) | '__/ _ \ \/ / | | |
|  _ <  __/ (_| |  __/| | | (_) >  <| |_| |
|_| \_\___|\__,_|_|   |_|  \___/_/\_\\__, |
                                     |___/
BANNER
echo -e "${NC}          RedProxy Installer v${VERSION}"
echo

info "Detecting OS and installing base dependencies..."
OS_ID=""
[[ -r /etc/os-release ]] && . /etc/os-release
case "${ID:-}" in
    ubuntu|debian)
        apt-get update -y >/dev/null
        apt-get install -y curl wget unzip git jq openssl qrencode socat cron python3 python3-venv ufw >/dev/null
        ;;
    centos|rhel|almalinux|rocky|fedora)
        PM=dnf; command -v dnf >/dev/null 2>&1 || PM=yum
        $PM install -y curl wget unzip git jq openssl qrencode socat cronie python3 firewalld >/dev/null
        ;;
    *)
        err "Unsupported OS: ${ID:-unknown}. RedProxy supports Debian/Ubuntu and RHEL-family distros."
        exit 1
        ;;
esac
ok "Dependencies installed"

info "Fetching RedProxy v${VERSION}..."
rm -rf "$INSTALL_DIR"
git clone --quiet --depth 1 "$REPO_URL" "$INSTALL_DIR"
chmod +x "$INSTALL_DIR"/*.sh "$INSTALL_DIR"/xray/*.sh "$INSTALL_DIR"/wireguard/*.sh "$INSTALL_DIR"/utils/*.sh
ok "RedProxy downloaded to $INSTALL_DIR"

# shellcheck source=./utils/colors.sh
source "$INSTALL_DIR/utils/colors.sh"
# shellcheck source=./utils/common.sh
source "$INSTALL_DIR/utils/common.sh"
# shellcheck source=./utils/os.sh
source "$INSTALL_DIR/utils/os.sh"

info "Configuring firewall..."
if command -v ufw >/dev/null 2>&1; then
    ufw allow OpenSSH >/dev/null 2>&1 || true
    ufw allow 443/tcp >/dev/null 2>&1 || true
    ufw --force enable >/dev/null 2>&1 || true
elif command -v firewall-cmd >/dev/null 2>&1; then
    systemctl enable --now firewalld >/dev/null 2>&1 || true
    firewall-cmd --permanent --add-service=ssh >/dev/null 2>&1 || true
    firewall-cmd --permanent --add-port=443/tcp >/dev/null 2>&1 || true
    firewall-cmd --reload >/dev/null 2>&1 || true
fi
ok "Firewall configured (SSH + 443/tcp allowed)"

info "Enabling BBR congestion control..."
cat > /etc/sysctl.d/99-redproxy-bbr.conf <<'SYSCTL'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
SYSCTL
sysctl --system >/dev/null 2>&1 || true
ok "BBR enabled"

bash "$INSTALL_DIR/xray/install_xray.sh"

info "Setting up Python venv for QR rendering..."
bash "$INSTALL_DIR/utils/venv_setup.sh" "$INSTALL_DIR" || warn "venv setup skipped, will fall back to qrencode"

ln -sf "$INSTALL_DIR/menu.sh" /usr/local/bin/redproxy
chmod +x /usr/local/bin/redproxy
ok "Installed 'redproxy' command"

echo
echo "Select a protocol to install:"
echo "  1) VLESS + Reality        [ready]"
echo "  2) VLESS + WS + TLS       [coming soon]"
echo "  3) VMess                  [coming soon]"
echo "  4) Trojan                 [coming soon]"
echo "  5) Hysteria2              [coming soon]"
echo "  6) TUIC                   [coming soon]"
echo "  7) WireGuard              [coming soon]"
read -rp "> " choice

case "$choice" in
    1)
        read -rp "Port [443]: " port; port=${port:-443}
        read -rp "SNI to masquerade as [www.microsoft.com]: " sni; sni=${sni:-www.microsoft.com}
        # shellcheck source=./xray/reality.sh
        source "$INSTALL_DIR/xray/reality.sh"
        reality_install "$port" "$sni"
        ;;
    *)
        warn "That protocol isn't implemented yet in v${VERSION}."
        warn "Run 'redproxy' later to install VLESS+Reality, or watch the repo for updates."
        ;;
esac

echo
ok "RedProxy installed. Run 'redproxy' anytime to manage clients."
