#!/usr/bin/env bats

# Integration tests for the worktree scripts against a throwaway
# DEVHUB_DIR fixture and a real local git repo. No Docker service is
# required: POSTGRES_CONTAINER points to a container that never exists,
# so DB provisioning is skipped and reported as false.

REPO="$BATS_TEST_DIRNAME/.."

setup() {
  export DEVHUB_DIR="$BATS_TEST_TMPDIR/devhub"
  export POSTGRES_CONTAINER="devhub-bats-absent"
  mkdir -p "$DEVHUB_DIR/data/projects" "$DEVHUB_DIR/docker"
  cp -r "$REPO/templates" "$DEVHUB_DIR/templates"

  PROJECT_DIR="$BATS_TEST_TMPDIR/demo"
  mkdir -p "$PROJECT_DIR"
  git init --bare -q -b main "$PROJECT_DIR/repo.git"
  git init -q -b main "$BATS_TEST_TMPDIR/seed"
  git -C "$BATS_TEST_TMPDIR/seed" -c user.name=devhub -c user.email=devhub@local \
    commit -q --allow-empty -m init
  git -C "$BATS_TEST_TMPDIR/seed" push -q "$PROJECT_DIR/repo.git" main

  cat > "$DEVHUB_DIR/data/projects/demo.env" <<EOF
PROJECT_NAME=demo
PROJECT_STACK=hono
PROJECT_RUNTIME_KIND=bun
PROJECT_ROOT=$PROJECT_DIR
PROJECT_REPO=$PROJECT_DIR/repo.git
PROJECT_REPO_KIND=bare
PROJECT_WORKTREES=$PROJECT_DIR/worktrees
PROJECT_BASE_REF=main
PROJECT_PORT_START=18101
PROJECT_PORT_END=18102
PROJECT_RUNTIME_PORT=18100
PROJECT_CONTAINER=demo-runtime
PROJECT_DEV_COMMAND=
EOF
}

wt_add() { "$REPO/data/scripts/wt-add.sh" "$@" 2>/dev/null; }
wt_list() { "$REPO/data/scripts/wt-list.sh" "$@" 2>/dev/null; }
wt_status() { "$REPO/data/scripts/wt-status.sh" "$@" 2>/dev/null; }
wt_conflicts() { "$REPO/data/scripts/wt-conflicts.sh" "$@" 2>/dev/null; }
wt_rm() { "$REPO/data/scripts/wt-rm.sh" "$@" 2>/dev/null; }
project() { "$REPO/data/scripts/project-init.sh" "$@" 2>/dev/null; }

# Commit a lane's work. The generated .env.local is dropped first: real stack
# templates gitignore it, but the bare test repo does not, so it would show up
# as an untracked change in every lane and pollute the oracle.
lane_commit() {
  local dir="$1"
  rm -f "$dir/.env" "$dir/.env.local"
  git -C "$dir" -c user.name=devhub -c user.email=devhub@local add -A
  git -C "$dir" -c user.name=devhub -c user.email=devhub@local commit -qm work
}

@test "wt add creates worktree, allocates port, renders env, registers it" {
  run wt_add demo feat/x --json
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r .status)" = "created" ]
  [ "$(echo "$output" | jq -r .slug)" = "feat-x" ]
  [ "$(echo "$output" | jq -r .port)" = "18101" ]
  [ "$(echo "$output" | jq -r .db)" = "demo_feat_x" ]
  [ "$(echo "$output" | jq -r .db_provisioned)" = "false" ]
  [ -d "$PROJECT_DIR/worktrees/feat-x" ]
  grep -q "demo_feat_x" "$PROJECT_DIR/worktrees/feat-x/.env.local"
  grep -q "^feat-x|18101|feat/x|" "$DEVHUB_DIR/docker/demo/worktrees.ports"
}

@test "wt add is idempotent: second add exits 3 and re-prints the entry" {
  wt_add demo feat/x --json >/dev/null || true
  run wt_add demo feat/x --json
  [ "$status" -eq 3 ]
  [ "$(echo "$output" | jq -r .status)" = "exists" ]
  [ "$(echo "$output" | jq -r .port)" = "18101" ]
}

@test "wt add exits 4 when the project port range is exhausted" {
  wt_add demo feat/a --json >/dev/null
  wt_add demo feat/b --json >/dev/null
  run wt_add demo feat/c --json
  [ "$status" -eq 4 ]
}

@test "wt list --json returns registered worktrees" {
  wt_add demo feat/x --json >/dev/null
  wt_add demo feat/y --json >/dev/null
  run wt_list demo --json
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq '.worktrees | length')" = "2" ]
  [ "$(echo "$output" | jq -r '.worktrees[0].url')" = "http://localhost:18101" ]
}

