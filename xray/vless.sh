#!/usr/bin/env bash
# VLESS + WS + TLS — planned for a future RedProxy release.
set -euo pipefail

INSTALL_DIR="/opt/redproxy"
# shellcheck source=../utils/colors.sh
source "$INSTALL_DIR/utils/colors.sh"
load_lang

vless_ws_install() {
    warn "$(m "VLESS + WS + TLS is not implemented yet in this RedProxy release." "VLESS + WS + TLS пока не реализован в этой версии RedProxy.")"
    warn "$(m "Track progress:" "Следите за обновлениями:") https://github.com/thedarkkness/RedProxy"
    return 1
}
