#!/usr/bin/env bash
set -euo pipefail

# DevHub release helper.
# Bumps VERSION, commits "chore(release): vX.Y.Z", creates an annotated tag,
# and (after confirmation) pushes so the Release workflow publishes the
# GitHub Release. VERSION is the single source of truth for the version.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERSION_FILE="$REPO_DIR/VERSION"
RELEASE_BRANCH="main"

RED='\033[0;31m'
GREEN='\033[0;32m'
DIM='\033[2m'
RESET='\033[0m'

info() { printf "${GREEN}[release]${RESET} %s\n" "$*"; }
warn() { printf "${RED}[release]${RESET} %s\n" "$*" >&2; }
dim()  { printf "${DIM}%s${RESET}\n" "$*"; }

usage() {
  cat <<EOF
Usage: release.sh <patch|minor|major|X.Y.Z> [--yes] [--dry-run] [--no-push]

Bumps VERSION, commits "chore(release): vX.Y.Z" and tags it, then pushes
${RELEASE_BRANCH} and the tag (the Release workflow publishes the GitHub Release).

Arguments:
  patch          x.y.Z + 1   (default)
  minor          x.Y.0 + 1
  major          X.0.0 + 1
  X.Y.Z          set an explicit version (e.g. 1.0.0)

Options:
  --yes          skip the confirmation prompt
  --dry-run      show the actions without changing anything
  --no-push      commit and tag locally, do not push
EOF
}

die() { warn "$*"; exit 1; }

bump="patch"
assume_yes=0
dry_run=0
do_push=1

while [ $# -gt 0 ]; do
  case "$1" in
    patch|minor|major) bump="$1" ;;
    [0-9]*.[0-9]*.[0-9]*) bump="$1" ;;
    --yes|-y) assume_yes=1 ;;
    --dry-run) dry_run=1 ;;
    --no-push) do_push=0 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; die "Unknown argument: $1" ;;
  esac
  shift
done

command -v git >/dev/null 2>&1 || die "git is required"
[ -f "$VERSION_FILE" ] || die "VERSION file not found: $VERSION_FILE"

cd "$REPO_DIR"

current="$(tr -d '[:space:]' < "$VERSION_FILE")"
[[ "$current" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "VERSION is not semver: '$current'"

IFS='.' read -r cur_major cur_minor cur_patch <<< "$current"

case "$bump" in
  patch) next="$cur_major.$cur_minor.$((cur_patch + 1))" ;;
  minor) next="$cur_major.$((cur_minor + 1)).0" ;;
  major) next="$((cur_major + 1)).0.0" ;;
  *)     next="$bump" ;;
esac

[[ "$next" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Invalid target version: '$next'"

tag="v$next"

# Pre-flight checks.
branch="$(git rev-parse --abbrev-ref HEAD)"
[ "$branch" = "$RELEASE_BRANCH" ] || die "Not on '$RELEASE_BRANCH' (current: '$branch')"

git diff --quiet && git diff --cached --quiet || die "Working tree not clean; commit or stash first"

if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  die "Tag already exists: $tag"
fi

if [ "$next" = "$current" ]; then
  die "Target version equals current version ($current)"
fi

info "Release $current -> $next  (tag $tag)"
[ "$dry_run" -eq 1 ] && dim "dry-run: no changes will be made"

if [ "$assume_yes" -eq 0 ] && [ "$dry_run" -eq 0 ]; then
  printf "Proceed? [y/N] "
  read -r answer
  case "$answer" in
    y|Y|yes) ;;
    *) die "Aborted." ;;
  esac
fi

run() {
  if [ "$dry_run" -eq 1 ]; then
    dim "+ $*"
  else
    "$@"
  fi
}

if [ "$dry_run" -eq 1 ]; then
  dim "+ echo $next > VERSION"
else
  echo "$next" > "$VERSION_FILE"
fi

run git add "$VERSION_FILE"
run git commit -m "chore(release): $tag"
run git tag -a "$tag" -m "$tag"

if [ "$do_push" -eq 1 ]; then
  run git push origin "$RELEASE_BRANCH"
  run git push origin "$tag"
  info "Pushed $RELEASE_BRANCH and $tag — the Release workflow will publish $tag."
else
  info "Committed and tagged locally. Push with:"
  dim "  git push origin $RELEASE_BRANCH && git push origin $tag"
fi
