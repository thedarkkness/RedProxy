#!/usr/bin/env bash
# MTProto proxy via mtg (https://github.com/9seconds/mtg) — Telegram's own
# proxy protocol with fake-TLS obfuscation (the secret masquerades the
# connection as a normal HTTPS handshake to a real site). Telegram
# supports it natively (Settings > Data and Storage > Proxy, or a
# tg://proxy?... deep link) — unlike VLESS+Reality, no separate client
# app is needed on the user's device.
#
# mtg deliberately supports only ONE secret per server (the upstream
# maintainer's explicit design choice — "multiple secrets solve no
# problems and just complexify software" — not a RedProxy limitation).
# Every "client" added here shares that same secret and link; removing
# one only deletes its local label, it doesn't revoke access. The only
# way to cut everyone off is to reinstall, which rotates the secret.
#
# Unlike Reality/SOCKS5/HTTP, this isn't an Xray inbound — mtg is its own
# binary, config file and systemd service.
set -euo pipefail

INSTALL_DIR="/opt/redproxy"
CONFIG_FILE="$INSTALL_DIR/configs/mtg.toml"
META_FILE="$INSTALL_DIR/configs/mtproto_meta.json"
CLIENTS_DIR="$INSTALL_DIR/clients"
MTPROTO_PREFIX="mtproto"
MTG_BIN="/usr/local/bin/mtg"

# shellcheck source=../utils/colors.sh
source "$INSTALL_DIR/utils/colors.sh"
# shellcheck source=../utils/common.sh
source "$INSTALL_DIR/utils/common.sh"
load_lang

mtproto_installed() {
    [[ -f "$CONFIG_FILE" ]]
}

install_mtg_binary() {
    local arch
    case "$(uname -m)" in
        x86_64|amd64)  arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *)
            err "$(m "Unsupported architecture for mtg: $(uname -m)" "Неподдерживаемая архитектура для mtg: $(uname -m)")"
            return 1
            ;;
    esac

    info "$(m "Fetching latest mtg (MTProto proxy) release..." "Загружаю последний релиз mtg (MTProto прокси)...")"
    local latest
    latest=$(curl -fsSL https://api.github.com/repos/9seconds/mtg/releases/latest | jq -r '.tag_name')
    if [[ -z "$latest" || "$latest" == "null" ]]; then
        err "$(m "Could not determine the latest mtg version" "Не удалось определить последнюю версию mtg")"
        return 1
    fi

    local ver="${latest#v}"
    local url="https://github.com/9seconds/mtg/releases/download/${latest}/mtg-${ver}-linux-${arch}.tar.gz"
    local tmp; tmp=$(mktemp -d)

    info "$(m "Downloading mtg ${latest} (linux-${arch})..." "Скачиваю mtg ${latest} (linux-${arch})...")"
    curl -fsSL "$url" -o "$tmp/mtg.tar.gz"
    tar -xzf "$tmp/mtg.tar.gz" -C "$tmp"

    local bin
    bin=$(find "$tmp" -type f -name mtg | head -1)
    if [[ -z "$bin" ]]; then
        err "$(m "mtg binary not found in the downloaded archive" "Бинарник mtg не найден в скачанном архиве")"
        rm -rf "$tmp"
        return 1
    fi
    install -m 755 "$bin" "$MTG_BIN"
    rm -rf "$tmp"

    ok "$(m "mtg ${latest} installed to $MTG_BIN" "mtg ${latest} установлен в $MTG_BIN")"
}

mtproto_install() {
    local port="${1:-8443}"
    local domain="${2:-www.cloudflare.com}"

    if mtproto_installed; then
        err "$(m "MTProto is already installed. Use 'redproxy add' to add another client instead." "MTProto уже установлен. Используйте 'redproxy add', чтобы добавить ещё одного клиента.")"
        return 1
    fi

    if port_in_use "$port"; then
        err "$(m "Port $port is already in use:" "Порт $port уже занят:")"
        port_owner "$port"
        return 1
    fi

    open_firewall_port "$port"

    [[ -x "$MTG_BIN" ]] || install_mtg_binary

    info "$(m "Generating fake-TLS secret (masquerading as $domain)..." "Генерирую fake-TLS секрет (маскировка под $domain)...")"
    local secret
    secret=$("$MTG_BIN" generate-secret --hex "$domain" 2>/dev/null)
    if [[ -z "$secret" ]]; then
        err "$(m "Could not generate an mtg secret" "Не удалось сгенерировать секрет mtg")"
        return 1
    fi

    mkdir -p "$INSTALL_DIR/configs" "$CLIENTS_DIR"
    local ip; ip=$(public_ip)

    sed \
        -e "s|__SECRET__|$secret|g" \
        -e "s|__PORT__|$port|g" \
        -e "s|__IP__|$ip|g" \
        "$INSTALL_DIR/templates/mtproto.toml.tpl" > "$CONFIG_FILE"

    install -m 644 "$INSTALL_DIR/templates/mtg.service.tpl" /etc/systemd/system/redproxy-mtg.service
    systemctl daemon-reload
    systemctl enable --now redproxy-mtg >/dev/null 2>&1

    jq -n --arg port "$port" --arg domain "$domain" --arg secret "$secret" --arg ip "$ip" \
       '{port:($port|tonumber), domain:$domain, secret:$secret, ip:$ip}' > "$META_FILE"

    ok "$(m "MTProto proxy created (port $port, masquerading as $domain)" "MTProto прокси создан (порт $port, маскировка под $domain)")"

    mtproto_add_client "client1"
}

