#!/usr/bin/env bash
set -euo pipefail

ports_file="/devhub/worktrees.ports"
runtime_port="${PROJECT_RUNTIME_PORT:-8100}"

python3 -m http.server "$runtime_port" --bind 0.0.0.0 --directory /worktrees >/tmp/devhub-dashboard.log 2>&1 &

if [ ! -s "$ports_file" ]; then
  echo "No worktrees registered for ${PROJECT_NAME:-project}."
  tail -f /tmp/devhub-dashboard.log
fi

pids=()
while IFS='|' read -r slug port branch path; do
  [ -n "$slug" ] || continue
  workdir="/worktrees/$slug"
  [ -d "$workdir" ] || continue
  (
    cd "$workdir"
    export DEVHUB_PORT="$port"
    export PORT="$port"
    export HOST="0.0.0.0"
    bash -lc "$PROJECT_DEV_COMMAND"
  ) &
  pids+=("$!")
done < "$ports_file"

trap 'for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done' INT TERM EXIT
wait -n "${pids[@]}"
