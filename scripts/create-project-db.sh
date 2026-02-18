#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <db_name> [db_user] [db_password]" >&2
  exit 1
fi

DB_NAME="$1"
DB_USER="${2:-$DB_NAME}"
DB_PASSWORD="${3:-$DB_NAME}"
POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-infra-postgres}"
POSTGRES_ADMIN_USER="${POSTGRES_ADMIN_USER:-test}"

name_re='^[a-zA-Z_][a-zA-Z0-9_]{0,62}$'
if [[ ! "$DB_NAME" =~ $name_re ]]; then
  echo "Invalid DB name: $DB_NAME" >&2
  exit 1
fi
if [[ ! "$DB_USER" =~ $name_re ]]; then
  echo "Invalid DB user: $DB_USER" >&2
  exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -q "^${POSTGRES_CONTAINER}$"; then
  echo "Postgres container '$POSTGRES_CONTAINER' is not running." >&2
  echo "Run: devhub up" >&2
  exit 1
fi

escaped_password=${DB_PASSWORD//\'/\'\'}

if ! docker exec "$POSTGRES_CONTAINER" psql -U "$POSTGRES_ADMIN_USER" -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | grep -q 1; then
  docker exec "$POSTGRES_CONTAINER" psql -U "$POSTGRES_ADMIN_USER" -d postgres -v ON_ERROR_STOP=1 -c "CREATE ROLE \"${DB_USER}\" LOGIN PASSWORD '${escaped_password}';"
  echo "Role created: ${DB_USER}"
else
  echo "Role exists: ${DB_USER}"
fi

if ! docker exec "$POSTGRES_CONTAINER" psql -U "$POSTGRES_ADMIN_USER" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then
  docker exec "$POSTGRES_CONTAINER" psql -U "$POSTGRES_ADMIN_USER" -d postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE \"${DB_NAME}\" OWNER \"${DB_USER}\";"
  echo "Database created: ${DB_NAME}"
else
  echo "Database exists: ${DB_NAME}"
fi

docker exec "$POSTGRES_CONTAINER" psql -U "$POSTGRES_ADMIN_USER" -d postgres -v ON_ERROR_STOP=1 -c "GRANT ALL PRIVILEGES ON DATABASE \"${DB_NAME}\" TO \"${DB_USER}\";" >/dev/null

echo "Done: db=${DB_NAME} user=${DB_USER}"
