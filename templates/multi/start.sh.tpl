#!/usr/bin/env bash
set -euo pipefail

ports_file="/devhub/worktrees.ports"
runtime_port="${PROJECT_RUNTIME_PORT:-8100}"

python3 -m http.server "$runtime_port" --bind 0.0.0.0 --directory /worktrees >/tmp/devhub-dashboard.log 2>&1 &

if [ ! -s "$ports_file" ]; then
  echo "No worktrees registered for ${PROJECT_NAME:-project}."
  tail -f /tmp/devhub-dashboard.log
fi

# "web=8101,api=8102" + name -> port
app_port_for() {
  awk -v RS=',' -F'=' -v n="$2" '$1 == n { gsub(/[^0-9]/, "", $2); print $2 }' <<< "$1"
}

app_dev_command() {
  case "$1" in
    nextjs)
      echo 'bun install && exec bun run dev --hostname 0.0.0.0 --port "$DEVHUB_PORT"' ;;
    tanstack-start|hono)
      echo 'bun install && exec bun run dev --host 0.0.0.0 --port "$DEVHUB_PORT"' ;;
    fastapi-ddd)
      echo '[ -d .venv ] || python3 -m venv .venv
        if [ -f requirements.txt ]; then ./.venv/bin/pip install -q -r requirements.txt
        elif [ -f pyproject.toml ]; then ./.venv/bin/pip install -q -e .
        fi
        [ -x ./.venv/bin/uvicorn ] || ./.venv/bin/pip install -q uvicorn
        exec ./.venv/bin/python -m uvicorn app.main:app --host 0.0.0.0 --port "$DEVHUB_PORT" --reload' ;;
    *)
      echo '' ;;
  esac
}

IFS=',' read -ra app_defs <<< "${PROJECT_APPS:-}"

pids=()
while IFS='|' read -r slug port branch path app_ports; do
  [ -n "$slug" ] || continue
  workdir="/worktrees/$slug"
  if [ ! -d "$workdir" ]; then
    echo "Skipping missing worktree: $workdir" >&2
    continue
  fi
  for app_def in "${app_defs[@]}"; do
    [ -n "$app_def" ] || continue
    app_name="${app_def%%=*}"
    app_rest="${app_def#*=}"
    app_dir="${app_rest%%=*}"
    app_stack="${app_rest#*=}"
    app_port="$(app_port_for "$app_ports" "$app_name")"
    if [ -z "$app_port" ]; then
      echo "No port registered for app $app_name in $slug" >&2
      continue
    fi
    cmd="$(app_dev_command "$app_stack")"
    if [ -z "$cmd" ]; then
      echo "Unsupported app stack for $app_name: $app_stack" >&2
      continue
    fi
    (
      cd "$workdir/$app_dir"
      export DEVHUB_PORT="$app_port"
      export PORT="$app_port"
      export HOST="0.0.0.0"
      for peer_def in "${app_defs[@]}"; do
        peer_name="${peer_def%%=*}"
        peer_port="$(app_port_for "$app_ports" "$peer_name")"
        [ -n "$peer_port" ] || continue
        peer_var="DEVHUB_$(printf '%s' "$peer_name" | tr '[:lower:]-' '[:upper:]_')_URL"
        export "$peer_var=http://localhost:$peer_port"
      done
      exec bash -c "$cmd"
    ) &
    pids+=("$!")
  done
done < "$ports_file"

trap 'for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done' INT TERM EXIT
wait -n "${pids[@]}"