@test "wt status reports http/db/runtime state without infra" {
  wt_add demo feat/x --json >/dev/null
  run wt_status demo --json
  [ "$status" -eq 0 ]
  runtime="$(echo "$output" | jq -r .runtime)"
  [ "$runtime" = "down" ] || [ "$runtime" = "unknown" ]
  [ "$(echo "$output" | jq -r '.worktrees[0].slug')" = "feat-x" ]
  [ "$(echo "$output" | jq -r '.worktrees[0].http')" != "ok" ]
  [ "$(echo "$output" | jq -r '.worktrees[0].db')" = "unknown" ]
}

@test "wt status on unknown slug exits 1" {
  wt_add demo feat/x --json >/dev/null
  run wt_status demo nope --json
  [ "$status" -eq 1 ]
}

@test "wt rm removes a clean worktree and its registry entry" {
  wt_add demo feat/x --json >/dev/null
  run wt_rm demo feat-x --json
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r .removed)" = "true" ]
  [ ! -d "$PROJECT_DIR/worktrees/feat-x" ]
  ! grep -q "^feat-x|" "$DEVHUB_DIR/docker/demo/worktrees.ports"
}

@test "wt rm refuses a dirty worktree with exit 5, --force removes it" {
  wt_add demo feat/x --json >/dev/null
  touch "$PROJECT_DIR/worktrees/feat-x/untracked.txt"
  run wt_rm demo feat-x --json
  [ "$status" -eq 5 ]
  [ -d "$PROJECT_DIR/worktrees/feat-x" ]
  run wt_rm demo feat-x --json --force
  [ "$status" -eq 0 ]
  [ ! -d "$PROJECT_DIR/worktrees/feat-x" ]
}

@test "wt add --group/--owns are stored and surfaced; wt list --group filters" {
  wt_add demo feat/a --group notif --owns 'src/**,lib/**' --json >/dev/null
  wt_add demo feat/b --json >/dev/null
  run wt_list demo --json
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.worktrees[] | select(.slug=="feat-a") | .group')" = "notif" ]
  [ "$(echo "$output" | jq -r '.worktrees[] | select(.slug=="feat-a") | .owns[1]')" = "lib/**" ]
  [ "$(echo "$output" | jq -r '.worktrees[] | select(.slug=="feat-b") | .group')" = "" ]
  run wt_list demo --group notif --json
  [ "$(echo "$output" | jq '.worktrees | length')" = "1" ]
  [ "$(echo "$output" | jq -r '.worktrees[0].slug')" = "feat-a" ]
}

@test "wt conflicts flags overlap and out-of-scope changes, exit 6" {
  wt_add demo feat/a --group m --owns 'src/**' --json >/dev/null
  wt_add demo feat/b --group m --owns 'src/**' --json >/dev/null
  wa="$PROJECT_DIR/worktrees/feat-a"
  wb="$PROJECT_DIR/worktrees/feat-b"
  mkdir -p "$wa/src" "$wb/src"
  echo a > "$wa/src/shared.ts"   # both lanes touch this -> overlap
  echo a > "$wa/docs.md"         # outside src/** -> out of scope for feat-a
  echo b > "$wb/src/shared.ts"
  lane_commit "$wa"
  lane_commit "$wb"
  run wt_conflicts demo --group m --json
  [ "$status" -eq 6 ]
  [ "$(echo "$output" | jq -r .conflict)" = "true" ]
  echo "$output" | jq -e '[.overlaps[].files[]] | index("src/shared.ts")'
  echo "$output" | jq -e '.worktrees[] | select(.slug=="feat-a") | .out_of_scope | index("docs.md")'
}

@test "wt conflicts returns 0 when lanes are disjoint" {
  wt_add demo feat/a --group m --owns 'a/**' --json >/dev/null
  wt_add demo feat/b --group m --owns 'b/**' --json >/dev/null
  wa="$PROJECT_DIR/worktrees/feat-a"
  wb="$PROJECT_DIR/worktrees/feat-b"
  mkdir -p "$wa/a" "$wb/b"
  echo x > "$wa/a/f.ts"
  echo y > "$wb/b/g.ts"
  lane_commit "$wa"
  lane_commit "$wb"
  run wt_conflicts demo --group m --json
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r .conflict)" = "false" ]
}

@test "project list --json returns registered projects" {
  run project list --json
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.projects[0].name')" = "demo" ]
  [ "$(echo "$output" | jq -r '.projects[0].stack')" = "hono" ]
}
