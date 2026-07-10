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
PROJECT_APPS="${PROJECT_APPS:-}"
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
  local root="$1" sub
  if [ -n "$PROJECT_APPS" ]; then
    # Multi-app: report the primary app's env file.
    sub="${PROJECT_APPS%%,*}"
    sub="${sub#*=}"
    root="$1/${sub%%=*}"
  fi
  if [ -f "$root/.env" ]; then
    printf '%s' "$root/.env"
  elif [ -f "$root/.env.local" ]; then
    printf '%s' "$root/.env.local"
  fi
}

print_worktree_json() {
  local state="$1" port="$2" provisioned="$3"
  local apps_json=""
  [ -n "$APP_PORTS" ] && apps_json=",\"apps\":$(apps_ports_json "$APP_PORTS")"
  printf '{"v":1,"status":%s,"project":%s,"slug":%s,"branch":%s,"path":%s,"port":%s,"url":%s,"db":%s,"db_user":%s,"redis_prefix":%s,"env_path":%s,"container":%s,"db_provisioned":%s%s}\n' \
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
    "$provisioned" \
    "$apps_json"
}

APP_PORTS=""

existing_line="$(awk -F'|' -v slug="$WORKTREE_SLUG" '$1 == slug { print; exit }' "$ports_file")"
if [ -n "$existing_line" ]; then
  existing_port="$(printf '%s' "$existing_line" | awk -F'|' '{ print $2 }')"
  APP_PORTS="$(printf '%s' "$existing_line" | awk -F'|' '{ print $5 }')"
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
  local reserved=" $* " port
  for port in $(seq "$PROJECT_PORT_START" "$PROJECT_PORT_END"); do
    if [[ "$reserved" == *" $port "* ]]; then
      continue
    fi
    # Registered ports live in field 2 (primary) and field 5 (per-app map).
    if awk -F'|' -v port="$port" '$2 == port { found=1 } $5 ~ ("=" port "(,|$)") { found=1 } END { exit found ? 0 : 1 }' "$ports_file"; then
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

no_free_port() {
  echo "No free port in $PROJECT_PORT_START-$PROJECT_PORT_END" >&2
  exit 4
}

if [ -n "$PROJECT_APPS" ]; then
  IFS=',' read -ra APP_DEFS <<< "$PROJECT_APPS"
  picked=()
  for app_def in "${APP_DEFS[@]}"; do
    [ -n "$app_def" ] || continue
    app_port="$(pick_port "${picked[@]:-}")" || no_free_port
    picked+=("$app_port")
    APP_PORTS="${APP_PORTS:+$APP_PORTS,}${app_def%%=*}=$app_port"
  done
  WORKTREE_PORT="${picked[0]}"
else
  WORKTREE_PORT="$(pick_port)" || no_free_port
fi

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

render_stack_env() {
  local stack="$1" dir="$2"
  local template_dir="$DEVHUB_DIR/templates/$stack"
  if [ -f "$template_dir/worktree.env.tpl" ] && [ ! -f "$dir/.env" ]; then
    render_template "$template_dir/worktree.env.tpl" "$dir/.env"
  elif [ -f "$template_dir/worktree.env.local.tpl" ] && [ ! -f "$dir/.env.local" ]; then
    render_template "$template_dir/worktree.env.local.tpl" "$dir/.env.local"
  fi
}

app_env_file() {
  local dir="$1"
  if [ -f "$dir/.env" ]; then
    printf '%s' "$dir/.env"
  elif [ -f "$dir/.env.local" ]; then
    printf '%s' "$dir/.env.local"
  else
    printf '%s' "$dir/.env"
  fi
}

append_env_kv() {
  local file="$1" key="$2" value="$3"
  mkdir -p "$(dirname "$file")"
  grep -qs "^${key}=" "$file" || printf '%s=%s\n' "$key" "$value" >> "$file"
}

