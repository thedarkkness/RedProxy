#!/usr/bin/env bash
# VMess — planned for a future RedProxy release.
set -euo pipefail

INSTALL_DIR="/opt/redproxy"
# shellcheck source=../utils/colors.sh
source "$INSTALL_DIR/utils/colors.sh"
load_lang

vmess_install() {
    warn "$(m "VMess is not implemented yet in this RedProxy release." "VMess пока не реализован в этой версии RedProxy.")"
    warn "$(m "Track progress:" "Следите за обновлениями:") https://github.com/thedarkkness/RedProxy"
    return 1
}
