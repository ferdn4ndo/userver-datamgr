#!/bin/sh
# Generate a self-signed TLS certificate for local Docker Postgres (development only).
# Requires: openssl on the host. Run from repo root: ./postgres/generate-ssl.sh

set -e
SCRIPT_DIR=$(cd -- "$(dirname "$0")" && pwd)
SSL_DIR="${SCRIPT_DIR}/ssl"
DAYS="${SSL_DAYS:-3650}"
CN="${SSL_CN:-userver-postgres}"

mkdir -p "$SSL_DIR"
if [ -f "${SSL_DIR}/server.key" ] || [ -f "${SSL_DIR}/server.crt" ]; then
  echo "Refusing to overwrite existing ${SSL_DIR}/server.key or server.crt — remove them first." >&2
  exit 1
fi

openssl req -new -x509 -nodes -days "$DAYS" \
  -keyout "${SSL_DIR}/server.key" \
  -out "${SSL_DIR}/server.crt" \
  -subj "/CN=${CN}/O=userver-datamgr/OU=dev"

chmod 600 "${SSL_DIR}/server.key"
echo "Wrote ${SSL_DIR}/server.crt and server.key (self-signed, ${DAYS} days)."
