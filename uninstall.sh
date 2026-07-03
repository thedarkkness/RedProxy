#!/usr/bin/env bash
# Removes RedProxy, Xray-core, the systemd unit and all client data.
set -euo pipefail

INSTALL_DIR="/opt/redproxy"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "$*"; }
ok()   { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }

if [[ "$EUID" -ne 0 ]]; then
    echo -e "${RED}[✗]${NC} Run as root"
    exit 1
fi

read -rp "This will remove RedProxy, Xray-core and all client configs. Continue? [y/N] " ans
[[ "$ans" =~ ^[Yy]$ ]] || { info "Aborted"; exit 0; }

systemctl disable --now redproxy-xray >/dev/null 2>&1 || true
rm -f /etc/systemd/system/redproxy-xray.service
systemctl daemon-reload

rm -f /usr/local/bin/xray
rm -f /usr/local/bin/redproxy
rm -f /etc/sysctl.d/99-redproxy-bbr.conf

id -u redproxy >/dev/null 2>&1 && userdel redproxy >/dev/null 2>&1 || true

rm -rf "$INSTALL_DIR"

ok "RedProxy removed"
