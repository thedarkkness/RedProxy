#!/usr/bin/env bash
# WireGuard — planned for a future RedProxy release.
set -euo pipefail

INSTALL_DIR="/opt/redproxy"
# shellcheck source=../utils/colors.sh
source "$INSTALL_DIR/utils/colors.sh"

wireguard_install() {
    warn "WireGuard is not implemented yet in this RedProxy release."
    warn "Track progress: https://github.com/thedarkkness/RedProxy"
    return 1
}
