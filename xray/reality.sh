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

reality_install() {
    local port="${1:-443}"
    local sni="${2:-www.microsoft.com}"

    mkdir -p "$INSTALL_DIR/configs" "$CLIENTS_DIR"

    info "Generating Reality X25519 keypair..."
    local keys priv pub
    keys=$("$XRAY_BIN" x25519)
    priv=$(echo "$keys" | awk '/Private key:/ {print $3}')
    pub=$(echo "$keys" | awk '/Public key:/ {print $3}')

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

    ok "VLESS+Reality core config created (port $port, sni $sni)"

    systemctl enable redproxy-xray >/dev/null 2>&1

    reality_add_client "client1"
}

reality_add_client() {
    local name="${1:-}"
    [[ -n "$name" ]] || { read -rp "Client name: " name; }
    [[ -f "$CONFIG_FILE" ]] || { err "Reality is not installed yet. Run the installer first."; return 1; }
    [[ -f "$CLIENTS_DIR/${name}.json" ]] && { err "Client '$name' already exists"; return 1; }

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
    [[ -n "$name" ]] || { read -rp "Client name: " name; }
    [[ -f "$CLIENTS_DIR/${name}.json" ]] || { err "Client '$name' not found"; return 1; }

    local uuid
    uuid=$(jq -r '.uuid' "$CLIENTS_DIR/${name}.json")

    jq --arg uuid "$uuid" '.inbounds[0].settings.clients |= map(select(.id != $uuid))' \
       "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

    rm -f "$CLIENTS_DIR/${name}.json" "$CLIENTS_DIR/${name}.link"
    systemctl restart redproxy-xray
    ok "Client '$name' removed"
}

reality_list_clients() {
    if [[ ! -d "$CLIENTS_DIR" ]] || [[ -z "$(ls -A "$CLIENTS_DIR" 2>/dev/null)" ]]; then
        warn "No clients yet"
        return 0
    fi

    printf "  %-20s %-38s %s\n" "NAME" "UUID" "CREATED"
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
    [[ -n "$name" ]] || { read -rp "Client name: " name; }
    [[ -f "$CLIENTS_DIR/${name}.link" ]] || { err "Client '$name' not found"; return 1; }

    local link
    link=$(cat "$CLIENTS_DIR/${name}.link")
    render_qr "$link"
    echo "$link"
}

print_client_card() {
    local name="$1" uuid="$2" ip="$3" port="$4" sni="$5" pub="$6" sid="$7" link="$8"
    line
    echo -e " ${BOLD}RedProxy Client: ${name}${NC}"
    line
    echo -e " Protocol  : VLESS + Reality"
    echo -e " Server    : ${ip}"
    echo -e " Port      : ${port}"
    echo -e " UUID      : ${uuid}"
    echo -e " Flow      : xtls-rprx-vision"
    echo -e " SNI       : ${sni}"
    echo -e " PublicKey : ${pub}"
    echo -e " ShortId   : ${sid}"
    line
    echo "$link"
    line
    render_qr "$link"
    line
    echo -e " Saved: ${CLIENTS_DIR}/${name}.json"
    line
}
