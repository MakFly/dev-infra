#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVHUB_DIR="${DEVHUB_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
# shellcheck disable=SC2034  # consumed by render_template via __DEVHUB_NETWORK__
NETWORK_NAME="${DEVHUB_NETWORK:-dev-shared-net}"

# shellcheck source=project-common.sh
source "$SCRIPT_DIR/project-common.sh"

usage() {
  cat <<'EOF'
Usage:
  devhub project init <name> --stack <stack> [options]
  devhub project list
  devhub project show <name>

Stacks:
  symfony, laravel, nextjs, tanstack-start, hono, fastapi-ddd

Options:
  --root <path>          Project runtime root (default: ./<name> from current directory)
  --repo <path|url>      Existing Git repo path or remote URL
  --base <ref>           Default base ref for new worktrees (default: main)
  --port-start <port>    First worktree port (default: 8101)
  --port-end <port>      Last worktree port (default: 8199)
  --runtime-port <port>  Dashboard/runtime port (default: 8100)
  --dev-command <cmd>    Override stack dev command for bun/python runtimes
EOF
}

write_registry() {
  local file
  file="$(project_file "$PROJECT_NAME")"
  mkdir -p "$(dirname "$file")"
  {
    printf 'PROJECT_NAME=%s\n' "$(quote_value "$PROJECT_NAME")"
    printf 'PROJECT_STACK=%s\n' "$(quote_value "$PROJECT_STACK")"
    printf 'PROJECT_RUNTIME_KIND=%s\n' "$(quote_value "$PROJECT_RUNTIME_KIND")"
    printf 'PROJECT_ROOT=%s\n' "$(quote_value "$PROJECT_ROOT")"
    printf 'PROJECT_REPO=%s\n' "$(quote_value "$PROJECT_REPO")"
    printf 'PROJECT_REPO_KIND=%s\n' "$(quote_value "$PROJECT_REPO_KIND")"
    printf 'PROJECT_WORKTREES=%s\n' "$(quote_value "$PROJECT_WORKTREES")"
    printf 'PROJECT_BASE_REF=%s\n' "$(quote_value "$PROJECT_BASE_REF")"
    printf 'PROJECT_PORT_START=%s\n' "$(quote_value "$PROJECT_PORT_START")"
    printf 'PROJECT_PORT_END=%s\n' "$(quote_value "$PROJECT_PORT_END")"
    printf 'PROJECT_RUNTIME_PORT=%s\n' "$(quote_value "$PROJECT_RUNTIME_PORT")"
    printf 'PROJECT_CONTAINER=%s\n' "$(quote_value "$PROJECT_CONTAINER")"
    printf 'PROJECT_DEV_COMMAND=%s\n' "$(quote_value "$PROJECT_DEV_COMMAND")"
  } > "$file"
  echo "Project registry written: $file"
}

default_dev_command() {
  case "$1" in
    nextjs) echo 'bun install && bun run dev --hostname 0.0.0.0 --port "$DEVHUB_PORT"' ;;
    tanstack-start) echo 'bun install && bun run dev --host 0.0.0.0 --port "$DEVHUB_PORT"' ;;
    hono) echo 'bun install && bun run dev --host 0.0.0.0 --port "$DEVHUB_PORT"' ;;
    fastapi-ddd) echo 'if [ -f requirements.txt ]; then pip install -r requirements.txt; fi && python -m uvicorn app.main:app --host 0.0.0.0 --port "$DEVHUB_PORT" --reload' ;;
    *) echo '' ;;
  esac
}

