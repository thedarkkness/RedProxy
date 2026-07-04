#!/usr/bin/env bash
# Archives configs and client data so they can be restored after a reinstall.
set -euo pipefail

INSTALL_DIR="/opt/redproxy"
# shellcheck source=./colors.sh
source "$INSTALL_DIR/utils/colors.sh"
load_lang

BACKUP_DIR="$INSTALL_DIR/backups"
mkdir -p "$BACKUP_DIR"

stamp=$(date +%Y%m%d-%H%M%S)
archive="$BACKUP_DIR/redproxy-backup-${stamp}.tar.gz"

tar -czf "$archive" -C "$INSTALL_DIR" configs clients 2>/dev/null || true
ok "$(m "Backup saved to $archive" "Резервная копия сохранена: $archive")"
