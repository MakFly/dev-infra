#!/usr/bin/env bash
# Import trading + distribution DB dumps from pro/tilvest/data/
# Usage: ./import-db.sh [trading|distribution|all]
# Default: all

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVHUB_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LAB_DIR="$(cd "$DEVHUB_DIR/.." && pwd)"
[ -f "$DEVHUB_DIR/.env" ] && set -a && source "$DEVHUB_DIR/.env" && set +a

DATA_DIR="${DATA_DIR:-$LAB_DIR/pro/tilvest/data}"
MYSQL_CONTAINER="${MYSQL_CONTAINER:-infra-mysql}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-root}"

TRADING_SQL="${DATA_DIR}/PRODUCTION-trading_app.sql"
DISTRIB_SQL="${DATA_DIR}/PRODUCTION-distribution_app.sql"

target="${1:-all}"

if ! docker ps --format '{{.Names}}' | grep -q "^${MYSQL_CONTAINER}$"; then
  echo "Error: MySQL container '$MYSQL_CONTAINER' is not running." >&2
  echo "Run: devhub up (or make up)" >&2
  exit 1
fi

import_trading() {
  if [[ ! -f "$TRADING_SQL" ]]; then
    echo "Error: $TRADING_SQL not found" >&2
    return 1
  fi
  echo "Creating database 'trading' if needed..."
  docker exec "$MYSQL_CONTAINER" mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS \`trading\`;"
  echo "Importing trading_app -> trading..."
  docker exec -i "$MYSQL_CONTAINER" mysql -u root -p"$MYSQL_ROOT_PASSWORD" trading < "$TRADING_SQL"
  echo "Done: trading"
}

import_distribution() {
  if [[ ! -f "$DISTRIB_SQL" ]]; then
    echo "Error: $DISTRIB_SQL not found" >&2
    return 1
  fi
  echo "Creating database 'distribution' if needed..."
  docker exec "$MYSQL_CONTAINER" mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "
    CREATE DATABASE IF NOT EXISTS \`distribution\`;
    GRANT ALL PRIVILEGES ON distribution.* TO '${MYSQL_USER:-test}'@'%';
    FLUSH PRIVILEGES;
  "
  echo "Importing distribution_app -> distribution..."
  docker exec -i "$MYSQL_CONTAINER" mysql -u root -p"$MYSQL_ROOT_PASSWORD" distribution < "$DISTRIB_SQL"
  echo "Done: distribution"
}

case "$target" in
  trading)
    import_trading
    ;;
  distribution|dist)
    import_distribution
    ;;
  all)
    import_trading
    import_distribution
    echo ""
    echo "Both databases imported."
    ;;
  *)
    echo "Usage: $0 [trading|distribution|all]" >&2
    exit 1
    ;;
esac
