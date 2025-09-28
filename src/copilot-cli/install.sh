#!/bin/bash
set -euo pipefail

VERSION=${VERSION:-latest}
INSTALL_COMPLETIONS=${INSTALLCOMPLETIONS:-true}
WITH_GH=${WITHGH:-true}
AUTO_UPDATE=${AUTOUPDATE:-false}

PKG_MANAGER=""

NODE_VERSION="22.11.0"
NODE_DIST_URL="https://nodejs.org/dist/v${NODE_VERSION}"
NODE_INSTALL_DIR="/usr/local/lib/nodejs"
NPM_GLOBAL_PREFIX="/usr/local"

log() {
    echo "[copilot-cli] $1"
}

err() {
    echo "[copilot-cli] ERROR: $1" >&2
}

run_as_root() {
    if [ "$(id -u)" -ne 0 ]; then
        err "This script must be run as root."
        exit 1
    fi
}

ensure_packages() {
    if command -v apt-get >/dev/null 2>&1; then
        PKG_MANAGER="apt"
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get install -y --no-install-recommends ca-certificates curl tar xz-utils gnupg procps
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="dnf"
        dnf -y install ca-certificates curl tar xz procps-ng coreutils gnupg2
    elif command -v yum >/dev/null 2>&1; then
        PKG_MANAGER="yum"
        yum -y install ca-certificates curl tar xz procps-ng coreutils gnupg2
    elif command -v apk >/dev/null 2>&1; then
        PKG_MANAGER="apk"
        apk update
        apk add --no-cache ca-certificates curl tar xz coreutils bash
    else
        err "Unsupported package manager."
        exit 1
    fi
}

ensure_node() {
    if command -v node >/dev/null 2>&1; then
        local current
        current=$(node -v | sed 's/^v//')
        if printf '%s
%s' "22.0.0" "${current}" | sort -V | tail -n 1 | grep -qx "${current}"; then
            log "Node.js ${current} already present; skipping install."
            return
        else
            log "Existing Node.js ${current} is older than required v22.x; upgrading."
        fi
    fi

    if [ "${PKG_MANAGER}" = "apk" ]; then
        apk add --no-cache nodejs-current npm
        local current
        current=$(node -v | sed 's/^v//')
        if ! printf '%s\n%s' "22.0.0" "${current}" | sort -V | tail -n 1 | grep -qx "${current}"; then
            err "Alpine repositories did not provide Node.js v22+."
            exit 1
        fi
        log "Using Node.js ${current} from Alpine repositories."
        return
    fi

    local arch
    arch=$(uname -m)
    local node_arch
    case "$arch" in
        x86_64|amd64)
            node_arch="x64"
            ;;
        aarch64|arm64)
            node_arch="arm64"
            ;;
        *)
            err "Unsupported architecture: $arch"
            exit 1
            ;;
    esac

    mkdir -p "${NODE_INSTALL_DIR}"
    local node_tar="node-v${NODE_VERSION}-linux-${node_arch}.tar.xz"
    local url="${NODE_DIST_URL}/${node_tar}"
    local tmp_dir
    tmp_dir=$(mktemp -d)
    curl -fsSL "${url}" -o "${tmp_dir}/${node_tar}"
    tar -xJf "${tmp_dir}/${node_tar}" -C "${NODE_INSTALL_DIR}"
    rm -rf "${tmp_dir}"

    ln -sf "${NODE_INSTALL_DIR}/node-v${NODE_VERSION}-linux-${node_arch}/bin/node" /usr/local/bin/node
    ln -sf "${NODE_INSTALL_DIR}/node-v${NODE_VERSION}-linux-${node_arch}/bin/npm" /usr/local/bin/npm
    ln -sf "${NODE_INSTALL_DIR}/node-v${NODE_VERSION}-linux-${node_arch}/bin/npx" /usr/local/bin/npx
    log "Installed Node.js v${NODE_VERSION} (${node_arch})."
}

