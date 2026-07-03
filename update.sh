#!/usr/bin/env bash
# Pulls the latest RedProxy scripts, refreshes Xray-core and restarts the service.
set -euo pipefail

INSTALL_DIR="/opt/redproxy"
# shellcheck source=./utils/colors.sh
source "$INSTALL_DIR/utils/colors.sh"

if [[ "$EUID" -ne 0 ]]; then
    err "Run as root"
    exit 1
fi

info "Backing up configs..."
bash "$INSTALL_DIR/utils/backup.sh"

info "Pulling latest RedProxy scripts..."
git -C "$INSTALL_DIR" pull --quiet
chmod +x "$INSTALL_DIR"/*.sh "$INSTALL_DIR"/xray/*.sh "$INSTALL_DIR"/wireguard/*.sh "$INSTALL_DIR"/utils/*.sh

info "Updating Xray-core..."
bash "$INSTALL_DIR/xray/install_xray.sh"

systemctl restart redproxy-xray
ok "RedProxy updated and restarted"
