#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DEPLOY_HOST="${DEPLOY_HOST:-}"
DEPLOY_USER="${DEPLOY_USER:-}"
DEPLOY_PORT="${DEPLOY_PORT:-22}"
DEPLOY_PATH="${DEPLOY_PATH:-/var/www/html}"

if [[ -z "${DEPLOY_HOST}" || -z "${DEPLOY_USER}" ]]; then
  echo "Missing DEPLOY_HOST or DEPLOY_USER"
  echo "Example:"
  echo "  DEPLOY_HOST=5.223.51.101 DEPLOY_USER=openclawuser $0"
  exit 1
fi

SSH_OPTS=(
  -p "${DEPLOY_PORT}"
  -o StrictHostKeyChecking=accept-new
)

SCP_OPTS=(
  -P "${DEPLOY_PORT}"
  -o StrictHostKeyChecking=accept-new
)

if [[ -n "${SSH_KEY_PATH:-}" ]]; then
  SSH_OPTS+=(-i "${SSH_KEY_PATH}" -o IdentitiesOnly=yes)
  SCP_OPTS+=(-i "${SSH_KEY_PATH}" -o IdentitiesOnly=yes)
fi

TMP_ARCHIVE_LOCAL="$(mktemp -t emergo-site.XXXXXX.tgz)"
TMP_NAME="$(basename "${TMP_ARCHIVE_LOCAL}")"

cleanup() {
  rm -f "${TMP_ARCHIVE_LOCAL}"
}
trap cleanup EXIT

cd "${ROOT_DIR}"

tar \
  --exclude=".git" \
  --exclude=".github" \
  --exclude="scripts" \
  --exclude="README.md" \
  -czf "${TMP_ARCHIVE_LOCAL}" \
  .

scp "${SCP_OPTS[@]}" "${TMP_ARCHIVE_LOCAL}" "${DEPLOY_USER}@${DEPLOY_HOST}:/tmp/${TMP_NAME}"

ssh "${SSH_OPTS[@]}" "${DEPLOY_USER}@${DEPLOY_HOST}" \
  "bash -s" -- "${DEPLOY_PATH}" "/tmp/${TMP_NAME}" <<'REMOTE'
set -euo pipefail

DEPLOY_PATH="$1"
TMP_ARCHIVE="$2"
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir" "$TMP_ARCHIVE"' EXIT

mkdir -p "$workdir/site"
tar -xzf "$TMP_ARCHIVE" -C "$workdir/site"

sudo mkdir -p "$DEPLOY_PATH"

# Preserve certbot challenges if present.
if [[ -d "$DEPLOY_PATH/.well-known" ]]; then
  sudo find "$DEPLOY_PATH" -mindepth 1 -maxdepth 1 ! -name '.well-known' -exec rm -rf {} +
else
  sudo find "$DEPLOY_PATH" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
fi

sudo tar -czf "$workdir/site.tar.gz" -C "$workdir/site" .
sudo tar -xzf "$workdir/site.tar.gz" -C "$DEPLOY_PATH"
sudo chown -R root:root "$DEPLOY_PATH"

if command -v nginx >/dev/null 2>&1; then
  sudo nginx -t
  sudo systemctl reload nginx
fi

echo "Deployed to $DEPLOY_PATH"
REMOTE
