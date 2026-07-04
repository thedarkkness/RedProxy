#!/usr/bin/env bash
# VLESS + XTLS-Reality: the flagship, fully implemented RedProxy protocol.
# Provides: reality_install, reality_add_client, reality_remove_client,
# reality_list_clients, reality_show_qr — sourced by menu.sh / install.sh.
#
# config.json can hold several protocols' inbounds at once (Reality,
# SOCKS5, HTTP, ...), so this operates on the inbound tagged "reality-in"
# rather than assuming it owns the whole file, and client files are
# prefixed "reality-" so they don't collide with other protocols' clients
# of the same name.
set -euo pipefail

INSTALL_DIR="/opt/redproxy"
CONFIG_FILE="$INSTALL_DIR/configs/config.json"
CLIENTS_DIR="$INSTALL_DIR/clients"
META_FILE="$INSTALL_DIR/configs/reality_meta.json"
XRAY_BIN="/usr/local/bin/xray"
REALITY_TAG="reality-in"
REALITY_PREFIX="reality"

# shellcheck source=../utils/colors.sh
source "$INSTALL_DIR/utils/colors.sh"
# shellcheck source=../utils/common.sh
source "$INSTALL_DIR/utils/common.sh"
load_lang

# Parses `xray x25519` key:value output regardless of field-name wording.
# Xray-core has used at least three label styles for the same values:
#   "Private key: xxx"          / "Public key: xxx"           (old)
#   "PrivateKey: xxx"           / "Password: xxx"              (v25.3+)
#   "PrivateKey: xxx"           / "Password (PublicKey): xxx"  (v26+)
# so this matches on a normalized substring rather than an exact label.
reality_parse_key() {
    local raw="$1" field="$2" k v nk
    while IFS=':' read -r k v; do
        [[ -z "$k" ]] && continue
        nk=$(echo "$k" | tr -d '[:space:]()' | tr '[:upper:]' '[:lower:]')
        if [[ "$nk" == *"$field"* ]]; then
            echo "$v" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
            return 0
        fi
    done <<< "$raw"
}

reality_install() {
    local port="${1:-443}"
    local sni="${2:-www.microsoft.com}"

    ensure_config_skeleton

    if inbound_installed "$REALITY_TAG"; then
        err "$(m "VLESS+Reality is already installed. Use 'redproxy add' to add another client instead." "VLESS+Reality уже установлен. Используйте 'redproxy add', чтобы добавить ещё одного клиента.")"
        return 1
    fi

    if port_in_use "$port"; then
        err "$(m "Port $port is already in use:" "Порт $port уже занят:")"
        port_owner "$port"
        return 1
    fi

    info "$(m "Generating Reality X25519 keypair..." "Генерирую пару ключей X25519 для Reality...")"
    local keys priv pub
    keys=$("$XRAY_BIN" x25519)
    priv=$(reality_parse_key "$keys" "privatekey")
    pub=$(reality_parse_key "$keys" "publickey")
    [[ -z "$pub" ]] && pub=$(reality_parse_key "$keys" "password")

    if [[ -z "$priv" || -z "$pub" ]]; then
        err "$(m "Could not parse 'xray x25519' output — aborting so the server isn't left with an empty key." "Не удалось разобрать вывод 'xray x25519' — прерываю установку, чтобы не оставить сервер с пустым ключом.")"
        echo "$keys" >&2
        return 1
    fi

    local short_id dest inbound
    short_id=$(gen_short_id)
    dest="${sni}:443"

    inbound=$(sed \
        -e "s|__PORT__|$port|g" \
        -e "s|__DEST__|$dest|g" \
        -e "s|__SNI__|$sni|g" \
        -e "s|__PRIVATE_KEY__|$priv|g" \
        -e "s|__SHORT_ID__|$short_id|g" \
        "$INSTALL_DIR/templates/vless_reality.json.tpl")

    jq --argjson inbound "$inbound" '.inbounds += [$inbound]' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

    jq -n --arg port "$port" --arg sni "$sni" --arg dest "$dest" \
          --arg priv "$priv" --arg pub "$pub" --arg sid "$short_id" \
          '{protocol:"vless-reality", port:($port|tonumber), sni:$sni, dest:$dest, private_key:$priv, public_key:$pub, short_id:$sid}' \
          > "$META_FILE"

    ok "$(m "VLESS+Reality core config created (port $port, sni $sni)" "Базовый конфиг VLESS+Reality создан (порт $port, sni $sni)")"

    systemctl enable redproxy-xray >/dev/null 2>&1

    reality_add_client "client1"
}

