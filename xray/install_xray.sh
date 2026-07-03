#!/usr/bin/env bash
# Installs/updates the Xray-core binary, the dedicated system user and the
# redproxy-xray systemd unit. Safe to re-run (used by both install.sh and
# update.sh).
set -euo pipefail

INSTALL_DIR="/opt/redproxy"
XRAY_BIN="/usr/local/bin/xray"

# shellcheck source=../utils/colors.sh
source "$INSTALL_DIR/utils/colors.sh"
# shellcheck source=../utils/os.sh
source "$INSTALL_DIR/utils/os.sh"

install_xray_binary() {
    detect_arch
    info "Fetching latest Xray-core release..."

    local latest
    latest=$(curl -fsSL https://api.github.com/repos/XTLS/Xray-core/releases/latest | jq -r '.tag_name')
    if [[ -z "$latest" || "$latest" == "null" ]]; then
        err "Could not determine the latest Xray-core version"
        exit 1
    fi

    local url="https://github.com/XTLS/Xray-core/releases/download/${latest}/Xray-linux-${ARCH}.zip"
    local tmp
    tmp=$(mktemp -d)

    info "Downloading Xray-core ${latest} (linux-${ARCH})..."
    curl -fsSL "$url" -o "$tmp/xray.zip"
    unzip -oq "$tmp/xray.zip" -d "$tmp"
    install -m 755 "$tmp/xray" "$XRAY_BIN"
    setcap 'cap_net_bind_service=+ep' "$XRAY_BIN" 2>/dev/null || warn "setcap unavailable, xray may need CAP_NET_BIND_SERVICE from systemd only"
    rm -rf "$tmp"

    ok "Xray-core ${latest} installed to $XRAY_BIN"
}

create_redproxy_user() {
    if ! id -u redproxy >/dev/null 2>&1; then
        useradd --system --no-create-home --shell /usr/sbin/nologin redproxy
        ok "Created system user 'redproxy'"
    fi
}

install_systemd_unit() {
    install -m 644 "$INSTALL_DIR/templates/xray.service.tpl" /etc/systemd/system/redproxy-xray.service
    systemctl daemon-reload
    ok "systemd unit installed (redproxy-xray.service)"
}

install_xray_binary
create_redproxy_user
install_systemd_unit
