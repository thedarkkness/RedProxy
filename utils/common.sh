#!/usr/bin/env bash
# Shared helper functions used by the installer and protocol scripts.

XRAY_BIN="${XRAY_BIN:-/usr/local/bin/xray}"

require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        err "This script must be run as root. Try: sudo bash $0"
        exit 1
    fi
}

gen_uuid() {
    if [[ -x "$XRAY_BIN" ]]; then
        "$XRAY_BIN" uuid
    else
        cat /proc/sys/kernel/random/uuid
    fi
}

gen_short_id() {
    openssl rand -hex 8
}

public_ip() {
    curl -fsSL4 --max-time 5 https://api.ipify.org 2>/dev/null \
        || curl -fsSL4 --max-time 5 https://ifconfig.me 2>/dev/null \
        || hostname -I | awk '{print $1}'
}

# True if something is already listening on $1, on any interface. Xray
# always binds 0.0.0.0, so a listener on 127.0.0.1:<port> is still a
# conflict, not just one on the public interface.
port_in_use() {
    local port="$1"
    if command -v ss >/dev/null 2>&1; then
        ss -H -ltn 2>/dev/null | awk '{print $4}' | grep -qE ":${port}\$"
    else
        (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null && { exec 3<&- 3>&-; return 0; } || return 1
    fi
}

# What's holding a port, for the warning message (process name/PID if we
# can see it, otherwise just confirmation that it's occupied).
port_owner() {
    local port="$1"
    if command -v ss >/dev/null 2>&1; then
        ss -H -ltnp 2>/dev/null | awk -v p=":${port}\$" '$4 ~ p {print}'
    fi
}

render_qr() {
    local data="$1"
    local venv_py="$INSTALL_DIR/.venv/bin/python"
    if [[ -x "$venv_py" ]]; then
        "$venv_py" "$INSTALL_DIR/utils/qr.py" "$data"
    elif command -v qrencode >/dev/null 2>&1; then
        qrencode -t ANSIUTF8 "$data"
    else
        warn "No QR renderer available (venv and qrencode both missing)"
    fi
}
