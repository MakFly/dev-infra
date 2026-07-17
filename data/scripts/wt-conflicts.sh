#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVHUB_DIR="${DEVHUB_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
# shellcheck disable=SC2034  # shared header; render_template reads it in sibling scripts
NETWORK_NAME="${DEVHUB_NETWORK:-dev-shared-net}"

# shellcheck source=project-common.sh
source "$SCRIPT_DIR/project-common.sh"

# Conflict oracle: mechanical, read-only, stateless. For each registered
# worktree it lists the files changed against a base ref, then reports where
# lanes step on each other:
#   - overlap    : two lanes changed the same file (a merge conflict waiting)
#   - out-of-scope: a lane changed a file outside its declared --owns fence
#   - migrations : more than one lane added/changed a migration
# Everything is recomputed from git on every call, so it never goes stale.

usage() {
  echo "Usage: devhub wt conflicts <project> [--group <slug>] [--against <ref>] [--json]" >&2
  echo "Exit codes: 0 no conflicts, 6 conflicts detected" >&2
}

JSON_OUT=0
GROUP=""
AGAINST=""
positional=()
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON_OUT=1 ;;
    --group) GROUP="${2:-}"; shift ;;
    --group=*) GROUP="${1#*=}" ;;
    --against) AGAINST="${2:-}"; shift ;;
    --against=*) AGAINST="${1#*=}" ;;
    -h|--help) usage; exit 0 ;;
    *) positional+=("$1") ;;
  esac
  shift
done

project="${positional[0]:-}"
[ -n "$project" ] || { usage; exit 1; }
load_project "$project"
[ -z "$GROUP" ] || GROUP="$(slugify "$GROUP")"
base_ref="${AGAINST:-$PROJECT_BASE_REF}"

ports_file="$DEVHUB_DIR/docker/$PROJECT_NAME/worktrees.ports"
[ -f "$ports_file" ] || { echo "No worktrees registered for $PROJECT_NAME." >&2; exit 0; }

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

# A changed file is in scope when it matches any glob of the lane's --owns fence.
# An empty fence means "whole repo": nothing is ever out of scope.
in_scope() {
  local file="$1" spec="$2" pat
  [ -n "$spec" ] || return 0
  local -a pats
  # Split the fence on commas WITHOUT pathname expansion (read -ra), then glob
  # each pattern against the file in the [[ == ]] test below.
  IFS=',' read -ra pats <<< "$spec"
  for pat in "${pats[@]}"; do
    [ -n "$pat" ] || continue
    # shellcheck disable=SC2053  # intentional glob match against the fence pattern
    [[ "$file" == $pat ]] && return 0
  done
  return 1
}

count_lines() {
  local n
  n="$(wc -l < "$1" 2>/dev/null || echo 0)"
  printf '%s' "${n//[[:space:]]/}"
}

lines_json_array() {
  local file="$1" out="" line
  [ -s "$file" ] || { printf '[]'; return 0; }
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    [ -n "$out" ] && out+=","
    out+="$(json_str "$line")"
  done < "$file"
  printf '[%s]' "$out"
}

slugs=()
branches=()
owns_specs=()
mig_slugs=()

while IFS='|' read -r slug port branch path app_ports group owns; do
  [ -n "$slug" ] || continue
  [ -z "$GROUP" ] || [ "$group" = "$GROUP" ] || continue
  [ -d "$path" ] || continue

  # Files this lane changed relative to the base ref (committed or not), plus
  # untracked files. Kept sorted+unique so `comm` can intersect two lanes.
  {
    git -C "$path" diff --name-only "$base_ref" -- 2>/dev/null || true
    git -C "$path" ls-files --others --exclude-standard 2>/dev/null || true
  } | LC_ALL=C sort -u > "$workdir/$slug.files"

  # Out-of-scope files (only when a fence is declared).
  : > "$workdir/$slug.oos"
  if [ -n "$owns" ]; then
    while IFS= read -r f || [ -n "$f" ]; do
      [ -n "$f" ] || continue
      in_scope "$f" "$owns" || printf '%s\n' "$f" >> "$workdir/$slug.oos"
    done < "$workdir/$slug.files"
  fi

  if grep -qE '(^|/)migrations/' "$workdir/$slug.files" 2>/dev/null; then
    mig_slugs+=("$slug")
  fi

  slugs+=("$slug")
  branches+=("$branch")
  owns_specs+=("$owns")
done < "$ports_file"

