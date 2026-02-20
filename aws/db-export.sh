#!/usr/bin/env bash
#
# Dump Aurora MySQL cluster to tmp/export.sql
#

set -euo pipefail
cd "$(dirname "$0")"

set -a
. export.env
set +a

SCRIPT_DIR="$(pwd)"
cd "$SCRIPT_DIR"

# Optional first argument = single database to migrate
MIGRATE_DB="${1:-${MIGRATE_DB:-}}"

# --- Config ---
: "${AURORA_PORT:=3306}"

# Resolve Aurora password
get_aurora_password() {
  if [[ -n "${AURORA_PASSWORD:-}" ]]; then
    echo -n "$AURORA_PASSWORD"
    return
  fi
  if [[ -z "${AURORA_SECRET_ARN:-}" ]]; then
    echo "Need AURORA_SECRET_ARN or AURORA_PASSWORD" >&2
    return 1
  fi
  aws secretsmanager get-secret-value --secret-id "$AURORA_SECRET_ARN" --query SecretString --output text | jq -r '.password'
}

# --- Validate ---
: "${AURORA_HOST:?Set AURORA_HOST (Aurora writer/reader endpoint)}"
: "${AURORA_USER:?Set AURORA_USER}"

AURORA_PASS="$(get_aurora_password)"

# Optional SSL for Aurora
AURORA_SSL_ARGS=()
if [[ -n "${AURORA_SSL_CA:-}" && -f "${AURORA_SSL_CA}" ]]; then
  AURORA_SSL_ARGS=(--ssl-mode=VERIFY_CA --ssl-ca="$AURORA_SSL_CA")
fi

mkdir -p ./tmp
OUTPUT_FILE="./tmp/export.sql"

# --- Dump ---
echo "Dumping from Aurora ${AURORA_HOST}:${AURORA_PORT} to ${OUTPUT_FILE} ..."

if [[ -n "$MIGRATE_DB" ]]; then
  # Single database
  mysqldump -h "$AURORA_HOST" -P "$AURORA_PORT" -u "$AURORA_USER" -p"$AURORA_PASS" \
    --single-transaction \
    --routines \
    --triggers \
    --set-gtid-purged=OFF \
    --no-tablespaces \
    ${AURORA_SSL_ARGS[@]+"${AURORA_SSL_ARGS[@]}"} \
    "$MIGRATE_DB" > "$OUTPUT_FILE"
  echo "Exported database: $MIGRATE_DB"
else
  # All user databases (exclude system DBs)
  DBS="$(
    mysql -h "$AURORA_HOST" -P "$AURORA_PORT" -u "$AURORA_USER" -p"$AURORA_PASS" \
      -N -e "SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT IN ('mysql','information_schema','performance_schema','sys');" \
      ${AURORA_SSL_ARGS[@]+"${AURORA_SSL_ARGS[@]}"}
  )"
  if [[ -z "${DBS//[$'\r\n']/}" ]]; then
    echo "No user databases found on Aurora." >&2
    exit 1
  fi
  mysqldump -h "$AURORA_HOST" -P "$AURORA_PORT" -u "$AURORA_USER" -p"$AURORA_PASS" \
    --single-transaction \
    --routines \
    --triggers \
    --set-gtid-purged=OFF \
    --no-tablespaces \
    --databases $DBS \
    ${AURORA_SSL_ARGS[@]+"${AURORA_SSL_ARGS[@]}"} > "$OUTPUT_FILE"
  echo "Exported databases: $DBS"
fi

echo "Done."
