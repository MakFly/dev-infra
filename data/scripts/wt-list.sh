#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVHUB_DIR="${DEVHUB_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
NETWORK_NAME="${DEVHUB_NETWORK:-dev-shared-net}"

# shellcheck source=project-common.sh
source "$SCRIPT_DIR/project-common.sh"

project="${1:-}"
load_project "$project"

ports_file="$DEVHUB_DIR/docker/$PROJECT_NAME/worktrees.ports"
if [ ! -f "$ports_file" ]; then
  echo "No worktrees registered for $PROJECT_NAME."
  exit 0
fi

printf "%-30s %-24s %s\n" "WORKTREE" "BRANCH" "URL"
printf "%-30s %-24s %s\n" "--------" "------" "---"

while IFS='|' read -r slug port branch path; do
  [ -n "$slug" ] || continue
  printf "%-30s %-24s http://localhost:%s\n" "$slug" "$branch" "$port"
done < "$ports_file"