prepare_repo() {
  mkdir -p "$PROJECT_ROOT" "$PROJECT_WORKTREES"
  PROJECT_CREATED_EMPTY_REPO="0"

  if [ -z "$PROJECT_REPO" ]; then
    PROJECT_REPO="$PROJECT_ROOT/repo.git"
    PROJECT_REPO_KIND="bare"
    if [ ! -d "$PROJECT_REPO" ]; then
      git init --bare --initial-branch=main "$PROJECT_REPO" >/dev/null
      PROJECT_CREATED_EMPTY_REPO="1"
      echo "Initialized bare repo: $PROJECT_REPO"
    fi
    return
  fi

  if [ -d "$PROJECT_REPO/.git" ] || [ -f "$PROJECT_REPO/.git" ]; then
    PROJECT_REPO="$(abs_path "$PROJECT_REPO")"
    PROJECT_REPO_KIND="path"
    return
  fi

  if [ -d "$PROJECT_REPO/objects" ] && [ -d "$PROJECT_REPO/refs" ]; then
    PROJECT_REPO="$(abs_path "$PROJECT_REPO")"
    PROJECT_REPO_KIND="bare"
    return
  fi

  local clone_target="$PROJECT_ROOT/repo.git"
  if [ ! -d "$clone_target" ]; then
    git clone --bare "$PROJECT_REPO" "$clone_target"
  fi
  PROJECT_REPO="$clone_target"
  PROJECT_REPO_KIND="bare"
}

