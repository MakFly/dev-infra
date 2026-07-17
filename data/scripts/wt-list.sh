#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVHUB_DIR="${DEVHUB_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
# shellcheck disable=SC2034  # shared header; render_template reads it in sibling scripts
NETWORK_NAME="${DEVHUB_NETWORK:-dev-shared-net}"

# shellcheck source=project-common.sh
source "$SCRIPT_DIR/project-common.sh"

JSON_OUT=0
GROUP=""
positional=()
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON_OUT=1 ;;
    --group) GROUP="${2:-}"; shift ;;
    --group=*) GROUP="${1#*=}" ;;
    *) positional+=("$1") ;;
  esac
  shift
done

project="${positional[0]:-}"
load_project "$project"
[ -z "$GROUP" ] || GROUP="$(slugify "$GROUP")"

ports_file="$DEVHUB_DIR/docker/$PROJECT_NAME/worktrees.ports"

if [ "$JSON_OUT" -eq 1 ]; then
  printf '{"v":1,"project":%s,"worktrees":[' "$(json_str "$PROJECT_NAME")"
  first=1
  if [ -f "$ports_file" ]; then
    while IFS='|' read -r slug port branch path app_ports group owns; do
      [ -n "$slug" ] || continue
      [ -z "$GROUP" ] || [ "$group" = "$GROUP" ] || continue
      [ "$first" -eq 1 ] || printf ','
      first=0
      apps_json=""
      [ -n "$app_ports" ] && apps_json=",\"apps\":$(apps_ports_json "$app_ports")"
      printf '{"slug":%s,"port":%s,"branch":%s,"path":%s,"url":%s,"group":%s,"owns":%s%s}' \
        "$(json_str "$slug")" \
        "$port" \
        "$(json_str "$branch")" \
        "$(json_str "$path")" \
        "$(json_str "http://localhost:$port")" \
        "$(json_str "$group")" \
        "$(csv_json_array "$owns")" \
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

printf "%-30s %-24s %-12s %s\n" "WORKTREE" "BRANCH" "GROUP" "URL"
printf "%-30s %-24s %-12s %s\n" "--------" "------" "-----" "---"

# shellcheck disable=SC2034  # path/owns are part of the registry line format
while IFS='|' read -r slug port branch path app_ports group owns; do
  [ -n "$slug" ] || continue
  [ -z "$GROUP" ] || [ "$group" = "$GROUP" ] || continue
  printf "%-30s %-24s %-12s http://localhost:%s %s\n" "$slug" "$branch" "${group:--}" "$port" "${app_ports:+($app_ports)}"
done < "$ports_file"
