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
  devhub project adopt <path> [options]
  devhub project list
  devhub project show <name>

Stacks:
  symfony, laravel, nextjs, tanstack-start, hono, fastapi-ddd

Init options:
  --root <path>          Project runtime root (default: ./<name> from current directory)
  --repo <path|url>      Existing Git repo path or remote URL
  --base <ref>           Default base ref for new worktrees (default: main)
  --port-start <port>    First worktree port (default: 8101)
  --port-end <port>      Last worktree port (default: 8199)
  --runtime-port <port>  Dashboard/runtime port (default: 8100)
  --dev-command <cmd>    Override stack dev command for bun/python runtimes

Adopt options (one-shot migration of an existing Git checkout):
  --name <name>          Project name (default: source folder name)
  --stack <stack>        Stack (default: auto-detected from the source)
  --root <path>          Hub root (default: <path>-hub next to the source)
  --base <ref>           Base branch (default: source's current branch)
  --dev-command <cmd>    Override stack dev command
  --port-start/--port-end/--runtime-port  Same as init
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
    printf 'PROJECT_APPS=%s\n' "$(quote_value "$PROJECT_APPS")"
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

detect_stack_in_dir() {
  local dir="$1"
  if [ -f "$dir/composer.json" ]; then
    if grep -q '"laravel/framework"' "$dir/composer.json"; then echo laravel; return 0; fi
    if [ -f "$dir/symfony.lock" ] || grep -q '"symfony/framework-bundle"' "$dir/composer.json"; then echo symfony; return 0; fi
  fi
  if [ -f "$dir/package.json" ]; then
    if grep -q '"next"' "$dir/package.json"; then echo nextjs; return 0; fi
    if grep -Eq '"@tanstack/(react-)?start"' "$dir/package.json"; then echo tanstack-start; return 0; fi
    if grep -q '"hono"' "$dir/package.json"; then echo hono; return 0; fi
  fi
  if grep -qs 'fastapi' "$dir/pyproject.toml" "$dir"/requirements*.txt 2>/dev/null; then
    echo fastapi-ddd
    return 0
  fi
  return 0
}

# Append vars from $1 that are missing in $2 (never prints values).
merge_env_file() {
  local src="$1" target="$2"
  [ -f "$src" ] || return 0
  if [ ! -f "$target" ]; then
    mkdir -p "$(dirname "$target")"
    cp "$src" "$target"
    echo "Copied env file: $src -> $target"
    return 0
  fi
  local line key added=0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|\#*) continue ;; esac
    key="${line%%=*}"
    if ! grep -q "^${key}=" "$target"; then
      printf '%s\n' "$line" >> "$target"
      added=$((added + 1))
    fi
  done < "$src"
  [ "$added" -gt 0 ] && echo "Merged $added var(s) from $src into $target"
  return 0
}

cmd_adopt() {
  local source="${1:-}"
  [ -n "$source" ] || { usage; exit 1; }
  shift || true

  local adopt_name="" adopt_stack="" adopt_root="" adopt_base="" adopt_dev_command=""
  local adopt_port_start="" adopt_port_end="" adopt_runtime_port=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --name) adopt_name="${2:-}"; shift 2 ;;
      --stack) adopt_stack="${2:-}"; shift 2 ;;
      --root) adopt_root="${2:-}"; shift 2 ;;
      --base) adopt_base="${2:-}"; shift 2 ;;
      --dev-command) adopt_dev_command="${2:-}"; shift 2 ;;
      --port-start) adopt_port_start="${2:-}"; shift 2 ;;
      --port-end) adopt_port_end="${2:-}"; shift 2 ;;
      --runtime-port) adopt_runtime_port="${2:-}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
  done

  [ -d "$source" ] || { echo "Source path not found: $source" >&2; exit 1; }
  source="$(abs_path "$source")"
  if [ ! -d "$source/.git" ] && [ ! -f "$source/.git" ]; then
    echo "Not a Git checkout: $source" >&2
    exit 1
  fi

  adopt_name="${adopt_name:-$(basename "$source")}"
  adopt_name="$(slugify "$adopt_name")"
  require_project_name "$adopt_name"
  if [ -f "$(project_file "$adopt_name")" ]; then
    echo "Project already registered: $adopt_name (see: devhub project show $adopt_name)" >&2
    exit 1
  fi

  adopt_root="${adopt_root:-${source}-hub}"
  adopt_root="$(abs_path "$adopt_root")"
  if [ "$adopt_root" = "$source" ]; then
    echo "Hub root must not be the source checkout itself: $adopt_root" >&2
    exit 1
  fi

  if [ -z "$adopt_base" ]; then
    adopt_base="$(git -C "$source" symbolic-ref --short HEAD 2>/dev/null || echo main)"
  fi

  # Detect stack and app directory (root or one workspace level: apps/*, packages/*).
  local candidates=() dir rel stack
  for dir in "$source" "$source"/apps/*/ "$source"/packages/*/; do
    [ -d "$dir" ] || continue
    dir="${dir%/}"
    rel="${dir#"$source"}"
    rel="${rel#/}"
    [ -n "$rel" ] || rel="."
    stack="$(detect_stack_in_dir "$dir")"
    [ -n "$stack" ] && candidates+=("$rel|$stack")
  done

  local app_dir="." apps_spec=""
  if [ -n "$adopt_stack" ]; then
    adopt_stack="$(slugify "$adopt_stack")"
    local matches=()
    local entry
    for entry in "${candidates[@]:-}"; do
      [ -n "$entry" ] || continue
      [ "${entry#*|}" = "$adopt_stack" ] && matches+=("$entry")
    done
    if [ "${#matches[@]}" -eq 1 ]; then
      app_dir="${matches[0]%%|*}"
    elif [ "${#matches[@]}" -gt 1 ] && [ -z "$adopt_dev_command" ]; then
      echo "Several apps match stack $adopt_stack: ${matches[*]%%|*}" >&2
      echo "Pass an explicit --dev-command." >&2
      exit 1
    fi
  else
    if [ "${#candidates[@]}" -eq 0 ]; then
      echo "Could not detect the stack of $source" >&2
      echo "Pass --stack <symfony|laravel|nextjs|tanstack-start|hono|fastapi-ddd>." >&2
      exit 1
    fi
    if [ "${#candidates[@]}" -eq 1 ]; then
      app_dir="${candidates[0]%%|*}"
      adopt_stack="${candidates[0]#*|}"
    else
      # Multi-app monorepo: every app runs in one polyglot runtime (bun+python),
      # one port per app per worktree. PHP stacks need their own image: bail out.
      local entry stack
      for entry in "${candidates[@]}"; do
        stack="${entry#*|}"
        case "$stack" in
          symfony|laravel)
            echo "Multi-app adoption supports bun/python stacks only ($stack found in ${entry%%|*})." >&2
            echo "Pick a single app with --stack $stack." >&2
            exit 1
            ;;
        esac
      done
      # Primary app = the web-facing one (first front stack, else first found).
      local primary=""
      for entry in "${candidates[@]}"; do
        case "${entry#*|}" in nextjs|tanstack-start) primary="$entry"; break ;; esac
      done
      [ -n "$primary" ] || primary="${candidates[0]}"
      local ordered=("$primary") name
      for entry in "${candidates[@]}"; do
        [ "$entry" = "$primary" ] || ordered+=("$entry")
      done
      for entry in "${ordered[@]}"; do
        name="$(slugify "$(basename "${entry%%|*}")")"
        while [[ ",$apps_spec," == *",$name="* ]]; do name="${name}2"; done
        apps_spec="${apps_spec:+$apps_spec,}$name=${entry%%|*}=${entry#*|}"
      done
      adopt_stack="multi"
      app_dir="${primary%%|*}"
      echo "Multi-app project detected: $apps_spec"
    fi
  fi

  # Wrap the default dev command when the app lives in a workspace subdirectory.
  if [ -z "$adopt_dev_command" ] && [ "$app_dir" != "." ]; then
    local base_cmd
    base_cmd="$(default_dev_command "$adopt_stack")"
    [ -n "$base_cmd" ] && adopt_dev_command="cd $app_dir && $base_cmd"
  fi

  # Bare clone = single source of truth; keeps all local branches.
  local bare="$adopt_root/repo.git"
  mkdir -p "$adopt_root"
  if [ ! -d "$bare" ]; then
    git clone --bare "$source" "$bare"
  fi
  local origin_url
  origin_url="$(git -C "$source" remote get-url origin 2>/dev/null || true)"
  if [ -n "$origin_url" ]; then
    git -C "$bare" remote set-url origin "$origin_url"
  fi
  git -C "$bare" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
  git -C "$bare" fetch --prune origin >/dev/null 2>&1 || true

  local init_args=("$adopt_name" --stack "$adopt_stack" --root "$adopt_root" --repo "$bare" --base "$adopt_base")
  [ -n "$apps_spec" ] && init_args+=(--apps "$apps_spec")
  [ -n "$adopt_dev_command" ] && init_args+=(--dev-command "$adopt_dev_command")
  [ -n "$adopt_port_start" ] && init_args+=(--port-start "$adopt_port_start")
  [ -n "$adopt_port_end" ] && init_args+=(--port-end "$adopt_port_end")
  [ -n "$adopt_runtime_port" ] && init_args+=(--runtime-port "$adopt_runtime_port")
  cmd_init "${init_args[@]}"

  "$SCRIPT_DIR/wt-add.sh" "$adopt_name" "$adopt_base"

  # Bring untracked env files over, keeping DevHub-rendered values first.
  local wt
  wt="$PROJECT_WORKTREES/$(slugify "$adopt_base")"
  local env_name
  for env_name in .env .env.local; do
    merge_env_file "$source/$env_name" "$wt/$env_name"
  done
  if [ -n "$apps_spec" ]; then
    # Multi-app: wt-add rendered each app's env in place; bring the source
    # env of every app over (API keys etc.), rendered values keep priority.
    local pairs=() pair dir
    IFS=',' read -ra pairs <<< "$apps_spec"
    for pair in "${pairs[@]}"; do
      dir="${pair#*=}"
      dir="${dir%%=*}"
      for env_name in .env .env.local; do
        merge_env_file "$source/$dir/$env_name" "$wt/$dir/$env_name"
      done
    done
  elif [ "$app_dir" != "." ]; then
    for env_name in .env .env.local; do
      merge_env_file "$source/$app_dir/$env_name" "$wt/$app_dir/$env_name"
    done
    # The stack template renders its env at the worktree root; the app reads
    # it from its own directory in a workspace layout.
    for env_name in .env .env.local; do
      [ -f "$wt/$env_name" ] && merge_env_file "$wt/$env_name" "$wt/$app_dir/$env_name"
    done
  fi

  local dirty
  dirty="$(git -C "$source" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"

  cat <<EOF

