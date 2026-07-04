#!/usr/bin/env bash
# Live traffic status, roughly analogous to `wg show`. TCP-based proxies
# (VLESS/SOCKS5/HTTP) don't have WireGuard's periodic-handshake concept,
# so "is it alive" is shown instead as: the systemd service state, plus a
# per-client/per-protocol traffic counter that's marked active (●) when it
# has moved up since the last refresh a couple of seconds ago.
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

stats_query() {
    "$XRAY_BIN" api statsquery --server="$STATS_API" 2>/dev/null || echo '{"stat":[]}'
}

stat_value() {
    # stat_value <json> <exact stat name>
    echo "$1" | jq -r --arg n "$2" '(.stat // [])[] | select(.name == $n) | .value' 2>/dev/null | head -1
}

redproxy_status() {
    ensure_stats_enabled || return 1

    local -A prev
    echo "$(m "Auto-refreshing — press any key to go back to the menu." "Автообновление — нажмите любую клавишу для возврата в меню.")"

    while true; do
        clear
        local svc_state
        svc_state=$(systemctl is-active redproxy-xray 2>/dev/null || echo "unknown")

        line
        echo -e " ${BOLD}$(m "RedProxy — Live Status" "RedProxy — статус в реальном времени")${NC}"
        line
        printf " %s: %s\n" "$(m "Service" "Сервис")" "$svc_state"
        line

        local json any=0
        json=$(stats_query)

        if inbound_installed "$REALITY_TAG"; then
            any=1
            echo "-- VLESS+Reality --"
            local f name down up dkey ukey mark
            for f in "$CLIENTS_DIR/${REALITY_PREFIX}-"*.json; do
                [[ -e "$f" ]] || continue
                name=$(jq -r '.name' "$f")
                down=$(stat_value "$json" "user>>>${name}>>>traffic>>>downlink"); down=${down:-0}
                up=$(stat_value "$json" "user>>>${name}>>>traffic>>>uplink"); up=${up:-0}
                dkey="r_${name}_d"; ukey="r_${name}_u"
                mark=" "
                [[ "${down}" -gt "${prev[$dkey]:-0}" || "${up}" -gt "${prev[$ukey]:-0}" ]] && mark="${GREEN}●${NC}"
                printf "  %b %-16s ↓ %-10s ↑ %-10s\n" "$mark" "$name" "$(human_bytes "$down")" "$(human_bytes "$up")"
                prev[$dkey]=$down; prev[$ukey]=$up
            done
        fi

        if inbound_installed "$SOCKS5_TAG"; then
            any=1
            echo "-- SOCKS5 --"
            local down up mark
            down=$(stat_value "$json" "inbound>>>${SOCKS5_TAG}>>>traffic>>>downlink"); down=${down:-0}
            up=$(stat_value "$json" "inbound>>>${SOCKS5_TAG}>>>traffic>>>uplink"); up=${up:-0}
            mark=" "
            [[ "${down}" -gt "${prev[s_d]:-0}" || "${up}" -gt "${prev[s_u]:-0}" ]] && mark="${GREEN}●${NC}"
            printf "  %b %-16s ↓ %-10s ↑ %-10s\n" "$mark" "$(m "all clients" "все клиенты")" "$(human_bytes "$down")" "$(human_bytes "$up")"
            prev[s_d]=$down; prev[s_u]=$up
        fi

        if inbound_installed "$HTTP_TAG"; then
            any=1
            echo "-- HTTP --"
            local down up mark
            down=$(stat_value "$json" "inbound>>>${HTTP_TAG}>>>traffic>>>downlink"); down=${down:-0}
            up=$(stat_value "$json" "inbound>>>${HTTP_TAG}>>>traffic>>>uplink"); up=${up:-0}
            mark=" "
            [[ "${down}" -gt "${prev[h_d]:-0}" || "${up}" -gt "${prev[h_u]:-0}" ]] && mark="${GREEN}●${NC}"
            printf "  %b %-16s ↓ %-10s ↑ %-10s\n" "$mark" "$(m "all clients" "все клиенты")" "$(human_bytes "$down")" "$(human_bytes "$up")"
            prev[h_d]=$down; prev[h_u]=$up
        fi

        [[ $any -eq 1 ]] || warn "$(m "No protocol installed yet." "Протокол ещё не установлен.")"

        line
        echo "$(m "● = traffic moved since last refresh. Press any key to go back." "● = трафик изменился с прошлого обновления. Нажмите любую клавишу для возврата.")"

        if read -rsn1 -t 2 _; then
            break
        fi
    done
}
