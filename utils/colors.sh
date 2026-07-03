#!/usr/bin/env bash
# Color and logging helpers shared across RedProxy scripts.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info() { echo -e "${BLUE}[i]${NC} $*"; }
ok()   { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*" >&2; }
line() { echo -e "${CYAN}════════════════════════════════════════════════════${NC}"; }

# --- i18n -------------------------------------------------------------
# RedProxy supports English and Russian. The chosen language is picked
# once during install.sh and persisted to $INSTALL_DIR/lang so every
# later invocation (menu.sh, update.sh, ...) reads the same choice.
RP_LANG="${RP_LANG:-en}"

load_lang() {
    local f="${INSTALL_DIR:-/opt/redproxy}/lang"
    [[ -f "$f" ]] && RP_LANG=$(cat "$f")
    [[ "$RP_LANG" == "ru" ]] || RP_LANG="en"
}

# m <english> <russian> — returns the string for the active language.
m() {
    if [[ "$RP_LANG" == "ru" ]]; then
        printf '%s' "$2"
    else
        printf '%s' "$1"
    fi
}
