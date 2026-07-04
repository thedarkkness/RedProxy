#!/usr/bin/env bash
# Live traffic status, roughly analogous to `wg show`. TCP-based proxies
# (VLESS/SOCKS5/HTTP) don't have WireGuard's periodic-handshake concept,
# so "is it alive" is shown instead as: the systemd service state, plus a
# traffic counter for the one client/protocol you pick that's marked
# active (●) when it's moved since the last refresh a couple seconds ago.
#
# Uses Xray's built-in Stats API (a loopback-only dokodemo-door inbound +
# the stats/policy config blocks) rather than anything invented — see
# https://xtls.github.io/en/document/level-2/traffic_stats.html
set -euo pipefail

INSTALL_DIR="/opt/redproxy"
CONFIG_FILE="$INSTALL_DIR/configs/config.json"
CLIENTS_DIR="$INSTALL_DIR/clients"
XRAY_BIN="/usr/local/bin/xray"
STATS_API="127.0.0.1:10085"
STATS_TAG="api"

# shellcheck source=../utils/colors.sh
source "$INSTALL_DIR/utils/colors.sh"
# shellcheck source=../utils/common.sh
source "$INSTALL_DIR/utils/common.sh"
load_lang

# Idempotent: adds the api/stats/policy blocks and the loopback API
# inbound to config.json if they aren't there yet (covers installs made
# before this feature existed), then restarts Xray once to pick it up.
ensure_stats_enabled() {
    ensure_config_skeleton

    if jq -e '.api' "$CONFIG_FILE" >/dev/null 2>&1; then
        return 0
    fi

    if port_in_use 10085; then
        warn "$(m "Port 10085 (local stats API) is already in use, traffic stats won't be available." "Порт 10085 (локальный API статистики) уже занят, статистика трафика будет недоступна.")"
        return 1
    fi

    jq --arg tag "$STATS_TAG" '
        .api = {tag: $tag, services: ["StatsService"]}
        | .stats = {}
        | .policy = {
            levels: {"0": {statsUserUplink: true, statsUserDownlink: true}},
            system: {statsInboundUplink: true, statsInboundDownlink: true}
          }
        | .inbounds += [{tag: $tag, listen: "127.0.0.1", port: 10085, protocol: "dokodemo-door", settings: {address: "127.0.0.1"}}]
        | .routing = ((.routing // {rules: []}) | .rules += [{type: "field", inboundTag: [$tag], outboundTag: $tag}])
    ' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

    systemctl restart redproxy-xray
    sleep 1
    ok "$(m "Traffic stats enabled" "Статистика трафика включена")"
}

human_bytes() {
    awk -v b="${1:-0}" 'BEGIN {
        split("B KB MB GB TB", units, " ")
        i = 1
        while (b >= 1024 && i < 5) { b /= 1024; i++ }
        printf "%.1f %s", b, units[i]
    }'
}

# Coerces anything that isn't a plain non-negative integer (empty output,
# "null", a stray error message from the API) to "0" — arithmetic tests
# like `-gt` try to evaluate a non-numeric string as a variable name
# under `set -u`, which crashes instead of comparing.
to_int() {
    [[ "$1" =~ ^[0-9]+$ ]] && echo "$1" || echo "0"
}

stats_query() {
    "$XRAY_BIN" api statsquery --server="$STATS_API" 2>/dev/null || echo '{"stat":[]}'
}

stat_value() {
    # stat_value <json> <exact stat name>
    echo "$1" | jq -r --arg n "$2" '(.stat // [])[]? | select(.name == $n) | .value' 2>/dev/null | head -1
}

# Tab-separated "kind<TAB>id<TAB>label" for every trackable target: one
# row per Reality client, plus one aggregate row each for SOCKS5/HTTP
# (Xray doesn't reliably expose per-account stats for those, only
# per-inbound totals, so that's the most specific thing we can offer).
list_status_targets() {
    local f name
    if inbound_installed "$REALITY_TAG"; then
        for f in "$CLIENTS_DIR/${REALITY_PREFIX}-"*.json; do
            [[ -e "$f" ]] || continue
            name=$(jq -r '.name' "$f")
            printf 'reality\t%s\tVLESS+Reality — %s\n' "$name" "$name"
        done
    fi
    if inbound_installed "$SOCKS5_TAG"; then
        printf 'socks5\tall\tSOCKS5 (%s)\n' "$(m "all clients" "все клиенты")"
    fi
    if inbound_installed "$HTTP_TAG"; then
        printf 'http\tall\tHTTP (%s)\n' "$(m "all clients" "все клиенты")"
    fi
}

# Prints one "kind<TAB>id<TAB>label" row: the only target, or an
# interactively-chosen one if there's more than one. Empty output (with a
# printed error) if nothing is installed yet.
pick_status_target() {
    local rows count
    rows=$(list_status_targets)
    if [[ -z "$rows" ]]; then
        err "$(m "No protocol installed yet. Run install.sh again to add one." "Протокол ещё не установлен. Запустите install.sh снова, чтобы добавить.")"
        return 1
    fi

    count=$(echo "$rows" | wc -l)
    if [[ "$count" -eq 1 ]]; then
        echo "$rows"
        return 0
    fi

    echo "$(m "Which client/config do you want to watch?" "За каким клиентом/конфигом следить?")" >&2
    local i=1 label
    while IFS=$'\t' read -r _ _ label; do
        echo "  $i) $label" >&2
        i=$((i+1))
    done <<< "$rows"
    local sel
    echo -n "> " >&2
    read -r sel
    echo "$rows" | sed -n "${sel}p"
}

redproxy_status() {
    ensure_stats_enabled || return 1

    local row kind id label
    row=$(pick_status_target) || return 1
    [[ -n "$row" ]] || return 1
    IFS=$'\t' read -r kind id label <<< "$row"

    local stat_down stat_up
    case "$kind" in
        reality) stat_down="user>>>${id}>>>traffic>>>downlink";       stat_up="user>>>${id}>>>traffic>>>uplink" ;;
        socks5)  stat_down="inbound>>>${SOCKS5_TAG}>>>traffic>>>downlink"; stat_up="inbound>>>${SOCKS5_TAG}>>>traffic>>>uplink" ;;
        http)    stat_down="inbound>>>${HTTP_TAG}>>>traffic>>>downlink";   stat_up="inbound>>>${HTTP_TAG}>>>traffic>>>uplink" ;;
    esac

    echo "$(m "Auto-refreshing — press any key to go back to the menu." "Автообновление — нажмите любую клавишу для возврата в меню.")"

    local prev_down=0 prev_up=0
    while true; do
        clear
        local svc_state json down up mark
        svc_state=$(systemctl is-active redproxy-xray 2>/dev/null || echo "unknown")
        json=$(stats_query)
        down=$(to_int "$(stat_value "$json" "$stat_down")")
        up=$(to_int "$(stat_value "$json" "$stat_up")")
        mark=" "
        [[ "$down" -gt "$prev_down" || "$up" -gt "$prev_up" ]] && mark="${GREEN}●${NC}"

        line
        echo -e " ${BOLD}$(m "RedProxy — Live Status" "RedProxy — статус в реальном времени")${NC}"
        line
        printf " %s: %s\n" "$(m "Service" "Сервис")" "$svc_state"
        printf " %s: %s\n" "$(m "Watching" "Отслеживается")" "$label"
        line
        printf "  %b ↓ %-10s ↑ %-10s\n" "$mark" "$(human_bytes "$down")" "$(human_bytes "$up")"
        line
        echo "$(m "● = traffic moved since last refresh. Press any key to go back." "● = трафик изменился с прошлого обновления. Нажмите любую клавишу для возврата.")"

        prev_down=$down; prev_up=$up
        if read -rsn1 -t 2 _; then
            break
        fi
    done
}