render_runtime() {
  local template_dir="$DEVHUB_DIR/templates/$PROJECT_STACK"
  [ -d "$template_dir" ] || {
    echo "Missing template directory: $template_dir" >&2
    exit 1
  }

  local docker_dir="$DEVHUB_DIR/docker/$PROJECT_NAME"
  mkdir -p "$docker_dir" "$docker_dir/sites"
  : > "$docker_dir/worktrees.ports"

  local file
  while IFS= read -r file; do
    local rel="${file#$template_dir/}"
    case "$rel" in
      override.yml.tpl|worktree.env.tpl|worktree.env.local.tpl|site.caddy.tpl|scaffold/*) continue ;;
    esac
    local target="$docker_dir/${rel%.tpl}"
    render_template "$file" "$target"
    if [[ "$target" == *.sh ]]; then
      chmod +x "$target"
    fi
  done < <(find "$template_dir" -type f | sort)

  render_template "$template_dir/override.yml.tpl" "$DEVHUB_DIR/overrides/$PROJECT_NAME-app.override.yml"
}

scaffold_initial_worktree() {
  [ "${PROJECT_CREATED_EMPTY_REPO:-0}" = "1" ] || return 0

  local template_dir="$DEVHUB_DIR/templates/$PROJECT_STACK"
  local scaffold_dir="$template_dir/scaffold"
  [ -d "$scaffold_dir" ] || return 0

  local slug="main"
  local target="$PROJECT_WORKTREES/$slug"
  git -C "$PROJECT_REPO" worktree add -b main "$target" >/dev/null
  cp -a "$scaffold_dir/." "$target/"

  git -C "$target" add .
  git -C "$target" -c user.name=DevHub -c user.email=devhub@local commit -m "chore: scaffold $PROJECT_STACK app" >/dev/null

  WORKTREE_SLUG="$slug"
  WORKTREE_PORT="$PROJECT_PORT_START"
  WORKTREE_DB="$(underscore_slug "${PROJECT_NAME}_${WORKTREE_SLUG}")"
  # shellcheck disable=SC2034  # expanded by render_template
  WORKTREE_DB_USER="$WORKTREE_DB"
  # shellcheck disable=SC2034  # expanded by render_template
  WORKTREE_DB_PASSWORD="$WORKTREE_DB"
  # shellcheck disable=SC2034  # expanded by render_template
  WORKTREE_REDIS_PREFIX="$WORKTREE_DB"

  if [ -f "$template_dir/worktree.env.tpl" ]; then
    render_template "$template_dir/worktree.env.tpl" "$target/.env"
  elif [ -f "$template_dir/worktree.env.local.tpl" ]; then
    render_template "$template_dir/worktree.env.local.tpl" "$target/.env.local"
  fi
  if [ -f "$template_dir/site.caddy.tpl" ]; then
    render_template "$template_dir/site.caddy.tpl" "$DEVHUB_DIR/docker/$PROJECT_NAME/sites/$slug.caddy"
  fi

  printf '%s|%s|%s|%s\n' "$slug" "$WORKTREE_PORT" "main" "$target" >> "$DEVHUB_DIR/docker/$PROJECT_NAME/worktrees.ports"
  echo "Initial scaffold created: $target"
}

cmd_init() {
  PROJECT_NAME="${1:-}"
  [ -n "$PROJECT_NAME" ] || { usage; exit 1; }
  shift || true
  PROJECT_NAME="$(slugify "$PROJECT_NAME")"
  require_project_name "$PROJECT_NAME"

  PROJECT_STACK=""
  PROJECT_ROOT="$PWD/$PROJECT_NAME"
  PROJECT_REPO=""
  PROJECT_REPO_KIND=""
  PROJECT_BASE_REF="main"
  PROJECT_PORT_START="8101"
  PROJECT_PORT_END="8199"
  PROJECT_RUNTIME_PORT="8100"
  PROJECT_CONTAINER="$PROJECT_NAME-runtime"
  PROJECT_DEV_COMMAND=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --stack) PROJECT_STACK="${2:-}"; shift 2 ;;
      --root) PROJECT_ROOT="${2:-}"; shift 2 ;;
      --repo) PROJECT_REPO="${2:-}"; shift 2 ;;
      --base) PROJECT_BASE_REF="${2:-}"; shift 2 ;;
      --port-start) PROJECT_PORT_START="${2:-}"; shift 2 ;;
      --port-end) PROJECT_PORT_END="${2:-}"; shift 2 ;;
      --runtime-port) PROJECT_RUNTIME_PORT="${2:-}"; shift 2 ;;
      --dev-command) PROJECT_DEV_COMMAND="${2:-}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
  done

  [ -n "$PROJECT_STACK" ] || { echo "--stack is required" >&2; usage; exit 1; }
  PROJECT_STACK="$(slugify "$PROJECT_STACK")"
  PROJECT_RUNTIME_KIND="$(stack_runtime_kind "$PROJECT_STACK")"
  PROJECT_ROOT="$(abs_path "$PROJECT_ROOT")"
  PROJECT_WORKTREES="$PROJECT_ROOT/worktrees"
  if [ -z "$PROJECT_DEV_COMMAND" ]; then
    PROJECT_DEV_COMMAND="$(default_dev_command "$PROJECT_STACK")"
  fi

  prepare_repo
  write_registry
  render_runtime
  scaffold_initial_worktree

  cat <<EOF

Project ready: $PROJECT_NAME
Stack:         $PROJECT_STACK
Root:          $PROJECT_ROOT
Worktrees:     $PROJECT_WORKTREES
Runtime:       $DEVHUB_DIR/overrides/$PROJECT_NAME-app.override.yml

Next:
  devhub wt add $PROJECT_NAME <branch> [base-ref]
  devhub runtime $PROJECT_NAME
EOF
}

cmd_list() {
  local dir
  dir="$(project_registry_dir)"
  mkdir -p "$dir"
  local found=0
  for file in "$dir"/*.env; do
    [ -f "$file" ] || continue
    found=1
    # shellcheck source=/dev/null
    source "$file"
    printf '%-24s %-16s %s\n' "$PROJECT_NAME" "$PROJECT_STACK" "$PROJECT_ROOT"
  done
  [ "$found" -eq 1 ] || echo "No projects registered."
}

cmd_show() {
  local project="${1:-}"
  load_project "$project"
  cat "$(project_file "$project")"
}

case "${1:-}" in
  init) shift; cmd_init "$@" ;;
  list) cmd_list ;;
  show) shift; cmd_show "$@" ;;
  -h|--help|help|"") usage ;;
  *) echo "Unknown project command: $1" >&2; usage; exit 1 ;;
esac
