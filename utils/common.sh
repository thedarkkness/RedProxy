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

# Opens <port>/tcp (and /udp too when $2 is "true") in whichever firewall
# is active. install.sh's own pass only opens 443/tcp + SSH up front
# (the Reality default) before any port is actually chosen — this covers
# whatever port a protocol ends up using, including a custom Reality port
# or SOCKS5/HTTP, so a client isn't left unable to reach a service that's
# listening just fine locally.
open_firewall_port() {
    local port="$1" udp="${2:-false}"
    if command -v ufw >/dev/null 2>&1; then
        ufw allow "${port}/tcp" >/dev/null 2>&1 || true
        [[ "$udp" == "true" ]] && { ufw allow "${port}/udp" >/dev/null 2>&1 || true; }
        ufw reload >/dev/null 2>&1 || true
    elif command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port="${port}/tcp" >/dev/null 2>&1 || true
        [[ "$udp" == "true" ]] && { firewall-cmd --permanent --add-port="${port}/udp" >/dev/null 2>&1 || true; }
        firewall-cmd --reload >/dev/null 2>&1 || true
    fi
}

# Xray's config.json holds one inbound array shared by every installed
# protocol (Reality, SOCKS5, HTTP, ...), each tagged so it can be found and
# edited independently. This creates the empty skeleton once; each
# protocol's *_install() then appends its own inbound instead of
# overwriting the file, so installing a second protocol doesn't destroy
# the first one's clients.
ensure_config_skeleton() {
    local cfg="$INSTALL_DIR/configs/config.json"
    mkdir -p "$INSTALL_DIR/configs" "$INSTALL_DIR/clients"
    if [[ ! -f "$cfg" ]]; then
        jq -n '{log:{loglevel:"warning"}, inbounds: [], outbounds: [{protocol:"freedom",tag:"direct"},{protocol:"blackhole",tag:"block"}]}' > "$cfg"
    fi
}

# True if an inbound with this tag is already in config.json.
inbound_installed() {
    local tag="$1" cfg="$INSTALL_DIR/configs/config.json"
    [[ -f "$cfg" ]] && jq -e --arg tag "$tag" '.inbounds[]? | select(.tag == $tag)' "$cfg" >/dev/null 2>&1
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
