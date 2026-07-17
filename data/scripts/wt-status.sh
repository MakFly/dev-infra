#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVHUB_DIR="${DEVHUB_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

# shellcheck source=project-common.sh
source "$SCRIPT_DIR/project-common.sh"

usage() {
  echo "Usage: devhub wt status <project> [worktree-slug] [--json]" >&2
}

JSON_OUT=0
positional=()
for arg in "$@"; do
  case "$arg" in
    --json) JSON_OUT=1 ;;
    -h|--help) usage; exit 0 ;;
    *) positional+=("$arg") ;;
  esac
done

project="${positional[0]:-}"
only_slug="${positional[1]:-}"
[ -n "$project" ] || { usage; exit 1; }

load_project "$project"
[ -z "$only_slug" ] || only_slug="$(slugify "$only_slug")"

ports_file="$DEVHUB_DIR/docker/$PROJECT_NAME/worktrees.ports"

runtime_state="unknown"
if command -v docker >/dev/null 2>&1; then
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${PROJECT_CONTAINER}$"; then
    runtime_state="up"
  else
    runtime_state="down"
  fi
fi

http_state() {
  command -v curl >/dev/null 2>&1 || { echo "unknown"; return; }
  if curl -fsS -m 2 -o /dev/null "http://localhost:$1" 2>/dev/null; then
    echo "ok"
  else
    echo "down"
  fi
}

db_state() {
  postgres_running || { echo "unknown"; return; }
  if worktree_db_exists "$1"; then
    echo "ok"
  else
    echo "missing"
  fi
}

if [ "$JSON_OUT" -eq 1 ]; then
  printf '{"v":1,"project":%s,"runtime":%s,"worktrees":[' \
    "$(json_str "$PROJECT_NAME")" "$(json_str "$runtime_state")"
else
  echo "Runtime ($PROJECT_CONTAINER): $runtime_state"
  printf "%-30s %-8s %-8s %-8s\n" "WORKTREE" "PORT" "HTTP" "DB"
  printf "%-30s %-8s %-8s %-8s\n" "--------" "----" "----" "--"
fi

found=0
first=1
if [ -f "$ports_file" ]; then
  # shellcheck disable=SC2034  # branch/path/app_ports/group/owns are part of the registry line format
  while IFS='|' read -r slug port branch path app_ports group owns; do
    [ -n "$slug" ] || continue
    if [ -n "$only_slug" ] && [ "$slug" != "$only_slug" ]; then
      continue
    fi
    found=1
    db="$(underscore_slug "${PROJECT_NAME}_${slug}")"
    http="$(http_state "$port")"
    dbst="$(db_state "$db")"
    if [ "$JSON_OUT" -eq 1 ]; then
      [ "$first" -eq 1 ] || printf ','
      first=0
      printf '{"slug":%s,"port":%s,"url":%s,"http":%s,"db":%s}' \
        "$(json_str "$slug")" \
        "$port" \
        "$(json_str "http://localhost:$port")" \
        "$(json_str "$http")" \
        "$(json_str "$dbst")"
    else
      printf "%-30s %-8s %-8s %-8s\n" "$slug" "$port" "$http" "$dbst"
    fi
  done < "$ports_file"
fi

if [ "$JSON_OUT" -eq 1 ]; then
  printf ']}\n'
fi

if [ -n "$only_slug" ] && [ "$found" -eq 0 ]; then
  echo "Unknown worktree: $only_slug" >&2
  exit 1
fi
