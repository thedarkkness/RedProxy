#!/usr/bin/env bash
# Trojan — planned for a future RedProxy release.
set -euo pipefail

INSTALL_DIR="/opt/redproxy"
# shellcheck source=../utils/colors.sh
source "$INSTALL_DIR/utils/colors.sh"
load_lang

trojan_install() {
    warn "$(m "Trojan is not implemented yet in this RedProxy release." "Trojan пока не реализован в этой версии RedProxy.")"
    warn "$(m "Track progress:" "Следите за обновлениями:") https://github.com/thedarkkness/RedProxy"
    return 1
}
