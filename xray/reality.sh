#!/usr/bin/env bash
# VLESS + XTLS-Reality: the flagship, fully implemented RedProxy protocol.
# Provides: reality_install, reality_add_client, reality_remove_client,
# reality_list_clients, reality_show_qr — sourced by menu.sh / install.sh.
set -euo pipefail

INSTALL_DIR="/opt/redproxy"
CONFIG_FILE="$INSTALL_DIR/configs/config.json"
CLIENTS_DIR="$INSTALL_DIR/clients"
META_FILE="$INSTALL_DIR/configs/reality_meta.json"
XRAY_BIN="/usr/local/bin/xray"

# shellcheck source=../utils/colors.sh
source "$INSTALL_DIR/utils/colors.sh"
# shellcheck source=../utils/common.sh
source "$INSTALL_DIR/utils/common.sh"
load_lang

# Parses `xray x25519` key:value output regardless of field-name spacing or
# casing. Xray-core renamed "Private key:" / "Public key:" to "PrivateKey:" /
# "Password:" around v25.3+ (the value is the same, only the label changed),
# so this matches both the old and the new format.
reality_parse_key() {
    local raw="$1" field="$2" k v nk
    while IFS=':' read -r k v; do
        [[ -z "$k" ]] && continue
        nk=$(echo "$k" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        if [[ "$nk" == "$field" ]]; then
            echo "$v" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
            return 0
        fi
    done <<< "$raw"
}

reality_install() {
    local port="${1:-443}"
    local sni="${2:-www.microsoft.com}"

    mkdir -p "$INSTALL_DIR/configs" "$CLIENTS_DIR"

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

    local short_id dest
    short_id=$(gen_short_id)
    dest="${sni}:443"

    sed \
        -e "s|__PORT__|$port|g" \
        -e "s|__DEST__|$dest|g" \
        -e "s|__SNI__|$sni|g" \
        -e "s|__PRIVATE_KEY__|$priv|g" \
        -e "s|__SHORT_ID__|$short_id|g" \
        "$INSTALL_DIR/templates/vless_reality.json.tpl" > "$CONFIG_FILE"

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
    [[ -f "$CONFIG_FILE" ]] || { err "$(m "Reality is not installed yet. Run the installer first." "Reality ещё не установлен. Сначала запустите установщик.")"; return 1; }
    [[ -f "$CLIENTS_DIR/${name}.json" ]] && { err "$(m "Client '$name' already exists" "Клиент '$name' уже существует")"; return 1; }

    local uuid
    uuid=$("$XRAY_BIN" uuid)

    jq --arg uuid "$uuid" --arg email "$name" \
       '.inbounds[0].settings.clients += [{"id":$uuid,"email":$email,"flow":"xtls-rprx-vision"}]' \
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
          > "$CLIENTS_DIR/${name}.json"
    echo "$link" > "$CLIENTS_DIR/${name}.link"

    systemctl restart redproxy-xray

    print_client_card "$name" "$uuid" "$ip" "$port" "$sni" "$pub" "$sid" "$link"
}

reality_remove_client() {
    local name="${1:-}"
    [[ -n "$name" ]] || { read -rp "$(m "Client name: " "Имя клиента: ")" name; }
    [[ -f "$CLIENTS_DIR/${name}.json" ]] || { err "$(m "Client '$name' not found" "Клиент '$name' не найден")"; return 1; }

    local uuid
    uuid=$(jq -r '.uuid' "$CLIENTS_DIR/${name}.json")

    jq --arg uuid "$uuid" '.inbounds[0].settings.clients |= map(select(.id != $uuid))' \
       "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

    rm -f "$CLIENTS_DIR/${name}.json" "$CLIENTS_DIR/${name}.link"
    systemctl restart redproxy-xray
    ok "$(m "Client '$name' removed" "Клиент '$name' удалён")"
}

reality_list_clients() {
    if [[ ! -d "$CLIENTS_DIR" ]] || [[ -z "$(ls -A "$CLIENTS_DIR" 2>/dev/null)" ]]; then
        warn "$(m "No clients yet" "Клиентов пока нет")"
        return 0
    fi

    printf "  %-20s %-38s %s\n" "$(m "NAME" "ИМЯ")" "UUID" "$(m "CREATED" "СОЗДАН")"
    for f in "$CLIENTS_DIR"/*.json; do
        [[ -e "$f" ]] || continue
        local name uuid created
        name=$(jq -r '.name' "$f")
        uuid=$(jq -r '.uuid' "$f")
        created=$(jq -r '.created' "$f")
        printf "  %-20s %-38s %s\n" "$name" "$uuid" "$created"
    done
}

reality_show_qr() {
    local name="${1:-}"
    [[ -n "$name" ]] || { read -rp "$(m "Client name: " "Имя клиента: ")" name; }
    [[ -f "$CLIENTS_DIR/${name}.link" ]] || { err "$(m "Client '$name' not found" "Клиент '$name' не найден")"; return 1; }

    local link
    link=$(cat "$CLIENTS_DIR/${name}.link")
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
    printf " %s: %s\n" "$(m "Saved" "Сохранено")" "${CLIENTS_DIR}/${name}.json"
    line
}
