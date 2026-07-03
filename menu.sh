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
load_lang

VERSION=$(cat "$INSTALL_DIR/VERSION" 2>/dev/null || echo "0.0.1")

show_menu() {
    local opt
    while true; do
        line
        echo -e " ${BOLD}RedProxy v${VERSION}${NC}"
        line
        echo "  1) $(m "Add Client" "Добавить клиента")"
        echo "  2) $(m "Delete Client" "Удалить клиента")"
        echo "  3) $(m "List Clients" "Список клиентов")"
        echo "  4) $(m "Show QR" "Показать QR")"
        echo "  5) $(m "Restart" "Перезапустить")"
        echo "  6) $(m "Update" "Обновить")"
        echo "  7) $(m "Backup" "Резервная копия")"
        echo "  8) $(m "Change Port" "Сменить порт")"
        echo "  0) $(m "Exit" "Выход")"
        line
        read -rp "$(m "Select: " "Выбор: ")" opt
        case "$opt" in
            1) reality_add_client ;;
            2) reality_remove_client ;;
            3) reality_list_clients ;;
            4) reality_show_qr ;;
            5) systemctl restart redproxy-xray && ok "$(m "Restarted" "Перезапущено")" ;;
            6) bash "$INSTALL_DIR/update.sh" ;;
            7) bash "$INSTALL_DIR/utils/backup.sh" ;;
            8) warn "$(m "Change Port is not implemented yet in v${VERSION}" "Смена порта пока не реализована в v${VERSION}")" ;;
            0) exit 0 ;;
            *) warn "$(m "Invalid option" "Неверный выбор")" ;;
        esac
        echo
        read -rp "$(m "Press Enter to continue..." "Нажмите Enter для продолжения...")" _
    done
}

cmd="${1:-}"
case "$cmd" in
    add)               shift; reality_add_client "${1:-}" ;;
    remove|rm|delete)  shift; reality_remove_client "${1:-}" ;;
    list|ls)           reality_list_clients ;;
    qr)                shift; reality_show_qr "${1:-}" ;;
    restart)           systemctl restart redproxy-xray && ok "$(m "Restarted" "Перезапущено")" ;;
    update)            bash "$INSTALL_DIR/update.sh" ;;
    backup)            bash "$INSTALL_DIR/utils/backup.sh" ;;
    "")                show_menu ;;
    *)                 err "$(m "Unknown command: $cmd" "Неизвестная команда: $cmd")"; exit 1 ;;
esac