reality_add_client() {
    local name="${1:-}"
    [[ -n "$name" ]] || { read -rp "$(m "Client name: " "Имя клиента: ")" name; }
    inbound_installed "$REALITY_TAG" || { err "$(m "Reality is not installed yet. Run the installer first." "Reality ещё не установлен. Сначала запустите установщик.")"; return 1; }
    [[ -f "$CLIENTS_DIR/${REALITY_PREFIX}-${name}.json" ]] && { err "$(m "Client '$name' already exists" "Клиент '$name' уже существует")"; return 1; }

    local uuid
    uuid=$("$XRAY_BIN" uuid)

    jq --arg uuid "$uuid" --arg email "$name" --arg tag "$REALITY_TAG" \
       '(.inbounds[] | select(.tag == $tag) | .settings.clients) += [{"id":$uuid,"email":$email,"flow":"xtls-rprx-vision"}]' \
       "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

    local meta port sni pub sid ip link
    meta=$(cat "$META_FILE")
    port=$(echo "$meta" | jq -r '.port')
    sni=$(echo "$meta" | jq -r '.sni')
    pub=$(echo "$meta" | jq -r '.public_key')
    sid=$(echo "$meta" | jq -r '.short_id')
    ip=$(public_ip)

    link="vless://${uuid}@${ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${pub}&sid=${sid}&type=tcp&headerType=none#RedProxy-${name}"

    jq -n --arg name "$name" --arg uuid "$uuid" --arg link "$link" --arg created "$(date -u +%FT%TZ)" \
          '{name:$name, uuid:$uuid, protocol:"vless-reality", link:$link, created:$created}' \
          > "$CLIENTS_DIR/${REALITY_PREFIX}-${name}.json"
    echo "$link" > "$CLIENTS_DIR/${REALITY_PREFIX}-${name}.link"

    systemctl restart redproxy-xray

    print_client_card "$name" "$uuid" "$ip" "$port" "$sni" "$pub" "$sid" "$link"
}

reality_remove_client() {
    local name="${1:-}"
    [[ -n "$name" ]] || { read -rp "$(m "Client name: " "Имя клиента: ")" name; }
    [[ -f "$CLIENTS_DIR/${REALITY_PREFIX}-${name}.json" ]] || { err "$(m "Client '$name' not found" "Клиент '$name' не найден")"; return 1; }

    local uuid
    uuid=$(jq -r '.uuid' "$CLIENTS_DIR/${REALITY_PREFIX}-${name}.json")

    jq --arg uuid "$uuid" --arg tag "$REALITY_TAG" \
       '(.inbounds[] | select(.tag == $tag) | .settings.clients) |= map(select(.id != $uuid))' \
       "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

    rm -f "$CLIENTS_DIR/${REALITY_PREFIX}-${name}.json" "$CLIENTS_DIR/${REALITY_PREFIX}-${name}.link"
    systemctl restart redproxy-xray
    ok "$(m "Client '$name' removed" "Клиент '$name' удалён")"
}

reality_list_clients() {
    local found=0
    for f in "$CLIENTS_DIR/${REALITY_PREFIX}-"*.json; do
        [[ -e "$f" ]] || continue
        if [[ $found -eq 0 ]]; then
            printf "  %-20s %-38s %s\n" "$(m "NAME" "ИМЯ")" "UUID" "$(m "CREATED" "СОЗДАН")"
        fi
        found=1
        local name uuid created
        name=$(jq -r '.name' "$f")
        uuid=$(jq -r '.uuid' "$f")
        created=$(jq -r '.created' "$f")
        printf "  %-20s %-38s %s\n" "$name" "$uuid" "$created"
    done
    [[ $found -eq 1 ]] || warn "$(m "No clients yet" "Клиентов пока нет")"
}

reality_show_qr() {
    local name="${1:-}"
    [[ -n "$name" ]] || { read -rp "$(m "Client name: " "Имя клиента: ")" name; }
    [[ -f "$CLIENTS_DIR/${REALITY_PREFIX}-${name}.link" ]] || { err "$(m "Client '$name' not found" "Клиент '$name' не найден")"; return 1; }

    local link
    link=$(cat "$CLIENTS_DIR/${REALITY_PREFIX}-${name}.link")
    render_qr "$link"
    echo "$link"
}

print_client_card() {
    local name="$1" uuid="$2" ip="$3" port="$4" sni="$5" pub="$6" sid="$7" link="$8"
    line
    echo -e " ${BOLD}$(m "RedProxy Client" "Клиент RedProxy"): ${name}${NC}"
    line
    # Plain "Label: value" (no column padding) — printf's %-Ns pads by byte
    # count, which misaligns Cyrillic labels on servers without a UTF-8
    # locale (common on minimal Debian installs).
    printf " %s: %s\n" "$(m "Protocol" "Протокол")" "VLESS + Reality"
    printf " %s: %s\n" "$(m "Server" "Сервер")" "$ip"
    printf " %s: %s\n" "$(m "Port" "Порт")" "$port"
    printf " %s: %s\n" "UUID" "$uuid"
    printf " %s: %s\n" "Flow" "xtls-rprx-vision"
    printf " %s: %s\n" "SNI" "$sni"
    printf " %s: %s\n" "PublicKey" "$pub"
    printf " %s: %s\n" "ShortId" "$sid"
    line
    echo "$link"
    line
    render_qr "$link"
    line
    printf " %s: %s\n" "$(m "Saved" "Сохранено")" "${CLIENTS_DIR}/${REALITY_PREFIX}-${name}.json"
    line
}
