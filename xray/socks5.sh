#!/usr/bin/env bash
# SOCKS5 proxy (username/password auth) — for using this server as a plain
# proxy in apps like Telegram/WhatsApp, browsers, curl, or for commercial
# proxy resale. Thin wrapper around the shared logic in xray/authproxy.sh.
set -euo pipefail

INSTALL_DIR="/opt/redproxy"
# shellcheck source=./authproxy.sh
source "$INSTALL_DIR/xray/authproxy.sh"

SOCKS5_TAG="socks5-in"
SOCKS5_PREFIX="socks5"

socks5_install()       { authproxy_install "socks" "$SOCKS5_TAG" "$SOCKS5_PREFIX" "${1:-1080}"; }
socks5_add_client()    { authproxy_add_client "socks" "$SOCKS5_TAG" "$SOCKS5_PREFIX" "${1:-}"; }
socks5_remove_client() { authproxy_remove_client "$SOCKS5_TAG" "$SOCKS5_PREFIX" "${1:-}"; }
socks5_list_clients()  { authproxy_list_clients "$SOCKS5_PREFIX"; }
socks5_show_qr()       { authproxy_show_qr "$SOCKS5_PREFIX" "${1:-}"; }
