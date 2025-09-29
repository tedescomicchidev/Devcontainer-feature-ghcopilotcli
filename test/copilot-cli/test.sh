#!/bin/bash
set -euo pipefail

source dev-container-features-test-lib

extract_version() {
    local version
    version=$(copilot --version | head -n 1 | sed -n 's/^\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p')
    if [ -z "${version}" ]; then
        version=$(copilot --version | head -n 1 | sed -n 's/^copilot\/\([0-9][^ ]*\).*$/\1/p')
    fi
    echo "${version}"
}

check "copilot on PATH" which copilot
check "copilot version" copilot --version
check "copilot help" copilot --help

INSTALLED_VERSION=$(extract_version)

check "copilot binary is executable" test -x "$(command -v copilot)"

if [ -n "${INSTALLED_VERSION}" ]; then
    check "idempotent reinstall" bash -lc "npm install -g @github/copilot@${INSTALLED_VERSION} && copilot --version | grep -F \"${INSTALLED_VERSION}\""
else
    echo "Unable to determine installed Copilot CLI version" >&2
    exit 1
fi

reportResults
