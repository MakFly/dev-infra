#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVHUB_DIR="${DEVHUB_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
# shellcheck disable=SC2034  # shared header; render_template reads it in sibling scripts
NETWORK_NAME="${DEVHUB_NETWORK:-dev-shared-net}"

# shellcheck source=project-common.sh
source "$SCRIPT_DIR/project-common.sh"

usage() {
  echo "Usage: devhub wt rm <project> <worktree-slug> [--json] [--force]" >&2
  echo "Exit codes: 0 removed, 5 worktree has uncommitted/untracked changes" >&2
}

JSON_OUT=0
FORCE=0
positional=()
for arg in "$@"; do
  case "$arg" in
    --json) JSON_OUT=1 ;;
    --force) FORCE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) positional+=("$arg") ;;
  esac
done

project="${positional[0]:-}"
wt="${positional[1]:-}"
[ -n "$project" ] && [ -n "$wt" ] || { usage; exit 1; }

load_project "$project"
wt="$(slugify "$wt")"
ports_file="$DEVHUB_DIR/docker/$PROJECT_NAME/worktrees.ports"
[ -f "$ports_file" ] || { echo "No worktrees registered for $PROJECT_NAME." >&2; exit 1; }

# Serialize registry reads/writes across concurrent wt add / wt rm calls.
exec 9>"$ports_file.lock"
if command -v flock >/dev/null 2>&1; then
  flock 9
fi

line="$(awk -F'|' -v slug="$wt" '$1 == slug { print; found=1 } END { exit found ? 0 : 1 }' "$ports_file")" || {
  echo "Unknown worktree: $wt" >&2
  exit 1
}

target="$(printf '%s' "$line" | awk -F'|' '{ print $4 }')"
[ -n "$target" ] || { echo "Invalid registry entry for $wt" >&2; exit 1; }

# Refuse to delete work in progress unless --force. The generated env
# files are excluded: DevHub created them, DevHub may remove them.
if [ "$FORCE" -eq 0 ] && [ -d "$target" ]; then
  dirt="$(git -C "$target" status --porcelain 2>/dev/null | grep -v -E '^\?\? \.env(\.local)?$' || true)"
  if [ -n "$dirt" ]; then
    echo "Worktree has uncommitted or untracked changes: $target" >&2
    echo "Commit or stash them, or re-run with --force." >&2
    exit 5
  fi
fi

rm -f "$target/.env" "$target/.env.local"
if [ "$FORCE" -eq 1 ]; then
  git -C "$PROJECT_REPO" worktree remove --force "$target"
else
  git -C "$PROJECT_REPO" worktree remove "$target"
fi
rm -f "$DEVHUB_DIR/docker/$PROJECT_NAME/sites/$wt.caddy"

tmp="$(mktemp)"
awk -F'|' -v slug="$wt" '$1 != slug { print }' "$ports_file" > "$tmp"
mv "$tmp" "$ports_file"

if command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' | grep -q "^${PROJECT_CONTAINER}$"; then
  docker restart "$PROJECT_CONTAINER" >/dev/null
fi

if [ "$JSON_OUT" -eq 1 ]; then
  printf '{"v":1,"status":"removed","project":%s,"slug":%s,"removed":true}\n' \
    "$(json_str "$PROJECT_NAME")" "$(json_str "$wt")"
  exit 0
fi

echo "Removed worktree: $PROJECT_NAME/$wt"
