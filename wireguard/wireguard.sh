#!/usr/bin/env bash
# WireGuard — planned for a future RedProxy release.
set -euo pipefail

INSTALL_DIR="/opt/redproxy"
# shellcheck source=../utils/colors.sh
source "$INSTALL_DIR/utils/colors.sh"
load_lang

wireguard_install() {
    warn "$(m "WireGuard is not implemented yet in this RedProxy release." "WireGuard пока не реализован в этой версии RedProxy.")"
    warn "$(m "Track progress:" "Следите за обновлениями:") https://github.com/thedarkkness/RedProxy"
    return 1
}
