#!/usr/bin/env bash
set -euo pipefail

TARGET_BIN="$HOME/.local/bin/devhub"
ZSH_SNIPPET_FILE="$HOME/.config/devhub/devhub.zsh"

rm -f "$TARGET_BIN"
rm -f "$ZSH_SNIPPET_FILE"

echo "Removed $TARGET_BIN and $ZSH_SNIPPET_FILE"
echo "If needed, remove the source line from ~/.zshrc manually."