app_port_for() {
  awk -v RS=',' -F'=' -v n="$1" '$1 == n { gsub(/[^0-9]/, "", $2); print $2 }' <<< "$APP_PORTS"
}

if [ -n "$PROJECT_APPS" ]; then
  # One env per app, rendered with that app's port; then wire apps together
  # (DEVHUB_<APP>_URL for every peer, API_URL conventions for an `api` app).
  primary_port="$WORKTREE_PORT"
  for app_def in "${APP_DEFS[@]}"; do
    [ -n "$app_def" ] || continue
    app_name="${app_def%%=*}"
    app_rest="${app_def#*=}"
    app_dir="${app_rest%%=*}"
    app_stack="${app_rest#*=}"
    WORKTREE_PORT="$(app_port_for "$app_name")"
    render_stack_env "$app_stack" "$target/$app_dir"
  done
  WORKTREE_PORT="$primary_port"
  for app_def in "${APP_DEFS[@]}"; do
    [ -n "$app_def" ] || continue
    app_name="${app_def%%=*}"
    app_rest="${app_def#*=}"
    app_dir="${app_rest%%=*}"
    env_file="$(app_env_file "$target/$app_dir")"
    for peer_def in "${APP_DEFS[@]}"; do
      peer_name="${peer_def%%=*}"
      [ "$peer_name" != "$app_name" ] || continue
      peer_port="$(app_port_for "$peer_name")"
      [ -n "$peer_port" ] || continue
      peer_var="DEVHUB_$(printf '%s' "$peer_name" | tr '[:lower:]-' '[:upper:]_')_URL"
      append_env_kv "$env_file" "$peer_var" "http://localhost:$peer_port"
      if [ "$peer_name" = "api" ]; then
        append_env_kv "$env_file" "API_URL" "http://localhost:$peer_port"
        append_env_kv "$env_file" "NEXT_PUBLIC_API_URL" "http://localhost:$peer_port"
      fi
    done
  done
else
  render_stack_env "$PROJECT_STACK" "$target"
fi

template_dir="$DEVHUB_DIR/templates/$PROJECT_STACK"

if [ -f "$template_dir/site.caddy.tpl" ]; then
  render_template "$template_dir/site.caddy.tpl" "$DEVHUB_DIR/docker/$PROJECT_NAME/sites/$WORKTREE_SLUG.caddy"
fi

if [ -n "$APP_PORTS" ]; then
  printf '%s|%s|%s|%s|%s\n' "$WORKTREE_SLUG" "$WORKTREE_PORT" "$branch" "$target" "$APP_PORTS" >> "$ports_file"
else
  printf '%s|%s|%s|%s\n' "$WORKTREE_SLUG" "$WORKTREE_PORT" "$branch" "$target" >> "$ports_file"
fi

if [ -n "$PROJECT_APPS" ]; then
  # Multi runtimes publish only allocated ports: re-render the override so the
  # new worktree's ports are bound.
  # shellcheck disable=SC2034  # consumed by render_template via __PROJECT_PORTS_YAML__
  PROJECT_PORTS_YAML="$(override_ports_yaml "$ports_file")"
  render_template "$DEVHUB_DIR/templates/$PROJECT_STACK/override.yml.tpl" "$DEVHUB_DIR/overrides/$PROJECT_NAME-app.override.yml"
fi

if command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' | grep -q "^${PROJECT_CONTAINER}$"; then
  if [ -n "$PROJECT_APPS" ]; then
    # Port bindings changed: the container must be recreated, not restarted.
    "$DEVHUB_DIR/bin/devhub" runtime "$PROJECT_NAME" >/dev/null 2>&1 || docker restart "$PROJECT_CONTAINER" >/dev/null
  else
    docker restart "$PROJECT_CONTAINER" >/dev/null
  fi
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
URL:     http://localhost:$WORKTREE_PORT${APP_PORTS:+
Apps:    $APP_PORTS}
DB:      $WORKTREE_DB (provisioned: $provisioned_label)

Next:
  devhub runtime $PROJECT_NAME
EOF
