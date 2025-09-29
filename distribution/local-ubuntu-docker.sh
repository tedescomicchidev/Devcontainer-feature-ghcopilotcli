#!/usr/bin/env bash
set -euo pipefail

# Helper script to publish the Feature collection from an Ubuntu host with Docker.
# It mirrors the GitHub Actions workflow but runs locally using the devcontainers
# CLI container image so no additional dependencies are required on the host.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REGISTRY_HOST="${REGISTRY_HOST:-ghcr.io}"

# Attempt to detect the default namespace from the git remote (owner/repo).
DEFAULT_NAMESPACE="local/features"
if command -v git >/dev/null 2>&1; then
  if origin_url=$(git -C "${REPO_ROOT}" remote get-url origin 2>/dev/null); then
    stripped="${origin_url%.git}"
    stripped="${stripped#git@}"
    stripped="${stripped#https://}"
    stripped="${stripped#http://}"
    stripped="${stripped#github.com/}"
    stripped="${stripped#github.com:}"
    if [[ "${stripped}" == */* ]]; then
      DEFAULT_NAMESPACE="${stripped}"
    fi
  fi
fi

FEATURES_NAMESPACE="${FEATURES_NAMESPACE:-${DEFAULT_NAMESPACE}}"
FEATURES_NAMESPACE="$(echo "${FEATURES_NAMESPACE}" | tr '[:upper:]' '[:lower:]')"
COLLECTION="${COLLECTION:-${FEATURES_NAMESPACE}}"
OCI_REF="${REGISTRY_HOST}/${COLLECTION}"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required to run this script." >&2
  exit 1
fi

if [ "${REGISTRY_HOST}" != "localhost" ]; then
  cat <<EOF1
[info] Pushing to ${REGISTRY_HOST}. Ensure you have run 'docker login ${REGISTRY_HOST}'
      (or 'gh auth login --scopes write:packages') before executing this script.
EOF1
fi

# Use the devcontainers CLI container to publish the Features.
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "${REPO_ROOT}:/workspaces/repo" \
  -w /workspaces/repo \
  ghcr.io/devcontainers/ci:latest \
  devcontainer features publish \
    --registry "${REGISTRY_HOST}" \
    --namespace "${FEATURES_NAMESPACE}" \
    --base-path ./src

cat <<EOF2
Successfully published feature collection to ${OCI_REF}.
Remember to adjust package visibility in GHCR if you want the Features to be public.
EOF2