mtproto_add_client() {
    local name="${1:-}"
    [[ -n "$name" ]] || { read -rp "$(m "Client name (leave empty for a random one): " "Имя клиента (оставьте пустым для случайного): ")" name; }
    mtproto_installed || { err "$(m "MTProto is not installed yet. Run the installer first." "MTProto ещё не установлен. Сначала запустите установщик.")"; return 1; }
    if [[ -z "$name" ]]; then
        name=$(gen_unique_client_name "$MTPROTO_PREFIX")
    elif [[ -f "$CLIENTS_DIR/${MTPROTO_PREFIX}-${name}.json" ]]; then
        err "$(m "Client '$name' already exists" "Клиент '$name' уже существует")"
        return 1
    fi

    local meta ip port secret link
    meta=$(cat "$META_FILE")
    ip=$(echo "$meta" | jq -r '.ip')
    port=$(echo "$meta" | jq -r '.port')
    secret=$(echo "$meta" | jq -r '.secret')

    link="tg://proxy?server=${ip}&port=${port}&secret=${secret}"

    jq -n --arg name "$name" --arg link "$link" --arg secret "$secret" --arg created "$(date -u +%FT%TZ)" \
          '{name:$name, protocol:"mtproto", link:$link, secret:$secret, created:$created}' \
          > "$CLIENTS_DIR/${MTPROTO_PREFIX}-${name}.json"
    echo "$link" > "$CLIENTS_DIR/${MTPROTO_PREFIX}-${name}.link"

    print_mtproto_card "$name" "$ip" "$port" "$secret" "$link"
}

mtproto_remove_client() {
    local name="${1:-}"
    [[ -n "$name" ]] || { read -rp "$(m "Client name: " "Имя клиента: ")" name; }
    [[ -f "$CLIENTS_DIR/${MTPROTO_PREFIX}-${name}.json" ]] || { err "$(m "Client '$name' not found" "Клиент '$name' не найден")"; return 1; }

    rm -f "$CLIENTS_DIR/${MTPROTO_PREFIX}-${name}.json" "$CLIENTS_DIR/${MTPROTO_PREFIX}-${name}.link"
    warn "$(m "Local record for '$name' removed. Note: MTProto uses one shared secret for everyone, so this does NOT revoke their access — reinstall MTProto to rotate the secret if you need to cut someone off." "Локальная запись '$name' удалена. Обратите внимание: MTProto использует один общий секрет на всех, поэтому доступ НЕ отзывается — переустановите MTProto, чтобы сменить секрет, если нужно кого-то отключить.")"
}

mtproto_list_clients() {
    local found=0
    for f in "$CLIENTS_DIR/${MTPROTO_PREFIX}-"*.json; do
        [[ -e "$f" ]] || continue
        if [[ $found -eq 0 ]]; then
            printf "  %-20s %s\n" "$(m "NAME" "ИМЯ")" "$(m "CREATED" "СОЗДАН")"
        fi
        found=1
        local name created
        name=$(jq -r '.name' "$f")
        created=$(jq -r '.created' "$f")
        printf "  %-20s %s\n" "$name" "$created"
    done
    [[ $found -eq 1 ]] || warn "$(m "No clients yet" "Клиентов пока нет")"
}

mtproto_show_qr() {
    local name="${1:-}"
    [[ -n "$name" ]] || { read -rp "$(m "Client name: " "Имя клиента: ")" name; }
    [[ -f "$CLIENTS_DIR/${MTPROTO_PREFIX}-${name}.link" ]] || { err "$(m "Client '$name' not found" "Клиент '$name' не найден")"; return 1; }

    local link
    link=$(cat "$CLIENTS_DIR/${MTPROTO_PREFIX}-${name}.link")
    render_qr "$link"
    echo "$link"
}

print_mtproto_card() {
    local name="$1" ip="$2" port="$3" secret="$4" link="$5"
    line
    echo -e " ${BOLD}$(m "RedProxy Client" "Клиент RedProxy"): ${name}${NC}"
    line
    printf " %s: %s\n" "$(m "Protocol" "Протокол")" "MTProto"
    printf " %s: %s\n" "$(m "Server" "Сервер")" "$ip"
    printf " %s: %s\n" "$(m "Port" "Порт")" "$port"
    printf " %s: %s\n" "Secret" "$secret"
    line
    echo "$link"
    line
    render_qr "$link"
    line
    warn "$(m "Everyone you share this with uses the same secret — MTProto has no per-user credentials." "Все, кому вы это отправите, используют один и тот же секрет — у MTProto нет отдельных учётных данных на пользователя.")"
    printf " %s: %s\n" "$(m "Saved" "Сохранено")" "${CLIENTS_DIR}/${MTPROTO_PREFIX}-${name}.json"
    line
}
