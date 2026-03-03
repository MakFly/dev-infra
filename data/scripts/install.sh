#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVHUB_BIN="$REPO_DIR/bin/devhub"
TARGET_BIN="$HOME/.local/bin/devhub"
ZSH_SNIPPET_DIR="$HOME/.config/devhub"
ZSH_SNIPPET_FILE="$ZSH_SNIPPET_DIR/devhub.zsh"
ZSHRC_FILE="$HOME/.zshrc"

mkdir -p "$HOME/.local/bin" "$ZSH_SNIPPET_DIR"

if [ ! -f "$REPO_DIR/.env" ] && [ -f "$REPO_DIR/.env.example" ]; then
  cp "$REPO_DIR/.env.example" "$REPO_DIR/.env"
  echo "Created $REPO_DIR/.env from .env.example"
fi

ln -sfn "$DEVHUB_BIN" "$TARGET_BIN"
chmod +x "$DEVHUB_BIN"

cat > "$ZSH_SNIPPET_FILE" <<'ZSH'
# Shared Docker Dev Hub shortcuts

function devhub() {
  "$HOME/.local/bin/devhub" "$@"
}

alias dh='devhub'
alias dhup='devhub up'
alias dhps='devhub ps'
alias dhdown='devhub down'
ZSH

SOURCE_LINE='[ -f "$HOME/.config/devhub/devhub.zsh" ] && source "$HOME/.config/devhub/devhub.zsh"'
if [ -f "$ZSHRC_FILE" ] && ! grep -Fq "$SOURCE_LINE" "$ZSHRC_FILE"; then
  printf "\n# Shared Docker Dev Hub aliases/functions\n%s\n" "$SOURCE_LINE" >> "$ZSHRC_FILE"
fi

echo "Installed devhub -> $TARGET_BIN"
echo "Next: source ~/.zshrc && devhub up"
