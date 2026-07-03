# RedProxy

One-command proxy deployer for VPS. Point it at a fresh Debian/Ubuntu or
RHEL-family server and it installs Xray-core, generates a client, and hands
you back a ready-to-use `vless://` link and a terminal QR code — no web
panel required.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/thedarkkness/RedProxy/main/install.sh)
```

The installer's first prompt lets you pick a language — `1) English` or
`2) Русский` — and every RedProxy script (installer, menu, client
management) speaks that language from then on.

## What the installer does

- ✓ Asks for a language (English / Русский)
- ✓ Detects the OS and installs dependencies
- ✓ Configures the firewall (UFW / firewalld)
- ✓ Enables BBR congestion control
- ✓ Creates an unprivileged `redproxy` system user
- ✓ Installs Xray-core and a systemd service (`redproxy-xray`)
- ✓ Generates Reality keys and a first client
- ✓ Prints the connection link **and** a scannable QR code
- ✓ Saves everything under `/opt/redproxy`

```
════════════════════════════════════════════════════
 RedProxy Client: client1
════════════════════════════════════════════════════
 Protocol  : VLESS + Reality
 Server    : 12.34.56.78
 Port      : 443
 UUID      : 8f14e45f-ceea-4c...
 Flow      : xtls-rprx-vision
 SNI       : www.microsoft.com
 PublicKey : Xg8f...
 ShortId   : a1b2c3d4e5f6a7b8
════════════════════════════════════════════════════
vless://8f14e45f-...@12.34.56.78:443?...#RedProxy-client1
════════════════════════════════════════════════════
█▀▀▀▀▀█ ▀▄▀█▄ █▀▀▀▀▀█
█ ███ █ █▀▀▀▄█ █ ███ █
█ ▀▀▀ █ █▀ █▀█ █ ▀▀▀ █
════════════════════════════════════════════════════
 Saved: /opt/redproxy/clients/client1.json
════════════════════════════════════════════════════
```

## Managing clients

After install, `redproxy` is available on the server as both an interactive
menu and a CLI:

```bash
redproxy              # interactive menu
redproxy add alice    # add a client
redproxy remove alice # remove a client
redproxy list         # list clients
redproxy qr alice     # reprint link + QR
redproxy backup        # tar.gz of configs + clients
redproxy update         # git pull + refresh Xray-core
redproxy restart         # restart the xray service
```

```
════════════════════════════════════════════════════
 RedProxy v0.0.1
════════════════════════════════════════════════════
  1) Add Client
  2) Delete Client
  3) List Clients
  4) Show QR
  5) Restart
  6) Update
  7) Backup
  8) Change Port
  0) Exit
════════════════════════════════════════════════════
```

## Supported protocols

| Protocol          | Status         |
|--------------------|----------------|
| VLESS + Reality     | ✅ Ready        |
| VLESS + WS + TLS     | 🚧 Coming soon |
| VMess                 | 🚧 Coming soon |
| Trojan                 | 🚧 Coming soon |
| Hysteria2                | 🚧 Coming soon |
| TUIC                       | 🚧 Coming soon |
| WireGuard                    | 🚧 Coming soon |

RedProxy is versioned early on purpose (`0.0.1`) — VLESS+Reality is fully
built out first, the rest follow protocol-by-protocol. See
[CHANGELOG.md](CHANGELOG.md).

## Project layout

```
RedProxy/
├── install.sh          # one-command installer (entrypoint)
├── uninstall.sh          # removes RedProxy + Xray + client data
├── update.sh               # git pull + Xray-core refresh
├── menu.sh                   # CLI / interactive menu, symlinked to `redproxy`
├── xray/
│   ├── install_xray.sh         # installs the Xray-core binary + systemd unit
│   ├── reality.sh                # VLESS + Reality (fully implemented)
│   ├── vless.sh                    # VLESS + WS + TLS (stub)
│   ├── vmess.sh                      # VMess (stub)
│   ├── trojan.sh                       # Trojan (stub)
│   ├── hysteria2.sh                       # Hysteria2 (stub)
│   └── tuic.sh                               # TUIC (stub)
├── wireguard/
│   └── wireguard.sh                              # WireGuard (stub)
├── templates/                                       # xray config + systemd unit templates
├── utils/                                              # shared bash helpers + QR renderer (Python)
└── clients/                                              # generated client configs (created on the server)
```

## Local development

`utils/qr.py` renders QR codes via the `qrcode` package. The installer
creates a dedicated venv on the *target server* at `/opt/redproxy/.venv`
(via `utils/venv_setup.sh`) — it isn't committed to this repo since it's
platform-specific. To set one up locally for development:

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/python utils/qr.py "vless://test"
```

## Uninstall

```bash
sudo bash /opt/redproxy/uninstall.sh
```

## License

[MIT](LICENSE)