Adopted: $adopt_name
Source:  $source (left untouched)
Hub:     $adopt_root
Apps:    ${apps_spec:-$app_dir ($adopt_stack)}
Agents:  $adopt_root/CLAUDE.md (worktree rules for AI/terminals)

Next:
  cd $wt
  devhub runtime $adopt_name
EOF

  if [ "$dirty" -gt 0 ]; then
    echo ""
    echo "Warning: $dirty uncommitted change(s) remain in $source."
    echo "Commit them there and 'git -C $bare fetch', or copy them manually into $wt."
  fi
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

  # shellcheck disable=SC2034  # consumed by render_template via __PROJECT_PORTS_YAML__
  PROJECT_PORTS_YAML="$(override_ports_yaml "$docker_dir/worktrees.ports")"
  render_template "$template_dir/override.yml.tpl" "$DEVHUB_DIR/overrides/$PROJECT_NAME-app.override.yml"
}

# Render the Claude/agents workspace (CLAUDE.md, .claude/ agents, skills,
# permissions) at the hub root so AI sessions opened there orchestrate work
# through worktrees (/orchestrate, /orchestrate-fast).
render_claude_workspace() {
  local root="$1"
  local template_dir="$DEVHUB_DIR/templates/claude"
  [ -d "$template_dir" ] || return 0
  local file rel target
  while IFS= read -r file; do
    rel="${file#"$template_dir"/}"
    target="$root/${rel%.tpl}"
    render_template "$file" "$target"
  done < <(find "$template_dir" -type f -name '*.tpl' | sort)
  if [ -f "$root/CLAUDE.md" ]; then
    cp "$root/CLAUDE.md" "$root/AGENTS.md"
  fi
  echo "Agent workspace written: $root/CLAUDE.md + .claude/"
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
  PROJECT_APPS=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --stack) PROJECT_STACK="${2:-}"; shift 2 ;;
      --apps) PROJECT_APPS="${2:-}"; shift 2 ;;
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
  render_claude_workspace "$PROJECT_ROOT"

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
  local json_out=0
  [ "${1:-}" = "--json" ] && json_out=1
  local dir
  dir="$(project_registry_dir)"
  mkdir -p "$dir"

  if [ "$json_out" -eq 1 ]; then
    printf '{"v":1,"projects":['
    local first=1
    for file in "$dir"/*.env; do
      [ -f "$file" ] || continue
      [ "$first" -eq 1 ] || printf ','
      first=0
      (
        # shellcheck source=/dev/null
        source "$file"
        printf '{"name":%s,"stack":%s,"root":%s,"container":%s,"base_ref":%s,"port_start":%s,"port_end":%s}' \
          "$(json_str "$PROJECT_NAME")" \
          "$(json_str "$PROJECT_STACK")" \
          "$(json_str "$PROJECT_ROOT")" \
          "$(json_str "$PROJECT_CONTAINER")" \
          "$(json_str "$PROJECT_BASE_REF")" \
          "$PROJECT_PORT_START" \
          "$PROJECT_PORT_END"
      )
    done
    printf ']}\n'
    return 0
  fi

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
  adopt) shift; cmd_adopt "$@" ;;
  list) shift; cmd_list "$@" ;;
  show) shift; cmd_show "$@" ;;
  -h|--help|help|"") usage ;;
  *) echo "Unknown project command: $1" >&2; usage; exit 1 ;;
esac
