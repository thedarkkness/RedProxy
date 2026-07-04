# Changelog

## [0.0.8] - 2026-07-04

### Fixed
- The 0.0.7 fix itself had a typo: `git config -C "$INSTALL_DIR" core.fileMode false` puts the `-C` flag on the wrong side of the subcommand (`-C` is a global git option and must come *before* `config`, not after). Git rejected it with "unknown switch `C'" and printed `git config`'s usage instead of ever running `git pull` — install.sh aborted on this line for everyone. Corrected to `git -C "$INSTALL_DIR" config core.fileMode false` in both `install.sh` and `update.sh`.

## [0.0.7] - 2026-07-04

### Fixed
- **Critical:** the 0.0.6 fix that made `install.sh` `git pull` in place instead of re-cloning immediately broke on Linux servers: this repo is developed on Windows, where git doesn't track the executable bit at all, so every script got committed as non-executable (`100644`). `install.sh`'s own `chmod +x` then looked like an uncommitted local edit to git on Linux (`core.fileMode` defaults to true there), and `git pull` refused with "Your local changes ... would be overwritten by merge" the moment any of those files also changed upstream. `install.sh`/`update.sh` now set `core.fileMode false` on the managed checkout before pulling, and every `.sh` file is now committed with the executable bit set directly in the index so this class of bug can't recur.

### Added
- **SOCKS5 and HTTP proxy support** (username/password auth), installable as options 2 and 3 in `install.sh` alongside VLESS+Reality. Meant for plain proxy use — Telegram/WhatsApp proxy settings, browser/curl proxy config, or commercial proxy resale — rather than censorship circumvention: no TLS camouflage, just a fast authenticated relay. Client cards print a `socks5://`/`http://` link, a QR code, and a plain `host:port:user:pass` line for apps that want the fields typed in separately. Shared install/add/remove/list/qr logic lives in `xray/authproxy.sh`; `xray/socks5.sh` and `xray/http.sh` are thin wrappers over it.
- All three protocols (Reality, SOCKS5, HTTP) can now be installed on the same server at once, each as its own tagged inbound inside one shared `config.json` run by one `redproxy-xray` service. `redproxy add`/`remove`/`qr` ask which installed protocol to act on when more than one is present; `redproxy list` shows every installed protocol's clients together.

### Fixed
- **Critical:** `install.sh` deleted and re-cloned `/opt/redproxy` on every run (`rm -rf` + `git clone`), which wiped out any already-installed protocol's config and clients the moment you ran the installer again to add a second one — the opposite of what "add SOCKS5 alongside your existing Reality install" requires. It now `git pull`s in place when a previous install is detected, only doing a fresh clone the first time.
- `reality_install` used to overwrite `config.json` wholesale from a template and assumed its inbound was always `.inbounds[0]`; both assumptions broke as soon as a second protocol could share the file. It now appends a tagged (`reality-in`) inbound and looks itself up by tag, matching the same pattern SOCKS5/HTTP use.

## [0.0.5] - 2026-07-04

### Fixed
- `install.sh` accepted whatever port the user typed (default 443) without checking if it was already bound. On any server that already runs a web/mail stack on 443 (very common), Xray would fail to bind (`bind: address already in use`), the config would look completely correct, and `redproxy-xray` would silently crash-loop under systemd (`Start request repeated too quickly`) — so clients connected but every session timed out. The port prompt now checks with `ss` before proceeding and, if the port is taken, shows what's holding it and asks again instead of generating a config for a service that can't start.

### Added
- `port_in_use` / `port_owner` helpers in `utils/common.sh`, reusable by the future "Change Port" menu action.

## [0.0.4] - 2026-07-04

### Fixed
- `install.sh` printed a hardcoded `VERSION="0.0.1"` in its banner and log lines, independent of the repo's actual `VERSION` file — every patch release since 0.0.1 was invisible to anyone running the one-line installer. It now fetches `VERSION` from the repo at the start of the script (the installer runs before anything is cloned locally, so this is the only point it can read the real value from) instead of hardcoding a copy that will go stale again next release.

## [0.0.3] - 2026-07-04

### Fixed
- The 0.0.2 fix for `xray x25519` parsing still missed a third label variant actually in use on current Xray-core: `Password (PublicKey): xxx`. Matching is now substring-based on a normalized label (spaces and parentheses stripped) instead of an exact match, so it survives label wording changes like this one instead of needing a patch release each time.

## [0.0.2] - 2026-07-04

### Fixed
- **Critical:** `xray x25519` output parsing broke on Xray-core v25.3+ (labels changed from `Private key:`/`Public key:` to `PrivateKey:`/`Password:`), which silently produced an empty Reality private/public keypair — the server would come up but every client connection failed. `reality_install` now parses key:value pairs field-by-field and matches both the old and new label formats, and aborts loudly instead of writing an empty key if parsing ever fails again.
- `redproxy`'s interactive menu exited back to the shell after a single action instead of redisplaying — it now loops until you choose "Exit".
- Client card labels (Protocol/Server/Port/...) could misalign in Russian on servers without a UTF-8 locale, because `printf %-10s` pads by byte count; switched to unpadded "Label: value" lines.

## [0.0.1] - 2026-07-04

### Added
- One-command installer (`install.sh`): OS detection (Debian/Ubuntu/RHEL family), dependency install, UFW/firewalld setup, BBR congestion control, a dedicated unprivileged `redproxy` system user, and Xray-core installation via systemd.
- Full **VLESS + Reality** support: X25519 keypair generation, client add/remove/list, `vless://` link generation, and terminal QR codes (Python `qrcode` venv, with `qrencode` as a fallback).
- `redproxy` CLI / interactive menu: Add Client, Delete Client, List Clients, Show QR, Restart, Update, Backup, Change Port.
- `uninstall.sh` and `update.sh` maintenance scripts.
- Protocol scaffolding for VLESS+WS+TLS, VMess, Trojan, Hysteria2, TUIC and WireGuard (present as stubs, marked "coming soon").

### Known limitations
- Only VLESS+Reality is fully functional in this release; the other five protocols are stubs.
- "Change Port" menu action is not implemented yet.
