#!/usr/bin/env bash
# RedProxy installer
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/thedarkkness/RedProxy/main/install.sh)
set -euo pipefail

REPO_URL="https://github.com/thedarkkness/RedProxy.git"
INSTALL_DIR="/opt/redproxy"

# Single source of truth for the version is the VERSION file in the repo
# (read by menu.sh etc. after cloning). install.sh runs before anything is
# cloned, so it fetches the same file remotely instead of hardcoding a
# copy that's guaranteed to go stale after the next release.
VERSION=$(curl -fsSL "https://raw.githubusercontent.com/thedarkkness/RedProxy/main/VERSION" 2>/dev/null | tr -d '[:space:]')
[[ -n "$VERSION" ]] || VERSION="dev"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info() { echo -e "${BLUE}[i]${NC} $*"; }
ok()   { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*" >&2; }

# Minimal inline translator for the handful of messages printed before the
# repo is cloned (utils/colors.sh, which defines the same m(), isn't on
# disk yet at this point). RP_LANG is written to $INSTALL_DIR/lang once
# the repo is cloned so every later script (menu.sh, update.sh, ...)
# reads back the same choice via load_lang().
RP_LANG="en"
m() { if [[ "$RP_LANG" == "ru" ]]; then printf '%s' "$2"; else printf '%s' "$1"; fi }

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

echo "Select language / Выберите язык:"
echo "  1) English"
echo "  2) Русский"
read -rp "> " lang_choice
case "$lang_choice" in
    2) RP_LANG="ru" ;;
    *) RP_LANG="en" ;;
esac
echo

info "$(m "Detecting OS and installing base dependencies..." "Определяю ОС и устанавливаю базовые зависимости...")"
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
        err "$(m "Unsupported OS: ${ID:-unknown}. RedProxy supports Debian/Ubuntu and RHEL-family distros." "Неподдерживаемая ОС: ${ID:-unknown}. RedProxy поддерживает Debian/Ubuntu и семейство RHEL.")"
        exit 1
        ;;
esac
ok "$(m "Dependencies installed" "Зависимости установлены")"

info "$(m "Fetching RedProxy v${VERSION}..." "Загружаю RedProxy v${VERSION}...")"
rm -rf "$INSTALL_DIR"
git clone --quiet --depth 1 "$REPO_URL" "$INSTALL_DIR"
chmod +x "$INSTALL_DIR"/*.sh "$INSTALL_DIR"/xray/*.sh "$INSTALL_DIR"/wireguard/*.sh "$INSTALL_DIR"/utils/*.sh
echo "$RP_LANG" > "$INSTALL_DIR/lang"
ok "$(m "RedProxy downloaded to $INSTALL_DIR" "RedProxy загружен в $INSTALL_DIR")"

# shellcheck source=./utils/colors.sh
source "$INSTALL_DIR/utils/colors.sh"
# shellcheck source=./utils/common.sh
source "$INSTALL_DIR/utils/common.sh"
# shellcheck source=./utils/os.sh
source "$INSTALL_DIR/utils/os.sh"
load_lang

info "$(m "Configuring firewall..." "Настраиваю firewall...")"
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
ok "$(m "Firewall configured (SSH + 443/tcp allowed)" "Firewall настроен (разрешены SSH и 443/tcp)")"

info "$(m "Enabling BBR congestion control..." "Включаю управление перегрузкой BBR...")"
cat > /etc/sysctl.d/99-redproxy-bbr.conf <<'SYSCTL'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
SYSCTL
sysctl --system >/dev/null 2>&1 || true
ok "$(m "BBR enabled" "BBR включён")"

bash "$INSTALL_DIR/xray/install_xray.sh"

info "$(m "Setting up Python venv for QR rendering..." "Настраиваю Python venv для генерации QR-кодов...")"
bash "$INSTALL_DIR/utils/venv_setup.sh" "$INSTALL_DIR" || warn "$(m "venv setup skipped, will fall back to qrencode" "Настройка venv пропущена, будет использован qrencode")"

ln -sf "$INSTALL_DIR/menu.sh" /usr/local/bin/redproxy
chmod +x /usr/local/bin/redproxy
ok "$(m "Installed 'redproxy' command" "Команда 'redproxy' установлена")"

echo
echo "$(m "Select a protocol to install:" "Выберите протокол для установки:")"
echo "  1) VLESS + Reality        [$(m "ready" "готово")]"
echo "  2) VLESS + WS + TLS       [$(m "coming soon" "скоро")]"
echo "  3) VMess                  [$(m "coming soon" "скоро")]"
echo "  4) Trojan                 [$(m "coming soon" "скоро")]"
echo "  5) Hysteria2              [$(m "coming soon" "скоро")]"
echo "  6) TUIC                   [$(m "coming soon" "скоро")]"
echo "  7) WireGuard              [$(m "coming soon" "скоро")]"
read -rp "> " choice

case "$choice" in
    1)
        read -rp "$(m "Port [443]: " "Порт [443]: ")" port; port=${port:-443}
        read -rp "$(m "SNI to masquerade as [www.microsoft.com]: " "SNI для маскировки [www.microsoft.com]: ")" sni; sni=${sni:-www.microsoft.com}
        # shellcheck source=./xray/reality.sh
        source "$INSTALL_DIR/xray/reality.sh"
        reality_install "$port" "$sni"
        ;;
    *)
        warn "$(m "That protocol isn't implemented yet in v${VERSION}." "Этот протокол пока не реализован в v${VERSION}.")"
        warn "$(m "Run 'redproxy' later to install VLESS+Reality, or watch the repo for updates." "Запустите 'redproxy' позже, чтобы установить VLESS+Reality, или следите за обновлениями репозитория.")"
        ;;
esac

echo
ok "$(m "RedProxy installed. Run 'redproxy' anytime to manage clients." "RedProxy установлен. Запустите 'redproxy' в любой момент для управления клиентами.")"
