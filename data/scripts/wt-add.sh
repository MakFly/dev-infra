#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVHUB_DIR="${DEVHUB_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
NETWORK_NAME="${DEVHUB_NETWORK:-dev-shared-net}"

# shellcheck source=project-common.sh
source "$SCRIPT_DIR/project-common.sh"

usage() {
  echo "Usage: devhub wt add <project> <branch> [base-ref]" >&2
}

project="${1:-}"
branch="${2:-}"
base_ref="${3:-}"
[ -n "$project" ] && [ -n "$branch" ] || { usage; exit 1; }

load_project "$project"
[ -n "$base_ref" ] || base_ref="$PROJECT_BASE_REF"

WORKTREE_SLUG="$(slugify "$branch")"
[ -n "$WORKTREE_SLUG" ] || { echo "Invalid branch slug: $branch" >&2; exit 1; }

target="$PROJECT_WORKTREES/$WORKTREE_SLUG"
ports_file="$DEVHUB_DIR/docker/$PROJECT_NAME/worktrees.ports"
mkdir -p "$PROJECT_WORKTREES" "$(dirname "$ports_file")"
touch "$ports_file"

if [ -e "$target" ]; then
  echo "Worktree path already exists: $target" >&2
  exit 1
fi

if awk -F'|' -v slug="$WORKTREE_SLUG" '$1 == slug { found=1 } END { exit found ? 0 : 1 }' "$ports_file"; then
  echo "Worktree already registered: $WORKTREE_SLUG" >&2
  exit 1
fi

pick_port() {
  local port
  for port in $(seq "$PROJECT_PORT_START" "$PROJECT_PORT_END"); do
    if awk -F'|' -v port="$port" '$2 == port { found=1 } END { exit found ? 0 : 1 }' "$ports_file"; then
      continue
    fi
    if command -v ss >/dev/null 2>&1 && ss -H -ltn "sport = :$port" | grep -q .; then
      continue
    fi
    echo "$port"
    return 0
  done
  return 1
}

WORKTREE_PORT="$(pick_port)" || {
  echo "No free port in $PROJECT_PORT_START-$PROJECT_PORT_END" >&2
  exit 1
}

repo="$PROJECT_REPO"
if [ "$PROJECT_REPO_KIND" = "bare" ]; then
  git -C "$repo" fetch --all --prune >/dev/null 2>&1 || true
else
  git -C "$repo" fetch --all --prune >/dev/null 2>&1 || true
fi

if git -C "$repo" show-ref --verify --quiet "refs/heads/$branch"; then
  git -C "$repo" worktree add "$target" "$branch"
else
  git -C "$repo" worktree add -b "$branch" "$target" "$base_ref"
fi

WORKTREE_DB="$(underscore_slug "${PROJECT_NAME}_${WORKTREE_SLUG}")"
WORKTREE_DB_USER="$WORKTREE_DB"
WORKTREE_DB_PASSWORD="$WORKTREE_DB"
WORKTREE_REDIS_PREFIX="$WORKTREE_DB"

template_dir="$DEVHUB_DIR/templates/$PROJECT_STACK"
if [ -f "$template_dir/worktree.env.tpl" ] && [ ! -f "$target/.env" ]; then
  render_template "$template_dir/worktree.env.tpl" "$target/.env"
elif [ -f "$template_dir/worktree.env.local.tpl" ] && [ ! -f "$target/.env.local" ]; then
  render_template "$template_dir/worktree.env.local.tpl" "$target/.env.local"
fi

if [ -f "$template_dir/site.caddy.tpl" ]; then
  render_template "$template_dir/site.caddy.tpl" "$DEVHUB_DIR/docker/$PROJECT_NAME/sites/$WORKTREE_SLUG.caddy"
fi

printf '%s|%s|%s|%s\n' "$WORKTREE_SLUG" "$WORKTREE_PORT" "$branch" "$target" >> "$ports_file"

if command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' | grep -q "^${PROJECT_CONTAINER}$"; then
  docker restart "$PROJECT_CONTAINER" >/dev/null
fi

cat <<EOF

Worktree ready
Project: $PROJECT_NAME
Branch:  $branch
Slug:    $WORKTREE_SLUG
Path:    $target
URL:     http://localhost:$WORKTREE_PORT

Next:
  devhub runtime $PROJECT_NAME
EOF
