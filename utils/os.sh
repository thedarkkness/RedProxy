#!/usr/bin/env bash
# OS family, package manager and architecture detection.

detect_os() {
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        OS_ID="${ID:-}"
        OS_VERSION="${VERSION_ID:-}"
    else
        err "Cannot detect OS: /etc/os-release not found"
        exit 1
    fi

    case "$OS_ID" in
        ubuntu|debian)
            PKG_FAMILY="debian"
            PKG_UPDATE="apt-get update -y"
            PKG_INSTALL="apt-get install -y"
            ;;
        centos|rhel|almalinux|rocky|fedora)
            PKG_FAMILY="rhel"
            if command -v dnf >/dev/null 2>&1; then
                PKG_UPDATE="dnf makecache"
                PKG_INSTALL="dnf install -y"
            else
                PKG_UPDATE="yum makecache"
                PKG_INSTALL="yum install -y"
            fi
            ;;
        *)
            err "Unsupported OS: ${OS_ID:-unknown}"
            exit 1
            ;;
    esac
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)  ARCH="64" ;;
        aarch64|arm64) ARCH="arm64-v8a" ;;
        armv7l)        ARCH="arm32-v7a" ;;
        *)
            err "Unsupported architecture: $(uname -m)"
            exit 1
            ;;
    esac
}
