#!/usr/bin/env bash
# Removes RedProxy, Xray-core, the systemd unit and all client data.
set -euo pipefail

INSTALL_DIR="/opt/redproxy"
# shellcheck source=./utils/colors.sh
source "$INSTALL_DIR/utils/colors.sh"
load_lang

if [[ "$EUID" -ne 0 ]]; then
    err "$(m "Run as root" "Запустите от root")"
    exit 1
fi

read -rp "$(m "This will remove RedProxy, Xray-core and all client configs. Continue? [y/N] " "Это удалит RedProxy, Xray-core и все конфиги клиентов. Продолжить? [y/N] ")" ans
[[ "$ans" =~ ^[Yy]$ ]] || { info "$(m "Aborted" "Отменено")"; exit 0; }

systemctl disable --now redproxy-xray >/dev/null 2>&1 || true
rm -f /etc/systemd/system/redproxy-xray.service
systemctl daemon-reload

rm -f /usr/local/bin/xray
rm -f /usr/local/bin/redproxy
rm -f /etc/sysctl.d/99-redproxy-bbr.conf

id -u redproxy >/dev/null 2>&1 && userdel redproxy >/dev/null 2>&1 || true

rm -rf "$INSTALL_DIR"

ok "$(m "RedProxy removed" "RedProxy удалён")"
