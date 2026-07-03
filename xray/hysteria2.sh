#!/usr/bin/env bash
# Hysteria2 — planned for a future RedProxy release.
set -euo pipefail

INSTALL_DIR="/opt/redproxy"
# shellcheck source=../utils/colors.sh
source "$INSTALL_DIR/utils/colors.sh"
load_lang

hysteria2_install() {
    warn "$(m "Hysteria2 is not implemented yet in this RedProxy release." "Hysteria2 пока не реализован в этой версии RedProxy.")"
    warn "$(m "Track progress:" "Следите за обновлениями:") https://github.com/thedarkkness/RedProxy"
    return 1
}
