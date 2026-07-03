#!/usr/bin/env bash
# Trojan — planned for a future RedProxy release.
set -euo pipefail

INSTALL_DIR="/opt/redproxy"
# shellcheck source=../utils/colors.sh
source "$INSTALL_DIR/utils/colors.sh"

trojan_install() {
    warn "Trojan is not implemented yet in this RedProxy release."
    warn "Track progress: https://github.com/thedarkkness/RedProxy"
    return 1
}
