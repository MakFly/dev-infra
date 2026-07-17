#!/usr/bin/env bash
set -euo pipefail

# Host user for runtime containers: files written into mounted worktrees
# (node_modules, .venv, build output) must stay removable by the host user.
DEVHUB_UID="${DEVHUB_UID:-$(id -u)}"
DEVHUB_GID="${DEVHUB_GID:-$(id -g)}"

slugify() {
  local value="$1"
  printf '%s' "$value" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's#[^a-z0-9]+#-#g' \
    | sed -E 's#(^-|-$)##g'
}

underscore_slug() {
  slugify "$1" | tr '-' '_'
}

quote_value() {
  printf "%q" "$1"
}

abs_path() {
  local path="$1"
  if [ -d "$path" ]; then
    cd "$path" && pwd
    return
  fi

  local dir
  dir="$(dirname "$path")"
  local base
  base="$(basename "$path")"
  mkdir -p "$dir"
  dir="$(cd "$dir" && pwd)"
  printf '%s/%s\n' "$dir" "$base"
}

project_registry_dir() {
  printf '%s/data/projects\n' "$DEVHUB_DIR"
}

project_file() {
  local project="$1"
  printf '%s/%s.env\n' "$(project_registry_dir)" "$(slugify "$project")"
}

require_project_name() {
  local project="$1"
  if [ -z "$project" ]; then
    echo "Project name is required." >&2
    exit 1
  fi
  if [ "$project" != "$(slugify "$project")" ]; then
    echo "Invalid project name: $project (use lowercase letters, digits and dashes)" >&2
    exit 1
  fi
}

load_project() {
  local project="$1"
  require_project_name "$project"
  local file
  file="$(project_file "$project")"
  [ -f "$file" ] || {
    echo "Unknown project: $project" >&2
    echo "Run: devhub project init $project --stack <stack>" >&2
    exit 1
  }
  # shellcheck source=/dev/null
  source "$file"
}

render_template() {
  local source="$1"
  local target="$2"
  mkdir -p "$(dirname "$target")"

  local safe_project_dev_command="${PROJECT_DEV_COMMAND//&/\\&}"
  safe_project_dev_command="${safe_project_dev_command//\$/\$\$}"

  while IFS= read -r line || [ -n "$line" ]; do
    line="${line//__PROJECT_NAME__/${PROJECT_NAME}}"
    line="${line//__PROJECT_STACK__/${PROJECT_STACK}}"
    line="${line//__PROJECT_ROOT__/${PROJECT_ROOT}}"
    line="${line//__PROJECT_WORKTREES__/${PROJECT_WORKTREES}}"
    line="${line//__PROJECT_CONTAINER__/${PROJECT_CONTAINER}}"
    line="${line//__PROJECT_PORT_START__/${PROJECT_PORT_START}}"
    line="${line//__PROJECT_PORT_END__/${PROJECT_PORT_END}}"
    line="${line//__PROJECT_RUNTIME_PORT__/${PROJECT_RUNTIME_PORT}}"
    line="${line//__PROJECT_DEV_COMMAND__/${safe_project_dev_command}}"
    line="${line//__PROJECT_APPS__/${PROJECT_APPS:-}}"
    line="${line//__PROJECT_PORTS_YAML__/${PROJECT_PORTS_YAML:-}}"
    line="${line//__DEVHUB_NETWORK__/${NETWORK_NAME}}"
    line="${line//__DEVHUB_UID__/${DEVHUB_UID}}"
    line="${line//__DEVHUB_GID__/${DEVHUB_GID}}"
    line="${line//__WORKTREE_SLUG__/${WORKTREE_SLUG:-}}"
    line="${line//__WORKTREE_PORT__/${WORKTREE_PORT:-}}"
    line="${line//__WORKTREE_DB__/${WORKTREE_DB:-}}"
    line="${line//__WORKTREE_DB_USER__/${WORKTREE_DB_USER:-}}"
    line="${line//__WORKTREE_DB_PASSWORD__/${WORKTREE_DB_PASSWORD:-}}"
    line="${line//__WORKTREE_REDIS_PREFIX__/${WORKTREE_REDIS_PREFIX:-}}"
    printf '%s\n' "$line"
  done < "$source" > "$target"
}

postgres_running() {
  command -v docker >/dev/null 2>&1 || return 1
  docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${POSTGRES_CONTAINER:-infra-postgres}$"
}

worktree_db_exists() {
  docker exec "${POSTGRES_CONTAINER:-infra-postgres}" psql -U "${POSTGRES_ADMIN_USER:-test}" -d postgres -tAc \
    "SELECT 1 FROM pg_database WHERE datname='${1}'" 2>/dev/null | grep -q 1
}

# Explicit compose port bindings for the runtime port plus every allocated
# worktree/app port. Publishing the whole project range would collide with
# unrelated host services inside it.
override_ports_yaml() {
  local ports_file="$1"
  local out="      - \"127.0.0.1:${PROJECT_RUNTIME_PORT}:${PROJECT_RUNTIME_PORT}\"" port
  if [ -f "$ports_file" ]; then
    while IFS= read -r port; do
      [ -n "$port" ] || continue
      out+=$'\n'"      - \"127.0.0.1:${port}:${port}\""
    done < <(awk -F'|' '
      $2 != "" { print $2 }
      $5 != "" { n = split($5, a, ","); for (i = 1; i <= n; i++) { split(a[i], kv, "="); print kv[2] } }
    ' "$ports_file" | sort -un)
  fi
  printf '%s' "$out"
}

# "apps/pwa/**,apps/web/**" -> ["apps/pwa/**","apps/web/**"] (empty -> [])
# read -ra splits on IFS without pathname expansion, so glob values like
# "apps/api/**" stay literal instead of matching files in the cwd.
csv_json_array() {
  local spec="$1" out="" item
  local -a items
  IFS=',' read -ra items <<< "$spec"
  for item in "${items[@]}"; do
    [ -n "$item" ] || continue
    [ -n "$out" ] && out+=","
    out+="$(json_str "$item")"
  done
  printf '[%s]' "$out"
}

# "web=8101,api=8102" -> {"web":8101,"api":8102}
apps_ports_json() {
  local spec="$1" out="" pair
  [ -n "$spec" ] || { printf '{}'; return 0; }
  local IFS=','
  for pair in $spec; do
    [ -n "$pair" ] || continue
    [ -n "$out" ] && out+=","
    out+="$(json_str "${pair%%=*}"):${pair#*=}"
  done
  printf '{%s}' "$out"
}

json_str() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '"%s"' "$s"
}

stack_runtime_kind() {
  case "$1" in
    symfony|laravel) echo "php" ;;
    nextjs|tanstack-start|hono) echo "bun" ;;
    fastapi-ddd) echo "python" ;;
    multi) echo "multi" ;;
    *)
      echo "Unknown stack: $1" >&2
      echo "Supported stacks: symfony, laravel, nextjs, tanstack-start, hono, fastapi-ddd" >&2
      exit 1
      ;;
  esac
}
