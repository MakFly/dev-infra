#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVHUB_DIR="${DEVHUB_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
# shellcheck disable=SC2034  # shared header; render_template reads it in sibling scripts
NETWORK_NAME="${DEVHUB_NETWORK:-dev-shared-net}"

# shellcheck source=project-common.sh
source "$SCRIPT_DIR/project-common.sh"

usage() {
  echo "Usage: devhub wt rm <project> <worktree-slug>" >&2
}

project="${1:-}"
wt="${2:-}"
[ -n "$project" ] && [ -n "$wt" ] || { usage; exit 1; }

load_project "$project"
wt="$(slugify "$wt")"
ports_file="$DEVHUB_DIR/docker/$PROJECT_NAME/worktrees.ports"
[ -f "$ports_file" ] || { echo "No worktrees registered for $PROJECT_NAME." >&2; exit 1; }

line="$(awk -F'|' -v slug="$wt" '$1 == slug { print; found=1 } END { exit found ? 0 : 1 }' "$ports_file")" || {
  echo "Unknown worktree: $wt" >&2
  exit 1
}

target="$(printf '%s' "$line" | awk -F'|' '{ print $4 }')"
[ -n "$target" ] || { echo "Invalid registry entry for $wt" >&2; exit 1; }

rm -f "$target/.env" "$target/.env.local"
git -C "$PROJECT_REPO" worktree remove "$target"
rm -f "$DEVHUB_DIR/docker/$PROJECT_NAME/sites/$wt.caddy"

tmp="$(mktemp)"
awk -F'|' -v slug="$wt" '$1 != slug { print }' "$ports_file" > "$tmp"
mv "$tmp" "$ports_file"

if command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' | grep -q "^${PROJECT_CONTAINER}$"; then
  docker restart "$PROJECT_CONTAINER" >/dev/null
fi

echo "Removed worktree: $PROJECT_NAME/$wt"
