#!/usr/bin/env bash
set -euo pipefail

REPO_SLUG="MakFly/dev-infra"
REPO_URL="https://github.com/${REPO_SLUG}.git"
# Which version to install: "latest" (newest release, default), "vX.Y.Z", or "main".
DEVHUB_VERSION="${DEVHUB_VERSION:-latest}"
DEVHUB_DIR="${DEVHUB_DIR:-$HOME/.local/share/devhub}"
BIN_DIR="$HOME/.local/bin"
ZSH_SNIPPET_DIR="$HOME/.config/devhub"
ZSH_SNIPPET_FILE="$ZSH_SNIPPET_DIR/devhub.zsh"

RED='\033[0;31m'
GREEN='\033[0;32m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

info()  { printf "${GREEN}[devhub]${RESET} %s\n" "$*"; }
warn()  { printf "${RED}[devhub]${RESET} %s\n" "$*" >&2; }
dim()   { printf "${DIM}%s${RESET}\n" "$*"; }

check_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    warn "Missing required command: $1"
    return 1
  fi
}

preflight() {
  local missing=0

  check_cmd docker || missing=1
  if ! docker compose version >/dev/null 2>&1; then
    warn "Docker Compose v2 not found (docker compose version failed)"
    missing=1
  fi
  check_cmd jq || missing=1
  check_cmd curl || missing=1

  if [ "$missing" -eq 1 ]; then
    echo ""
    warn "Install the missing dependencies above and re-run this script."
    exit 1
  fi

  info "Prerequisites OK: docker, docker compose, jq, curl"
}

# Resolve DEVHUB_VERSION into REF (git ref) + REF_KIND (tag|branch).
resolve_ref() {
  case "$DEVHUB_VERSION" in
    main)
      REF="main"; REF_KIND="branch"
      ;;
    latest)
      info "Resolving latest release..."
      local tag
      tag="$(curl -fsSL "https://api.github.com/repos/${REPO_SLUG}/releases/latest" \
        | jq -r '.tag_name // empty')"
      if [ -z "$tag" ]; then
        warn "No published release found — falling back to 'main'."
        REF="main"; REF_KIND="branch"
      else
        REF="$tag"; REF_KIND="tag"
      fi
      ;;
    v*)
      REF="$DEVHUB_VERSION"; REF_KIND="tag"
      ;;
    *)
      REF="v$DEVHUB_VERSION"; REF_KIND="tag"
      ;;
  esac
  info "Target version: $REF"
}

download() {
  if [ -d "$DEVHUB_DIR/.git" ]; then
    info "Updating existing installation to $REF..."
    if [ "$REF_KIND" = "branch" ]; then
      git -C "$DEVHUB_DIR" fetch origin "$REF"
      git -C "$DEVHUB_DIR" checkout -q "$REF"
      git -C "$DEVHUB_DIR" pull --ff-only origin "$REF"
    else
      git -C "$DEVHUB_DIR" fetch --tags origin
      git -C "$DEVHUB_DIR" checkout -q "tags/$REF"
    fi
    return
  fi

  if [ -d "$DEVHUB_DIR" ] && [ "$(ls -A "$DEVHUB_DIR" 2>/dev/null)" ]; then
    warn "$DEVHUB_DIR exists and is not empty."
    warn "Remove it first or set DEVHUB_DIR to another path."
    exit 1
  fi

  if command -v git >/dev/null 2>&1; then
    info "Cloning $REF via git..."
    git clone --depth 1 --branch "$REF" "$REPO_URL" "$DEVHUB_DIR"
  else
    info "git not found — downloading tarball..."
    mkdir -p "$DEVHUB_DIR"
    local tarball_url
    if [ "$REF_KIND" = "branch" ]; then
      tarball_url="https://github.com/${REPO_SLUG}/archive/refs/heads/${REF}.tar.gz"
    else
      tarball_url="https://github.com/${REPO_SLUG}/archive/refs/tags/${REF}.tar.gz"
    fi
    curl -fsSL "$tarball_url" | tar xz --strip-components=1 -C "$DEVHUB_DIR"
  fi
}

install_cli() {
  mkdir -p "$BIN_DIR" "$ZSH_SNIPPET_DIR"

  if [ ! -f "$DEVHUB_DIR/.env" ] && [ -f "$DEVHUB_DIR/.env.example" ]; then
    cp "$DEVHUB_DIR/.env.example" "$DEVHUB_DIR/.env"
    dim "Created $DEVHUB_DIR/.env from .env.example"
  fi

  chmod +x "$DEVHUB_DIR/bin/devhub"
  ln -sfn "$DEVHUB_DIR/bin/devhub" "$BIN_DIR/devhub"

  cat > "$ZSH_SNIPPET_FILE" <<'ZSH'
# Shared Docker Dev Hub shortcuts
function devhub() { "$HOME/.local/bin/devhub" "$@"; }
alias dh='devhub'
alias dhup='devhub up'
alias dhps='devhub ps'
alias dhdown='devhub down'
ZSH

  SOURCE_LINE='[ -f "$HOME/.config/devhub/devhub.zsh" ] && source "$HOME/.config/devhub/devhub.zsh"'
  if [ -f "$HOME/.zshrc" ] && ! grep -Fq "$SOURCE_LINE" "$HOME/.zshrc"; then
    printf "\n# DevHub CLI\n%s\n" "$SOURCE_LINE" >> "$HOME/.zshrc"
    dim "Added source line to ~/.zshrc"
  fi
}

summary() {
  echo ""
  printf "${BOLD}DevHub installed${RESET}\n"
  echo ""
  dim "  Version    ${REF:-$DEVHUB_VERSION}"
  dim "  Directory  $DEVHUB_DIR"
  dim "  CLI        $BIN_DIR/devhub"
  dim "  Aliases    $ZSH_SNIPPET_FILE"
  echo ""

  if echo "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
    info "Run: source ~/.zshrc && devhub up"
  else
    warn "$BIN_DIR is not in your PATH."
    info "Add it:  export PATH=\"\$HOME/.local/bin:\$PATH\""
    info "Then:    source ~/.zshrc && devhub up"
  fi
}

main() {
  echo ""
  printf "${BOLD}DevHub — Local Docker Development Infrastructure${RESET}\n"
  echo ""

  preflight
  resolve_ref
  download
  install_cli
  summary
}

main
