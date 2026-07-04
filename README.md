# RedProxy

One-command proxy deployer for VPS. Point it at a fresh Debian/Ubuntu or
RHEL-family server and it installs Xray-core, generates a client, and hands
you back a ready-to-use link and a terminal QR code — no web panel
required.

Covers two different needs:
- **VLESS + Reality** — a TLS-camouflaged tunnel for bypassing censorship/DPI.
- **SOCKS5 / HTTP proxy** (username+password auth) — a plain proxy for
  pointing apps like Telegram or WhatsApp at, browser/curl proxy settings,
  or commercial proxy resale. No TLS camouflage, just a fast authenticated
  relay.

All three can be installed on the same server at once (each on its own
port) — run `install.sh` again to add another one; existing clients and
configs are preserved.

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
- ✓ Checks the chosen port is actually free before configuring anything
- ✓ Generates Reality keys / a SOCKS5 or HTTP account, and a first client
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
 Saved: /opt/redproxy/clients/reality-client1.json
════════════════════════════════════════════════════
```

A SOCKS5/HTTP client card looks similar but prints a username/password
and both a `socks5://`/`http://` link *and* a plain
`host:port:user:pass` line for apps (like Telegram/WhatsApp) that want
the fields typed in separately rather than pasted as a URL:

```
════════════════════════════════════════════════════
 RedProxy Client: alice
════════════════════════════════════════════════════
 Protocol: SOCKS5
 Server: 12.34.56.78
 Port: 1080
 Username: alice
 Password: 9f3a1b2c4d5e6f70
════════════════════════════════════════════════════
socks5://alice:9f3a1b2c4d5e6f70@12.34.56.78:1080#RedProxy-alice
════════════════════════════════════════════════════
█▀▀▀▀▀█ ▀▄▀█▄ █▀▀▀▀▀█
█ ███ █ █▀▀▀▄█ █ ███ █
█ ▀▀▀ █ █▀ █▀█ █ ▀▀▀ █
════════════════════════════════════════════════════
 Manual entry (host:port:user:pass): 12.34.56.78:1080:alice:9f3a1b2c4d5e6f70
 Saved: /opt/redproxy/clients/socks5-alice.json
════════════════════════════════════════════════════
```

## Managing clients

After install, `redproxy` is available on the server as both an interactive
menu and a CLI. If more than one protocol is installed, `add`/`remove`/`qr`
ask which one to act on; `list` shows every installed protocol's clients
together:

```bash
redproxy              # interactive menu
redproxy add alice    # add a client
redproxy remove alice # remove a client
redproxy list         # list clients (all installed protocols)
redproxy qr alice     # reprint link + QR
redproxy backup        # tar.gz of configs + clients
redproxy update         # git pull + refresh Xray-core
redproxy restart         # restart the xray service
```

```
════════════════════════════════════════════════════
 RedProxy v0.0.6
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
| SOCKS5 Proxy          | ✅ Ready        |
| HTTP Proxy              | ✅ Ready        |
| VLESS + WS + TLS          | 🚧 Coming soon |
| VMess                       | 🚧 Coming soon |
| Trojan                       | 🚧 Coming soon |
| Hysteria2                      | 🚧 Coming soon |
| TUIC                              | 🚧 Coming soon |
| WireGuard                           | 🚧 Coming soon |

RedProxy is versioned early on purpose (`0.0.x`) — the tunneling protocol
(Reality) and the plain proxies (SOCKS5/HTTP) were built out first, the
rest follow protocol-by-protocol. See [CHANGELOG.md](CHANGELOG.md).

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
│   ├── authproxy.sh                # shared SOCKS5/HTTP logic
│   ├── socks5.sh                     # SOCKS5 proxy (fully implemented)
│   ├── http.sh                         # HTTP proxy (fully implemented)
│   ├── vless.sh                          # VLESS + WS + TLS (stub)
│   ├── vmess.sh                            # VMess (stub)
│   ├── trojan.sh                             # Trojan (stub)
│   ├── hysteria2.sh                             # Hysteria2 (stub)
│   └── tuic.sh                                     # TUIC (stub)
├── wireguard/
│   └── wireguard.sh                                    # WireGuard (stub)
├── templates/                                             # xray config + systemd unit templates
├── utils/                                                    # shared bash helpers + QR renderer (Python)
└── clients/                                                    # generated client configs (created on the server)
```

Every protocol is a tagged inbound inside one shared `config.json` and one
`redproxy-xray` systemd service — installing a second or third protocol
appends to that file instead of replacing it, so existing clients keep
working.

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
