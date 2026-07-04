#!/usr/bin/env bash
# Creates the Python venv used for QR-code rendering (utils/qr.py).
# Falls back silently to qrencode if python3/venv isn't available.
set -euo pipefail

INSTALL_DIR="${1:-/opt/redproxy}"

if ! command -v python3 >/dev/null 2>&1; then
    echo "[!] python3 not found, skipping QR venv setup (qrencode fallback will be used)"
    exit 0
fi

python3 -m venv "$INSTALL_DIR/.venv"
"$INSTALL_DIR/.venv/bin/pip" install --quiet --upgrade pip
"$INSTALL_DIR/.venv/bin/pip" install --quiet -r "$INSTALL_DIR/requirements.txt"