install_gh_cli() {
    if [ "${WITH_GH}" != "true" ]; then
        log "Skipping GitHub CLI installation (withGH=${WITH_GH})."
        return
    fi

    if command -v gh >/dev/null 2>&1; then
        log "GitHub CLI already installed."
        return
    fi

    if command -v apt-get >/dev/null 2>&1; then
        if [ ! -f /usr/share/keyrings/githubcli-archive-keyring.gpg ]; then
            curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        fi
        local arch
        arch=$(dpkg --print-architecture)
        echo "deb [arch=${arch} signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" >/etc/apt/sources.list.d/github-cli.list
        apt-get update
        apt-get install -y --no-install-recommends gh
    elif command -v dnf >/dev/null 2>&1; then
        rpm --import https://cli.github.com/packages/githubcli-archive-keyring.gpg
        cat <<'REPO' >/etc/yum.repos.d/github-cli.repo
[github-cli]
name=GitHub CLI
baseurl=https://cli.github.com/packages/rpm/
enabled=1
gpgcheck=1
gpgkey=https://cli.github.com/packages/githubcli-archive-keyring.gpg
REPO
        dnf install -y gh
    elif command -v yum >/dev/null 2>&1; then
        rpm --import https://cli.github.com/packages/githubcli-archive-keyring.gpg
        cat <<'REPO' >/etc/yum.repos.d/github-cli.repo
[github-cli]
name=GitHub CLI
baseurl=https://cli.github.com/packages/rpm/
enabled=1
gpgcheck=1
gpgkey=https://cli.github.com/packages/githubcli-archive-keyring.gpg
REPO
        yum install -y gh
    elif command -v apk >/dev/null 2>&1; then
        apk add --no-cache github-cli || log "Unable to install GitHub CLI from apk repository; continuing without it."
    else
        log "Unable to install GitHub CLI on this platform."
    fi
}

ensure_npm_prefix() {
    npm config set prefix "${NPM_GLOBAL_PREFIX}" >/dev/null 2>&1 || true
    export NPM_CONFIG_PREFIX="${NPM_GLOBAL_PREFIX}"
}

install_copilot_cli() {
    local installed_version=""
    if command -v copilot >/dev/null 2>&1; then
        installed_version=$(copilot --version 2>/dev/null | head -n 1 | sed -n 's/^\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p')
        if [ -z "${installed_version}" ]; then
            installed_version=$(copilot --version 2>/dev/null | head -n 1 | sed -n 's/^copilot\/\([0-9][^ ]*\).*$/\1/p')
        fi
    fi
    if [ -z "${installed_version}" ]; then
        # Fallback via npm list if binary missing but package installed
        installed_version=$(npm list -g @github/copilot --depth=0 2>/dev/null | grep -o '@[0-9][^ ]*' | sed 's/@//' | tail -n 1 || true)
    fi

    local target="${VERSION}"
    local install_arg="@github/copilot"
    if [ "${target}" != "latest" ]; then
        install_arg="@github/copilot@${target}"
    fi

    if [ -n "${installed_version}" ]; then
        if [ "${target}" = "latest" ] && [ "${AUTO_UPDATE}" != "true" ]; then
            log "Copilot CLI ${installed_version} already installed; skipping update (autoUpdate=false)."
            return
        fi
        if [ "${target}" != "latest" ] && [ "${installed_version}" = "${target}" ]; then
            log "Copilot CLI ${installed_version} already matches requested version."
            return
        fi
    elif [ "${target}" = "latest" ]; then
        log "Copilot CLI not found; installing latest release."
    else
        log "Copilot CLI not found; installing version ${target}."
    fi

    npm install -g "${install_arg}"
}

setup_completions() {
    if [ "${INSTALL_COMPLETIONS}" != "true" ]; then
        log "Skipping completions setup (installCompletions=${INSTALL_COMPLETIONS})."
        return
    fi

    if ! command -v copilot >/dev/null 2>&1; then
        log "Copilot CLI not available for completions setup."
        return
    fi

    if copilot help completion >/dev/null 2>&1; then
        local bash_dir="/etc/bash_completion.d"
        local zsh_dir="/usr/local/share/zsh/site-functions"
        mkdir -p "${bash_dir}" "${zsh_dir}"
        copilot help completion --shell bash >/etc/bash_completion.d/copilot
        copilot help completion --shell zsh >"${zsh_dir}/_copilot"
        log "Installed Copilot CLI completions for bash and zsh."
    else
        log "Copilot CLI does not expose completion helpers; skipping."
    fi
}

cleanup() {
    if command -v apt-get >/dev/null 2>&1; then
        apt-get clean
        rm -rf /var/lib/apt/lists/*
    elif command -v dnf >/dev/null 2>&1; then
        dnf clean all || true
        rm -rf /var/cache/dnf
    elif command -v yum >/dev/null 2>&1; then
        yum clean all || true
        rm -rf /var/cache/yum
    elif command -v apk >/dev/null 2>&1; then
        rm -rf /var/cache/apk/*
    fi
}

main() {
    run_as_root
    ensure_packages
    ensure_node
    ensure_npm_prefix
    install_gh_cli
    install_copilot_cli
    setup_completions
    cleanup
    log "Installation complete."
}

main "$@"
