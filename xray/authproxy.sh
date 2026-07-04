#!/usr/bin/env bash
# Shared logic for simple username/password proxy inbounds: SOCKS5 and
# HTTP. Xray configures both almost identically (protocol + a
# settings.accounts array of {user,pass}), so xray/socks5.sh and
# xray/http.sh are thin wrappers around these functions — the only real
# difference between the two protocols is the "protocol" field and the
# URI scheme used for the client link.
#
# Meant for plain proxy use (SOCKS5/HTTP proxy settings in apps like
# Telegram/WhatsApp, browsers, curl, or commercial proxy resale) rather
# than censorship circumvention — no TLS camouflage, just auth.
set -euo pipefail

INSTALL_DIR="/opt/redproxy"
CONFIG_FILE="$INSTALL_DIR/configs/config.json"
CLIENTS_DIR="$INSTALL_DIR/clients"

# shellcheck source=../utils/colors.sh
source "$INSTALL_DIR/utils/colors.sh"
# shellcheck source=../utils/common.sh
source "$INSTALL_DIR/utils/common.sh"
load_lang

# authproxy_install <xray_protocol: socks|http> <tag> <prefix> <port>
authproxy_install() {
    local xproto="$1" tag="$2" prefix="$3" port="$4"

    ensure_config_skeleton

    if inbound_installed "$tag"; then
        err "$(m "This proxy is already installed. Use 'redproxy add' to add another client instead." "Этот прокси уже установлен. Используйте 'redproxy add', чтобы добавить ещё одного клиента.")"
        return 1
    fi

    if port_in_use "$port"; then
        err "$(m "Port $port is already in use:" "Порт $port уже занят:")"
        port_owner "$port"
        return 1
    fi

    if [[ "$xproto" == "socks" ]]; then
        open_firewall_port "$port" true
    else
        open_firewall_port "$port"
    fi

    local settings
    if [[ "$xproto" == "socks" ]]; then
        local ip; ip=$(public_ip)
        settings=$(jq -n --arg ip "$ip" '{auth:"password", accounts: [], udp:true, ip:$ip}')
    else
        settings=$(jq -n '{accounts: [], allowTransparent:false}')
    fi

    jq --arg tag "$tag" --arg proto "$xproto" --argjson port "$port" --argjson settings "$settings" \
       '.inbounds += [{tag:$tag, listen:"0.0.0.0", port:$port, protocol:$proto, settings:$settings}]' \
       "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

    ok "$(m "$xproto inbound created on port $port" "Инбаунд $xproto создан на порту $port")"

    systemctl enable redproxy-xray >/dev/null 2>&1

    authproxy_add_client "$xproto" "$tag" "$prefix" "user1"
}

# authproxy_add_client <xray_protocol> <tag> <prefix> [name]
authproxy_add_client() {
    local xproto="$1" tag="$2" prefix="$3" name="${4:-}"
    [[ -n "$name" ]] || { read -rp "$(m "Client name (leave empty for a random one): " "Имя клиента (оставьте пустым для случайного): ")" name; }
    inbound_installed "$tag" || { err "$(m "This proxy is not installed yet. Run the installer first." "Этот прокси ещё не установлен. Сначала запустите установщик.")"; return 1; }
    if [[ -z "$name" ]]; then
        name=$(gen_unique_client_name "$prefix")
    elif [[ -f "$CLIENTS_DIR/${prefix}-${name}.json" ]]; then
        err "$(m "Client '$name' already exists" "Клиент '$name' уже существует")"
        return 1
    fi

    local user pass port ip scheme link
    user="$name"
    pass=$(openssl rand -hex 8)
    port=$(jq -r --arg tag "$tag" '.inbounds[] | select(.tag == $tag) | .port' "$CONFIG_FILE")
    ip=$(public_ip)

    jq --arg tag "$tag" --arg user "$user" --arg pass "$pass" \
       '(.inbounds[] | select(.tag == $tag) | .settings.accounts) += [{user:$user, pass:$pass}]' \
       "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

    scheme="$xproto"; [[ "$xproto" == "socks" ]] && scheme="socks5"
    link="${scheme}://${user}:${pass}@${ip}:${port}#RedProxy-${name}"

    jq -n --arg name "$name" --arg proto "$xproto" --arg user "$user" --arg pass "$pass" \
          --arg ip "$ip" --argjson port "$port" --arg link "$link" --arg created "$(date -u +%FT%TZ)" \
          '{name:$name, protocol:$proto, user:$user, pass:$pass, server:$ip, port:$port, link:$link, created:$created}' \
          > "$CLIENTS_DIR/${prefix}-${name}.json"
    echo "$link" > "$CLIENTS_DIR/${prefix}-${name}.link"

    systemctl restart redproxy-xray

    print_authproxy_card "$xproto" "$prefix" "$name" "$ip" "$port" "$user" "$pass" "$link"
}

