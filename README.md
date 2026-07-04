# RedProxy

One-command proxy deployer for VPS. Point it at a fresh Debian/Ubuntu or
RHEL-family server and it installs Xray-core, generates a client, and hands
you back a ready-to-use link and a terminal QR code — no web panel
required.

Covers a few different needs:
- **VLESS + Reality** — a TLS-camouflaged tunnel for bypassing censorship/DPI.
  Needs a client app (v2rayNG/NekoBox/Hiddify/v2rayN/...) since it's not a
  protocol apps support natively.
- **SOCKS5 / HTTP proxy** (username+password auth) — a plain proxy for
  pointing apps like WhatsApp at, browser/curl proxy settings, or commercial
  proxy resale. No TLS camouflage, just a fast authenticated relay — DPI
  that fingerprints unobfuscated proxy traffic (common in heavily-censored
  networks) can still block it.
- **MTProto** (via [mtg](https://github.com/9seconds/mtg)) — Telegram's own
  proxy protocol with fake-TLS obfuscation, so it blends in as ordinary
  HTTPS. Telegram supports it natively (Settings → Data and Storage →
  Proxy, or a `tg://proxy?...` link) — no separate client app needed.

All four can be installed on the same server at once (each on its own
port) — run `install.sh` again to add another one; existing clients and
configs are preserved. If it detects RedProxy is already installed, it
asks up front whether you want to manage the existing install (jumps
straight into the `redproxy` menu, skipping the OS/dependency setup) or
install another protocol / update.

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
redproxy               # interactive menu
redproxy add alice     # add a client
redproxy remove alice  # remove a client
redproxy list          # list clients (all installed protocols)
redproxy qr alice      # reprint link + QR
redproxy status        # live traffic view (see below)
redproxy check-update   # check for a newer version, offers to install it (Y/n)
redproxy backup           # tar.gz of configs + clients
redproxy restart            # restart the xray service
redproxy lang                  # switch English / Русский
```

```
════════════════════════════════════════════════════
 RedProxy v0.1.1
════════════════════════════════════════════════════
  1) Add Client
  2) Delete Client
  3) List Clients
  4) Show QR
  5) Live Status (traffic)
  6) Restart
  7) Check for Updates
  8) Backup
  9) Change Port
 10) Change Language
  0) Exit
════════════════════════════════════════════════════
```

"Check for Updates" compares your version against the repo's `VERSION`
file; if a newer one exists it asks `Update now? [Y/n]` right there
before pulling it, and if you're already current it just says so.

Running `install.sh` again on a server that already has RedProxy asks
the same kind of question up front: manage what's already there, or
install another protocol. Picking an already-installed protocol adds a
new client straight away instead of erroring and pointing you at a
separate command.

### Live status

`redproxy status` (or menu option 5) asks which client or protocol you
want to watch — pick one client for Reality, or "all clients" for
SOCKS5/HTTP, since Xray doesn't expose reliable per-account stats for
those, only per-inbound totals. It then shows whether `redproxy-xray` is
running and how much traffic that target has moved, via Xray's own
[Stats API](https://xtls.github.io/en/document/level-2/traffic_stats.html)
(a loopback-only inbound, enabled automatically the first time you check
status). Auto-refreshes every couple of seconds and marks the row `●`
when the counter has moved since the last refresh. TCP-based proxies
don't have WireGuard's periodic-handshake concept, so this is the
closest honest equivalent to "is there a live connection right now" —
press any key to go back to the menu.

```
Which client/config do you want to watch?
  1) VLESS+Reality — client1
  2) SOCKS5 (all clients)
> 1

════════════════════════════════════════════════════
 RedProxy — Live Status
════════════════════════════════════════════════════
 Service: active
 Watching: VLESS+Reality — client1
════════════════════════════════════════════════════
  ● ↓ 128.4 MB  ↑ 12.1 MB
════════════════════════════════════════════════════
● = traffic moved since last refresh. Press any key to go back.
```

## Supported protocols

| Protocol          | Status         |
|--------------------|----------------|
| VLESS + Reality     | ✅ Ready        |
| SOCKS5 Proxy          | ✅ Ready        |
| HTTP Proxy              | ✅ Ready        |
| MTProto (Telegram)        | ✅ Ready        |
| VLESS + WS + TLS              | 🚧 Coming soon |
| VMess                            | 🚧 Coming soon |
| Trojan                             | 🚧 Coming soon |
| Hysteria2                            | 🚧 Coming soon |
| TUIC                                    | 🚧 Coming soon |
| WireGuard                                  | 🚧 Coming soon |

RedProxy is versioned early on purpose (`0.x`) — the tunneling protocol
(Reality), the plain proxies (SOCKS5/HTTP), and MTProto were built out
first, the rest follow protocol-by-protocol. See [CHANGELOG.md](CHANGELOG.md).

**MTProto's one limitation, upfront:** [mtg](https://github.com/9seconds/mtg)
deliberately supports a single shared secret per server (the upstream
maintainer's explicit design choice, not something RedProxy works around).
Every client you "add" gets a locally-labeled copy of the *same* link —
handy for tracking who you sent it to, but removing a client only deletes
that label, it doesn't revoke their access. Reinstalling MTProto rotates
the secret and cuts everyone off at once if you need that.

## Project layout

```
RedProxy/
├── install.sh          # one-command installer (entrypoint)
├── uninstall.sh          # removes RedProxy + Xray + mtg + client data
├── update.sh               # git pull + Xray-core refresh
├── menu.sh                   # CLI / interactive menu, symlinked to `redproxy`
├── xray/
│   ├── install_xray.sh         # installs the Xray-core binary + systemd unit
│   ├── reality.sh                # VLESS + Reality (fully implemented)
│   ├── authproxy.sh                # shared SOCKS5/HTTP logic
│   ├── socks5.sh                     # SOCKS5 proxy (fully implemented)
│   ├── http.sh                         # HTTP proxy (fully implemented)
│   ├── status.sh                         # Xray Stats API + `redproxy status` live view
│   ├── vless.sh                          # VLESS + WS + TLS (stub)
│   ├── vmess.sh                            # VMess (stub)
│   ├── trojan.sh                             # Trojan (stub)
│   ├── hysteria2.sh                             # Hysteria2 (stub)
│   └── tuic.sh                                     # TUIC (stub)
├── mtproto/
│   └── mtproto.sh                                    # MTProto via mtg (fully implemented)
├── wireguard/
│   └── wireguard.sh                                    # WireGuard (stub)
├── templates/                                             # xray/mtg config + systemd unit templates
├── utils/                                                    # shared bash helpers + QR renderer (Python)
└── clients/                                                    # generated client configs (created on the server)
```

Reality/SOCKS5/HTTP are each a tagged inbound inside one shared
`config.json` and one `redproxy-xray` systemd service — installing a
second or third protocol appends to that file instead of replacing it,
so existing clients keep working. MTProto is a separate binary
(`mtg`), config (`configs/mtg.toml`) and service (`redproxy-mtg`), since
it isn't an Xray protocol.

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
