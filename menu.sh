#!/usr/bin/env bash
# RedProxy CLI / interactive menu. Installed as `redproxy` on the target
# server (symlinked to /usr/local/bin/redproxy by install.sh).
#
# Interactive:  redproxy
# Non-interactive: redproxy <add|remove|list|qr|restart|update|backup> [name]
set -euo pipefail

INSTALL_DIR="/opt/redproxy"
# shellcheck source=./utils/colors.sh
source "$INSTALL_DIR/utils/colors.sh"
# shellcheck source=./utils/common.sh
source "$INSTALL_DIR/utils/common.sh"
# shellcheck source=./xray/reality.sh
source "$INSTALL_DIR/xray/reality.sh"

VERSION=$(cat "$INSTALL_DIR/VERSION" 2>/dev/null || echo "0.0.1")

show_menu() {
    line
    echo -e " ${BOLD}RedProxy v${VERSION}${NC}"
    line
    echo "  1) Add Client"
    echo "  2) Delete Client"
    echo "  3) List Clients"
    echo "  4) Show QR"
    echo "  5) Restart"
    echo "  6) Update"
    echo "  7) Backup"
    echo "  8) Change Port"
    echo "  0) Exit"
    line
    read -rp "Select: " opt
    case "$opt" in
        1) reality_add_client ;;
        2) reality_remove_client ;;
        3) reality_list_clients ;;
        4) reality_show_qr ;;
        5) systemctl restart redproxy-xray && ok "Restarted" ;;
        6) bash "$INSTALL_DIR/update.sh" ;;
        7) bash "$INSTALL_DIR/utils/backup.sh" ;;
        8) warn "Change Port is not implemented yet in v${VERSION}" ;;
        0) exit 0 ;;
        *) warn "Invalid option" ;;
    esac
}

cmd="${1:-}"
case "$cmd" in
    add)               shift; reality_add_client "${1:-}" ;;
    remove|rm|delete)  shift; reality_remove_client "${1:-}" ;;
    list|ls)           reality_list_clients ;;
    qr)                shift; reality_show_qr "${1:-}" ;;
    restart)           systemctl restart redproxy-xray && ok "Restarted" ;;
    update)            bash "$INSTALL_DIR/update.sh" ;;
    backup)            bash "$INSTALL_DIR/utils/backup.sh" ;;
    "")                show_menu ;;
    *)                 err "Unknown command: $cmd"; exit 1 ;;
esac