# Pairwise overlaps: same file changed by two lanes.
: > "$workdir/overlaps.tsv"   # slug_a<TAB>slug_b<TAB>file
n=${#slugs[@]}
for ((i = 0; i < n; i++)); do
  for ((j = i + 1; j < n; j++)); do
    a="${slugs[$i]}"; b="${slugs[$j]}"
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      printf '%s\t%s\t%s\n' "$a" "$b" "$f" >> "$workdir/overlaps.tsv"
    done < <(LC_ALL=C comm -12 "$workdir/$a.files" "$workdir/$b.files")
  done
done

# Materialize the migrations list once (used by both JSON and human output).
: > "$workdir/mig.files"
for m in "${mig_slugs[@]:-}"; do
  [ -n "$m" ] && printf '%s\n' "$m" >> "$workdir/mig.files"
done

# Conflict = any overlap, any out-of-scope file, or migrations touched by >1 lane.
conflict=0
[ -s "$workdir/overlaps.tsv" ] && conflict=1
for s in "${slugs[@]:-}"; do
  [ -n "$s" ] || continue
  [ -s "$workdir/$s.oos" ] && conflict=1
done
[ "${#mig_slugs[@]}" -gt 1 ] && conflict=1

if [ "$JSON_OUT" -eq 1 ]; then
  printf '{"v":1,"project":%s,"against":%s,"conflict":%s,"worktrees":[' \
    "$(json_str "$PROJECT_NAME")" "$(json_str "$base_ref")" \
    "$([ "$conflict" -eq 1 ] && echo true || echo false)"
  for ((i = 0; i < n; i++)); do
    s="${slugs[$i]}"
    [ "$i" -eq 0 ] || printf ','
    changed_count="$(count_lines "$workdir/$s.files")"
    mig=false
    for m in "${mig_slugs[@]:-}"; do [ "$m" = "$s" ] && mig=true; done
    printf '{"slug":%s,"branch":%s,"changed":%s,"owns":%s,"out_of_scope":%s,"migrations":%s}' \
      "$(json_str "$s")" \
      "$(json_str "${branches[$i]}")" \
      "$changed_count" \
      "$(csv_json_array "${owns_specs[$i]}")" \
      "$(lines_json_array "$workdir/$s.oos")" \
      "$mig"
  done
  printf '],"overlaps":['
  # Group overlap rows by (slug_a, slug_b).
  first=1
  while IFS= read -r pair; do
    [ -n "$pair" ] || continue
    a="${pair%%$'\t'*}"; b="${pair#*$'\t'}"
    [ "$first" -eq 1 ] || printf ','
    first=0
    awk -F'\t' -v a="$a" -v b="$b" '$1==a && $2==b { print $3 }' "$workdir/overlaps.tsv" > "$workdir/pair.files"
    printf '{"pair":[%s,%s],"files":%s}' \
      "$(json_str "$a")" "$(json_str "$b")" "$(lines_json_array "$workdir/pair.files")"
  done < <(cut -f1,2 "$workdir/overlaps.tsv" | LC_ALL=C sort -u)
  printf '],"migrations":%s}\n' "$(lines_json_array "$workdir/mig.files")"
  [ "$conflict" -eq 1 ] && exit 6 || exit 0
fi

# Human output.
if [ "$n" -eq 0 ]; then
  echo "No worktrees to compare${GROUP:+ in group $GROUP}."
  exit 0
fi

echo "Conflict check for $PROJECT_NAME${GROUP:+ (group: $GROUP)} against: $base_ref"
echo
printf "%-30s %-24s %-8s %s\n" "WORKTREE" "BRANCH" "CHANGED" "FLAGS"
printf "%-30s %-24s %-8s %s\n" "--------" "------" "-------" "-----"
for ((i = 0; i < n; i++)); do
  s="${slugs[$i]}"
  changed_count="$(count_lines "$workdir/$s.files")"
  flags=""
  [ -s "$workdir/$s.oos" ] && flags+="out-of-scope($(count_lines "$workdir/$s.oos")) "
  for m in "${mig_slugs[@]:-}"; do [ "$m" = "$s" ] && flags+="migrations "; done
  printf "%-30s %-24s %-8s %s\n" "$s" "${branches[$i]}" "$changed_count" "${flags:-ok}"
done

if [ -s "$workdir/overlaps.tsv" ]; then
  echo
  echo "Overlaps (same file changed by two lanes):"
  while IFS= read -r pair; do
    [ -n "$pair" ] || continue
    a="${pair%%$'\t'*}"; b="${pair#*$'\t'}"
    echo "  $a <-> $b"
    awk -F'\t' -v a="$a" -v b="$b" '$1==a && $2==b { print "    " $3 }' "$workdir/overlaps.tsv"
  done < <(cut -f1,2 "$workdir/overlaps.tsv" | LC_ALL=C sort -u)
fi

for ((i = 0; i < n; i++)); do
  s="${slugs[$i]}"
  if [ -s "$workdir/$s.oos" ]; then
    echo
    echo "Out-of-scope changes in $s (outside --owns '${owns_specs[$i]}'):"
    sed 's/^/    /' "$workdir/$s.oos"
  fi
done

if [ "${#mig_slugs[@]}" -gt 1 ]; then
  echo
  echo "Migrations changed by multiple lanes: ${mig_slugs[*]}"
fi

echo
if [ "$conflict" -eq 1 ]; then
  echo "Result: CONFLICTS DETECTED — serialize the offending lanes before merging."
  exit 6
fi
echo "Result: clean — lanes are disjoint."
exit 0
