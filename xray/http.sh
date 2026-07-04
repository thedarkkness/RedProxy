#!/usr/bin/env bash
# HTTP proxy (username/password auth) — for using this server as a plain
# HTTP CONNECT proxy in browsers, curl, or for commercial proxy resale.
# Thin wrapper around the shared logic in xray/authproxy.sh.
set -euo pipefail

INSTALL_DIR="/opt/redproxy"
# shellcheck source=./authproxy.sh
source "$INSTALL_DIR/xray/authproxy.sh"

HTTP_TAG="http-in"
HTTP_PREFIX="http"

http_install()       { authproxy_install "http" "$HTTP_TAG" "$HTTP_PREFIX" "${1:-8080}"; }
http_add_client()    { authproxy_add_client "http" "$HTTP_TAG" "$HTTP_PREFIX" "${1:-}"; }
http_remove_client() { authproxy_remove_client "$HTTP_TAG" "$HTTP_PREFIX" "${1:-}"; }
http_list_clients()  { authproxy_list_clients "$HTTP_PREFIX"; }
http_show_qr()       { authproxy_show_qr "$HTTP_PREFIX" "${1:-}"; }
