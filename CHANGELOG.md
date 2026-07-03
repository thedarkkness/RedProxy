# Changelog

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
