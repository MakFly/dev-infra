#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <container_name> [network_name]" >&2
  exit 1
fi

container="$1"
network="${2:-dev-shared-net}"

if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
  echo "Container not running: ${container}" >&2
  exit 1
fi

if ! docker network inspect "$network" >/dev/null 2>&1; then
  docker network create "$network" >/dev/null
  echo "Network created: $network"
fi

if docker network inspect "$network" -f '{{range .Containers}}{{println .Name}}{{end}}' | grep -q "^${container}$"; then
  echo "Already connected: ${container} -> ${network}"
else
  docker network connect "$network" "$container"
  echo "Connected: ${container} -> ${network}"
fi
