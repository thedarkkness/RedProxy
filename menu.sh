#!/usr/bin/env bash
# RedProxy CLI / interactive menu. Installed as `redproxy` on the target
# server (symlinked to /usr/local/bin/redproxy by install.sh).
#
# Interactive:  redproxy
# Non-interactive: redproxy <add|remove|list|qr|restart|update|backup> [name]
#
# Several protocols (Reality, SOCKS5, HTTP) can be installed at once, each
# as its own tagged inbound in the same config.json. Add/Delete/QR ask
# which protocol to act on when more than one is installed; List shows
# every installed protocol's clients together.
set -euo pipefail

INSTALL_DIR="/opt/redproxy"
# shellcheck source=./utils/colors.sh
source "$INSTALL_DIR/utils/colors.sh"
# shellcheck source=./utils/common.sh
source "$INSTALL_DIR/utils/common.sh"
# shellcheck source=./xray/reality.sh
source "$INSTALL_DIR/xray/reality.sh"
# shellcheck source=./xray/socks5.sh
source "$INSTALL_DIR/xray/socks5.sh"
# shellcheck source=./xray/http.sh
source "$INSTALL_DIR/xray/http.sh"
load_lang

VERSION=$(cat "$INSTALL_DIR/VERSION" 2>/dev/null || echo "0.0.1")

# Tab-separated "tag<TAB>label<TAB>prefix" for every currently installed
# protocol. The `|| true` guards keep a "not installed" (non-zero) result
# from tripping `set -e`.
list_installed_protocols() {
    { inbound_installed "$REALITY_TAG" && printf '%s\t%s\t%s\n' "$REALITY_TAG" "VLESS+Reality" "reality"; } || true
    { inbound_installed "$SOCKS5_TAG" && printf '%s\t%s\t%s\n' "$SOCKS5_TAG" "SOCKS5" "socks5"; } || true
    { inbound_installed "$HTTP_TAG" && printf '%s\t%s\t%s\n' "$HTTP_TAG" "HTTP" "http"; } || true
}

# Prints one "tag<TAB>label<TAB>prefix" row: the only installed protocol,
# or an interactively-chosen one if several are installed. Empty output
# (with a printed error) if none are installed yet.
pick_protocol() {
    local rows count
    rows=$(list_installed_protocols)
    if [[ -z "$rows" ]]; then
        err "$(m "No protocol installed yet. Run install.sh again to add one." "Протокол ещё не установлен. Запустите install.sh снова, чтобы добавить.")"
        return 1
    fi

    count=$(echo "$rows" | wc -l)
    if [[ "$count" -eq 1 ]]; then
        echo "$rows"
        return 0
    fi

    echo "$(m "Which protocol?" "Какой протокол?")" >&2
    local i=1 label
    while IFS=$'\t' read -r _ label _; do
        echo "  $i) $label" >&2
        i=$((i+1))
    done <<< "$rows"
    local sel
    echo -n "> " >&2
    read -r sel
    echo "$rows" | sed -n "${sel}p"
}

# dispatch <add|remove|qr> [name] — resolves which protocol to act on via
# pick_protocol, then calls that protocol's matching *_add_client /
# *_remove_client / *_show_qr function.
dispatch() {
    local action="$1" name="${2:-}" row tag
    row=$(pick_protocol) || return 0
    [[ -n "$row" ]] || return 0
    IFS=$'\t' read -r tag _ _ <<< "$row"
    case "${tag}:${action}" in
        "${REALITY_TAG}:add")    reality_add_client "$name" ;;
        "${REALITY_TAG}:remove") reality_remove_client "$name" ;;
        "${REALITY_TAG}:qr")     reality_show_qr "$name" ;;
        "${SOCKS5_TAG}:add")     socks5_add_client "$name" ;;
        "${SOCKS5_TAG}:remove")  socks5_remove_client "$name" ;;
        "${SOCKS5_TAG}:qr")      socks5_show_qr "$name" ;;
        "${HTTP_TAG}:add")       http_add_client "$name" ;;
        "${HTTP_TAG}:remove")    http_remove_client "$name" ;;
        "${HTTP_TAG}:qr")        http_show_qr "$name" ;;
    esac
}

list_all_clients() {
    local any=0
    if inbound_installed "$REALITY_TAG"; then
        echo "-- VLESS+Reality --"
        reality_list_clients
        any=1
    fi
    if inbound_installed "$SOCKS5_TAG"; then
        echo "-- SOCKS5 --"
        socks5_list_clients
        any=1
    fi
    if inbound_installed "$HTTP_TAG"; then
        echo "-- HTTP --"
        http_list_clients
        any=1
    fi
    [[ $any -eq 1 ]] || err "$(m "No protocol installed yet. Run install.sh again to add one." "Протокол ещё не установлен. Запустите install.sh снова, чтобы добавить.")"
}

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
            1) dispatch add ;;
            2) dispatch remove ;;
            3) list_all_clients ;;
            4) dispatch qr ;;
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
    add)               shift; dispatch add "${1:-}" ;;
    remove|rm|delete)  shift; dispatch remove "${1:-}" ;;
    list|ls)           list_all_clients ;;
    qr)                shift; dispatch qr "${1:-}" ;;
    restart)           systemctl restart redproxy-xray && ok "$(m "Restarted" "Перезапущено")" ;;
    update)            bash "$INSTALL_DIR/update.sh" ;;
    backup)            bash "$INSTALL_DIR/utils/backup.sh" ;;
    "")                show_menu ;;
    *)                 err "$(m "Unknown command: $cmd" "Неизвестная команда: $cmd")"; exit 1 ;;
esac
