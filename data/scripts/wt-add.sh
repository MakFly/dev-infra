#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVHUB_DIR="${DEVHUB_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
# shellcheck disable=SC2034  # consumed by render_template via __DEVHUB_NETWORK__
NETWORK_NAME="${DEVHUB_NETWORK:-dev-shared-net}"

# shellcheck source=project-common.sh
source "$SCRIPT_DIR/project-common.sh"

usage() {
  echo "Usage: devhub wt add <project> <branch> [base-ref] [--json]" >&2
  echo "Exit codes: 0 created, 3 already registered, 4 no free port" >&2
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
branch="${positional[1]:-}"
base_ref="${positional[2]:-}"
[ -n "$project" ] && [ -n "$branch" ] || { usage; exit 1; }

load_project "$project"
[ -n "$base_ref" ] || base_ref="$PROJECT_BASE_REF"

WORKTREE_SLUG="$(slugify "$branch")"
[ -n "$WORKTREE_SLUG" ] || { echo "Invalid branch slug: $branch" >&2; exit 1; }

target="$PROJECT_WORKTREES/$WORKTREE_SLUG"
ports_file="$DEVHUB_DIR/docker/$PROJECT_NAME/worktrees.ports"
mkdir -p "$PROJECT_WORKTREES" "$(dirname "$ports_file")"
touch "$ports_file"

# Serialize registry reads/writes across concurrent wt add / wt rm calls.
# The lock is held until the script exits.
exec 9>"$ports_file.lock"
if command -v flock >/dev/null 2>&1; then
  flock 9
fi

WORKTREE_DB="$(underscore_slug "${PROJECT_NAME}_${WORKTREE_SLUG}")"
WORKTREE_DB_USER="$WORKTREE_DB"
WORKTREE_DB_PASSWORD="$WORKTREE_DB"
WORKTREE_REDIS_PREFIX="$WORKTREE_DB"

worktree_env_file() {
  if [ -f "$1/.env" ]; then
    printf '%s' "$1/.env"
  elif [ -f "$1/.env.local" ]; then
    printf '%s' "$1/.env.local"
  fi
}

print_worktree_json() {
  local state="$1" port="$2" provisioned="$3"
  printf '{"v":1,"status":%s,"project":%s,"slug":%s,"branch":%s,"path":%s,"port":%s,"url":%s,"db":%s,"db_user":%s,"redis_prefix":%s,"env_path":%s,"container":%s,"db_provisioned":%s}\n' \
    "$(json_str "$state")" \
    "$(json_str "$PROJECT_NAME")" \
    "$(json_str "$WORKTREE_SLUG")" \
    "$(json_str "$branch")" \
    "$(json_str "$target")" \
    "$port" \
    "$(json_str "http://localhost:$port")" \
    "$(json_str "$WORKTREE_DB")" \
    "$(json_str "$WORKTREE_DB_USER")" \
    "$(json_str "$WORKTREE_REDIS_PREFIX")" \
    "$(json_str "$(worktree_env_file "$target")")" \
    "$(json_str "$PROJECT_CONTAINER")" \
    "$provisioned"
}

existing_line="$(awk -F'|' -v slug="$WORKTREE_SLUG" '$1 == slug { print; exit }' "$ports_file")"
if [ -n "$existing_line" ]; then
  existing_port="$(printf '%s' "$existing_line" | awk -F'|' '{ print $2 }')"
  if [ "$JSON_OUT" -eq 1 ]; then
    provisioned=false
    if postgres_running && worktree_db_exists "$WORKTREE_DB"; then
      provisioned=true
    fi
    print_worktree_json "exists" "$existing_port" "$provisioned"
  else
    echo "Worktree already registered: $WORKTREE_SLUG (port $existing_port)" >&2
  fi
  exit 3
fi

if [ -e "$target" ]; then
  echo "Worktree path already exists but is not registered: $target" >&2
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
  exit 4
}

repo="$PROJECT_REPO"
if [ "$PROJECT_REPO_KIND" = "bare" ]; then
  git -C "$repo" fetch --all --prune >/dev/null 2>&1 || true
else
  git -C "$repo" fetch --all --prune >/dev/null 2>&1 || true
fi

# git prints "HEAD is now at ..." on stdout; keep stdout pure for --json.
if git -C "$repo" show-ref --verify --quiet "refs/heads/$branch"; then
  git -C "$repo" worktree add "$target" "$branch" 1>&2
else
  git -C "$repo" worktree add -b "$branch" "$target" "$base_ref" 1>&2
fi

DB_PROVISIONED=false
if postgres_running; then
  if "$SCRIPT_DIR/create-project-db.sh" "$WORKTREE_DB" "$WORKTREE_DB_USER" "$WORKTREE_DB_PASSWORD" >/dev/null; then
    DB_PROVISIONED=true
  else
    echo "Warning: database provisioning failed for $WORKTREE_DB" >&2
  fi
else
  echo "Postgres is not running; database not provisioned." >&2
  echo "Run: devhub up && devhub db create $WORKTREE_DB" >&2
fi

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

if [ "$JSON_OUT" -eq 1 ]; then
  print_worktree_json "created" "$WORKTREE_PORT" "$DB_PROVISIONED"
  exit 0
fi

provisioned_label="no"
[ "$DB_PROVISIONED" = true ] && provisioned_label="yes"

cat <<EOF

Worktree ready
Project: $PROJECT_NAME
Branch:  $branch
Slug:    $WORKTREE_SLUG
Path:    $target
URL:     http://localhost:$WORKTREE_PORT
DB:      $WORKTREE_DB (provisioned: $provisioned_label)

Next:
  devhub runtime $PROJECT_NAME
EOF
