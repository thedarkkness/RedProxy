#!/usr/bin/env bash
# TUIC — planned for a future RedProxy release.
set -euo pipefail

INSTALL_DIR="/opt/redproxy"
# shellcheck source=../utils/colors.sh
source "$INSTALL_DIR/utils/colors.sh"
load_lang

tuic_install() {
    warn "$(m "TUIC is not implemented yet in this RedProxy release." "TUIC пока не реализован в этой версии RedProxy.")"
    warn "$(m "Track progress:" "Следите за обновлениями:") https://github.com/thedarkkness/RedProxy"
    return 1
}
