# Changelog

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
