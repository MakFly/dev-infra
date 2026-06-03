#!/usr/bin/env bash
set -euo pipefail

services=(
  infra-postgres
  infra-mysql
  infra-redis
  infra-meilisearch
  infra-mailpit
  infra-adminer
  infra-dozzle
  infra-rabbitmq
  infra-node
)

printf "%-24s %-10s %-12s\n" "CONTAINER" "RUNNING" "HEALTH"
printf "%-24s %-10s %-12s\n" "--------" "-------" "------"

for c in "${services[@]}"; do
  if docker ps -a --format '{{.Names}}' | grep -q "^${c}$"; then
    running="no"
    if docker ps --format '{{.Names}}' | grep -q "^${c}$"; then
      running="yes"
    fi
    health=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}n/a{{end}}' "$c" 2>/dev/null || echo "n/a")
    printf "%-24s %-10s %-12s\n" "$c" "$running" "$health"
  fi
done