# authproxy_remove_client <tag> <prefix> [name]
authproxy_remove_client() {
    local tag="$1" prefix="$2" name="${3:-}"
    [[ -n "$name" ]] || { read -rp "$(m "Client name: " "Имя клиента: ")" name; }
    [[ -f "$CLIENTS_DIR/${prefix}-${name}.json" ]] || { err "$(m "Client '$name' not found" "Клиент '$name' не найден")"; return 1; }

    local user
    user=$(jq -r '.user' "$CLIENTS_DIR/${prefix}-${name}.json")

    jq --arg tag "$tag" --arg user "$user" \
       '(.inbounds[] | select(.tag == $tag) | .settings.accounts) |= map(select(.user != $user))' \
       "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

    rm -f "$CLIENTS_DIR/${prefix}-${name}.json" "$CLIENTS_DIR/${prefix}-${name}.link"
    systemctl restart redproxy-xray
    ok "$(m "Client '$name' removed" "Клиент '$name' удалён")"
}

# authproxy_list_clients <prefix>
authproxy_list_clients() {
    local prefix="$1"
    local found=0
    for f in "$CLIENTS_DIR/${prefix}-"*.json; do
        [[ -e "$f" ]] || continue
        if [[ $found -eq 0 ]]; then
            printf "  %-20s %-20s %s\n" "$(m "NAME" "ИМЯ")" "$(m "USERNAME" "ЛОГИН")" "$(m "CREATED" "СОЗДАН")"
        fi
        found=1
        local name user created
        name=$(jq -r '.name' "$f")
        user=$(jq -r '.user' "$f")
        created=$(jq -r '.created' "$f")
        printf "  %-20s %-20s %s\n" "$name" "$user" "$created"
    done
    [[ $found -eq 1 ]] || warn "$(m "No clients yet" "Клиентов пока нет")"
}

# authproxy_show_qr <prefix> [name]
authproxy_show_qr() {
    local prefix="$1" name="${2:-}"
    [[ -n "$name" ]] || { read -rp "$(m "Client name: " "Имя клиента: ")" name; }
    [[ -f "$CLIENTS_DIR/${prefix}-${name}.link" ]] || { err "$(m "Client '$name' not found" "Клиент '$name' не найден")"; return 1; }

    local link
    link=$(cat "$CLIENTS_DIR/${prefix}-${name}.link")
    render_qr "$link"
    echo "$link"
}

print_authproxy_card() {
    local xproto="$1" prefix="$2" name="$3" ip="$4" port="$5" user="$6" pass="$7" link="$8"
    local label="SOCKS5"; [[ "$xproto" == "http" ]] && label="HTTP"
    line
    echo -e " ${BOLD}$(m "RedProxy Client" "Клиент RedProxy"): ${name}${NC}"
    line
    printf " %s: %s\n" "$(m "Protocol" "Протокол")" "$label"
    printf " %s: %s\n" "$(m "Server" "Сервер")" "$ip"
    printf " %s: %s\n" "$(m "Port" "Порт")" "$port"
    printf " %s: %s\n" "$(m "Username" "Логин")" "$user"
    printf " %s: %s\n" "$(m "Password" "Пароль")" "$pass"
    line
    echo "$link"
    line
    render_qr "$link"
    line
    printf " %s: %s:%s:%s:%s\n" "$(m "Manual entry (host:port:user:pass)" "Ручной ввод (хост:порт:логин:пароль)")" "$ip" "$port" "$user" "$pass"
    printf " %s: %s\n" "$(m "Saved" "Сохранено")" "${CLIENTS_DIR}/${prefix}-${name}.json"
    line
}
