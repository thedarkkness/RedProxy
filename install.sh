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

# Re-running the one-liner is also how users pull updates or add a second
# protocol, but redoing OS/dependency setup every time is unnecessary
# noise for someone who just wants to manage what's already there.
if [[ -d "$INSTALL_DIR/.git" ]]; then
    echo "$(m "RedProxy is already installed on this server." "RedProxy уже установлен на этом сервере.")"
    echo "  1) $(m "Manage existing installation (clients, status, updates...)" "Управление текущей установкой (клиенты, статус, обновления...)")"
    echo "  2) $(m "Install another protocol / update RedProxy" "Установить ещё один протокол / обновить RedProxy")"
    read -rp "> " existing_choice
    echo
    if [[ "$existing_choice" == "1" ]]; then
        echo "$RP_LANG" > "$INSTALL_DIR/lang"
        exec bash "$INSTALL_DIR/menu.sh"
    fi
fi

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

if [[ -d "$INSTALL_DIR/.git" ]]; then
    info "$(m "Updating existing RedProxy install (configs and clients are preserved)..." "Обновляю существующую установку RedProxy (конфиги и клиенты сохраняются)...")"
    # Scripts are committed without the executable bit (this repo is
    # developed on Windows, where git doesn't track file mode at all).
    # The chmod +x below then looks like a local edit to git on Linux
    # (core.fileMode defaults to true there), and `git pull` refuses to
    # overwrite files it thinks have uncommitted changes. Telling git to
    # ignore file-mode diffs on this checkout fixes that permanently.
    git -C "$INSTALL_DIR" config core.fileMode false
    git -C "$INSTALL_DIR" pull --quiet
else
    info "$(m "Fetching RedProxy v${VERSION}..." "Загружаю RedProxy v${VERSION}...")"
    rm -rf "$INSTALL_DIR"
    git clone --quiet --depth 1 "$REPO_URL" "$INSTALL_DIR"
    git -C "$INSTALL_DIR" config core.fileMode false
fi
chmod +x "$INSTALL_DIR"/*.sh "$INSTALL_DIR"/xray/*.sh "$INSTALL_DIR"/wireguard/*.sh "$INSTALL_DIR"/utils/*.sh
echo "$RP_LANG" > "$INSTALL_DIR/lang"
ok "$(m "RedProxy ready in $INSTALL_DIR" "RedProxy готов в $INSTALL_DIR")"

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
echo "  2) SOCKS5 Proxy           [$(m "ready" "готово")]"
echo "  3) HTTP Proxy             [$(m "ready" "готово")]"
echo "  4) VLESS + WS + TLS       [$(m "coming soon" "скоро")]"
echo "  5) VMess                  [$(m "coming soon" "скоро")]"
echo "  6) Trojan                 [$(m "coming soon" "скоро")]"
echo "  7) Hysteria2              [$(m "coming soon" "скоро")]"
echo "  8) TUIC                   [$(m "coming soon" "скоро")]"
echo "  9) WireGuard              [$(m "coming soon" "скоро")]"
read -rp "> " choice

case "$choice" in
    1)
        # shellcheck source=./xray/reality.sh
        source "$INSTALL_DIR/xray/reality.sh"
        if inbound_installed "$REALITY_TAG"; then
            info "$(m "VLESS+Reality is already installed — adding a new client instead." "VLESS+Reality уже установлен — добавляю нового клиента.")"
            reality_add_client
        else
            while true; do
                read -rp "$(m "Port [443]: " "Порт [443]: ")" port; port=${port:-443}
                if port_in_use "$port"; then
                    warn "$(m "Port $port is already in use on this server:" "Порт $port уже занят на этом сервере:")"
                    port_owner "$port"
                    warn "$(m "Pick a different port (or stop whatever's using it first)." "Выберите другой порт (или сначала остановите то, что его занимает).")"
                    continue
                fi
                break
            done
            read -rp "$(m "SNI to masquerade as [www.microsoft.com]: " "SNI для маскировки [www.microsoft.com]: ")" sni; sni=${sni:-www.microsoft.com}
            reality_install "$port" "$sni"
        fi
        ;;
    2)
        # shellcheck source=./xray/socks5.sh
        source "$INSTALL_DIR/xray/socks5.sh"
        if inbound_installed "$SOCKS5_TAG"; then
            info "$(m "SOCKS5 is already installed — adding a new client instead." "SOCKS5 уже установлен — добавляю нового клиента.")"
            socks5_add_client
        else
            while true; do
                read -rp "$(m "Port [1080]: " "Порт [1080]: ")" port; port=${port:-1080}
                if port_in_use "$port"; then
                    warn "$(m "Port $port is already in use on this server:" "Порт $port уже занят на этом сервере:")"
                    port_owner "$port"
                    warn "$(m "Pick a different port (or stop whatever's using it first)." "Выберите другой порт (или сначала остановите то, что его занимает).")"
                    continue
                fi
                break
            done
            socks5_install "$port"
        fi
        ;;
    3)
        # shellcheck source=./xray/http.sh
        source "$INSTALL_DIR/xray/http.sh"
        if inbound_installed "$HTTP_TAG"; then
            info "$(m "HTTP proxy is already installed — adding a new client instead." "HTTP-прокси уже установлен — добавляю нового клиента.")"
            http_add_client
        else
            while true; do
                read -rp "$(m "Port [8080]: " "Порт [8080]: ")" port; port=${port:-8080}
                if port_in_use "$port"; then
                    warn "$(m "Port $port is already in use on this server:" "Порт $port уже занят на этом сервере:")"
                    port_owner "$port"
                    warn "$(m "Pick a different port (or stop whatever's using it first)." "Выберите другой порт (или сначала остановите то, что его занимает).")"
                    continue
                fi
                break
            done
            http_install "$port"
        fi
        ;;
    *)
        warn "$(m "That protocol isn't implemented yet in v${VERSION}." "Этот протокол пока не реализован в v${VERSION}.")"
        warn "$(m "Run 'redproxy' later to manage installed protocols, or run install.sh again to add another one." "Запустите 'redproxy' позже для управления установленными протоколами, либо запустите install.sh снова, чтобы добавить ещё один.")"
        ;;
esac

echo
ok "$(m "Done. Run 'redproxy' anytime to manage clients, or run install.sh again to add another protocol." "Готово. Запустите 'redproxy' в любой момент для управления клиентами, либо запустите install.sh снова, чтобы добавить ещё один протокол.")"
