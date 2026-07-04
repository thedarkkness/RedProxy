#!/usr/bin/env bash
# Pulls the latest RedProxy scripts, refreshes Xray-core and restarts the service.
set -euo pipefail

INSTALL_DIR="/opt/redproxy"
# shellcheck source=./utils/colors.sh
source "$INSTALL_DIR/utils/colors.sh"
load_lang

if [[ "$EUID" -ne 0 ]]; then
    err "$(m "Run as root" "Запустите от root")"
    exit 1
fi

info "$(m "Backing up configs..." "Резервное копирование конфигов...")"
bash "$INSTALL_DIR/utils/backup.sh"

info "$(m "Pulling latest RedProxy scripts..." "Загружаю последнюю версию скриптов RedProxy...")"
# See install.sh for why: scripts are committed without the executable
# bit, so chmod +x below looks like a local edit to git on Linux and
# blocks the pull unless file-mode diffs are ignored on this checkout.
git -C "$INSTALL_DIR" config core.fileMode false
git -C "$INSTALL_DIR" pull --quiet
chmod +x "$INSTALL_DIR"/*.sh "$INSTALL_DIR"/xray/*.sh "$INSTALL_DIR"/wireguard/*.sh "$INSTALL_DIR"/utils/*.sh

info "$(m "Updating Xray-core..." "Обновляю Xray-core...")"
bash "$INSTALL_DIR/xray/install_xray.sh"

systemctl restart redproxy-xray
ok "$(m "RedProxy updated and restarted" "RedProxy обновлён и перезапущен")"
