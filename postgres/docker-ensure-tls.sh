#!/bin/sh
# Prepare TLS paths then exec the upstream Postgres entrypoint.
# Priority: POSTGRES_SSL_CERT_BASENAME + /etc/nginx/certs (userver-web acme-companion) else ssl-local (generate-ssl.sh).
#
# Bind-mounted certs are often owned by the host user (e.g. CI uid 1001) with mode 600; the server runs as postgres
# (uid 70) and cannot open them. We copy into /tmp, chown postgres, then point -c ssl_* at the copies.

set -e

CERT_BASENAME="${POSTGRES_SSL_CERT_BASENAME:-}"
NGINX_CRT="/etc/nginx/certs/${CERT_BASENAME}.crt"
NGINX_KEY="/etc/nginx/certs/${CERT_BASENAME}.key"
LOCAL_CRT="/etc/postgresql/ssl-local/server.crt"
LOCAL_KEY="/etc/postgresql/ssl-local/server.key"
STAGE=/tmp/postgres-ssl

stage_tls_pair() {
  _crt=$1
  _key=$2
  rm -rf "${STAGE}"
  mkdir -p "${STAGE}"
  cp "${_crt}" "${STAGE}/server.crt"
  cp "${_key}" "${STAGE}/server.key"
  chown postgres:postgres "${STAGE}/server.crt" "${STAGE}/server.key"
  chmod 644 "${STAGE}/server.crt"
  chmod 600 "${STAGE}/server.key"
}

# First prod boot may start before acme-companion has written the cert (userver-web deploy order).
if [ -n "${CERT_BASENAME}" ]; then
  _wait=0
  while [ "${_wait}" -lt 120 ] && { [ ! -r "${NGINX_CRT}" ] || [ ! -r "${NGINX_KEY}" ]; }; do
    if [ "${_wait}" -eq 0 ] || [ "$((_wait % 20))" -eq 0 ]; then
      echo "docker-ensure-tls: waiting for ${NGINX_CRT} (acme-companion / Let's Encrypt)..."
    fi
    sleep 2
    _wait=$((_wait + 2))
  done
fi

if [ -n "${CERT_BASENAME}" ] && [ -r "${NGINX_CRT}" ] && [ -r "${NGINX_KEY}" ]; then
  stage_tls_pair "${NGINX_CRT}" "${NGINX_KEY}"
elif [ -f "${LOCAL_CRT}" ] && [ -f "${LOCAL_KEY}" ]; then
  stage_tls_pair "${LOCAL_CRT}" "${LOCAL_KEY}"
else
  echo "PostgreSQL TLS: provide Let's Encrypt files at /etc/nginx/certs/\${POSTGRES_SSL_CERT_BASENAME}.{crt,key}" >&2
  echo "  (set POSTGRES_SSL_CERT_BASENAME and USERVER_WEB_CERTS_DIR in .env), or run ./postgres/generate-ssl.sh for ssl-local." >&2
  exit 1
fi

exec /usr/local/bin/docker-entrypoint.sh postgres \
  -c "config_file=/etc/postgresql/config/postgresql.conf" \
  -c "ssl_cert_file=${STAGE}/server.crt" \
  -c "ssl_key_file=${STAGE}/server.key"
