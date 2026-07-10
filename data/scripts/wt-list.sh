#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVHUB_DIR="${DEVHUB_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
# shellcheck disable=SC2034  # shared header; render_template reads it in sibling scripts
NETWORK_NAME="${DEVHUB_NETWORK:-dev-shared-net}"

# shellcheck source=project-common.sh
source "$SCRIPT_DIR/project-common.sh"

JSON_OUT=0
positional=()
for arg in "$@"; do
  case "$arg" in
    --json) JSON_OUT=1 ;;
    *) positional+=("$arg") ;;
  esac
done

project="${positional[0]:-}"
load_project "$project"

ports_file="$DEVHUB_DIR/docker/$PROJECT_NAME/worktrees.ports"

if [ "$JSON_OUT" -eq 1 ]; then
  printf '{"v":1,"project":%s,"worktrees":[' "$(json_str "$PROJECT_NAME")"
  first=1
  if [ -f "$ports_file" ]; then
    while IFS='|' read -r slug port branch path app_ports; do
      [ -n "$slug" ] || continue
      [ "$first" -eq 1 ] || printf ','
      first=0
      apps_json=""
      [ -n "$app_ports" ] && apps_json=",\"apps\":$(apps_ports_json "$app_ports")"
      printf '{"slug":%s,"port":%s,"branch":%s,"path":%s,"url":%s%s}' \
        "$(json_str "$slug")" \
        "$port" \
        "$(json_str "$branch")" \
        "$(json_str "$path")" \
        "$(json_str "http://localhost:$port")" \
        "$apps_json"
    done < "$ports_file"
  fi
  printf ']}\n'
  exit 0
fi

if [ ! -f "$ports_file" ]; then
  echo "No worktrees registered for $PROJECT_NAME."
  exit 0
fi

printf "%-30s %-24s %s\n" "WORKTREE" "BRANCH" "URL"
printf "%-30s %-24s %s\n" "--------" "------" "---"

# shellcheck disable=SC2034  # path is part of the registry line format
while IFS='|' read -r slug port branch path app_ports; do
  [ -n "$slug" ] || continue
  printf "%-30s %-24s http://localhost:%s %s\n" "$slug" "$branch" "$port" "${app_ports:+($app_ports)}"
done < "$ports_file"
