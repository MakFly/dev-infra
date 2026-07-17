#!/usr/bin/env bats

# Integration tests for `devhub project adopt` against a throwaway
# DEVHUB_DIR fixture and real local git checkouts. No Docker service is
# required: POSTGRES_CONTAINER points to a container that never exists,
# so DB provisioning is skipped.

REPO="$BATS_TEST_DIRNAME/.."

setup() {
  export DEVHUB_DIR="$BATS_TEST_TMPDIR/devhub"
  export POSTGRES_CONTAINER="devhub-bats-absent"
  mkdir -p "$DEVHUB_DIR/data/projects" "$DEVHUB_DIR/docker" "$DEVHUB_DIR/overrides"
  cp -r "$REPO/templates" "$DEVHUB_DIR/templates"

  SRC="$BATS_TEST_TMPDIR/legacy-app"
  mkdir -p "$SRC"
  git init -q -b main "$SRC"
  printf '{\n  "dependencies": { "next": "16" }\n}\n' > "$SRC/package.json"
  git -C "$SRC" add .
  git -C "$SRC" -c user.name=devhub -c user.email=devhub@local commit -q -m init
}

project() { "$REPO/data/scripts/project-init.sh" "$@"; }

@test "adopt migrates a single-app checkout in one command" {
  printf 'API_KEY=secret\n' > "$SRC/.env.local"

  run project adopt "$SRC" --port-start 18101 --port-end 18102 --runtime-port 18100
  [ "$status" -eq 0 ]

  HUB="$BATS_TEST_TMPDIR/legacy-app-hub"
  # registry + bare repo + main worktree
  grep -q "PROJECT_STACK=nextjs" "$DEVHUB_DIR/data/projects/legacy-app.env"
  grep -q "PROJECT_REPO_KIND=bare" "$DEVHUB_DIR/data/projects/legacy-app.env"
  [ -d "$HUB/repo.git" ]
  [ -f "$HUB/worktrees/main/package.json" ]
  grep -q "^main|18101|main|" "$DEVHUB_DIR/docker/legacy-app/worktrees.ports"
  # runtime override rendered
  [ -f "$DEVHUB_DIR/overrides/legacy-app-app.override.yml" ]
  # rendered env kept, source vars merged in
  grep -q "infra-postgres" "$HUB/worktrees/main/.env.local"
  grep -q "API_KEY=secret" "$HUB/worktrees/main/.env.local"
  # agent workspace generated: guide + agents + skills + permissions
  grep -q "legacy-app" "$HUB/CLAUDE.md"
  grep -q "wt add legacy-app" "$HUB/AGENTS.md"
  grep -q "legacy-app" "$HUB/.claude/agents/implementer.md"
  [ -f "$HUB/.claude/agents/implementer-ui.md" ]
  [ -f "$HUB/.claude/agents/security-review.md" ]
  [ -f "$HUB/.claude/agents/perf.md" ]
  grep -q "wt add legacy-app" "$HUB/.claude/skills/orchestrate/SKILL.md"
  grep -q "one worktree" "$HUB/.claude/skills/orchestrate-fast/SKILL.md"
  grep -q "devhub wt add" "$HUB/.claude/settings.json"
  # hub Makefile with the project name baked in
  grep -q "PROJECT := legacy-app" "$HUB/Makefile"
  grep -q "^run:" "$HUB/Makefile"
}

@test "project init also generates the agent workspace" {
  run project init fresh --stack hono --root "$BATS_TEST_TMPDIR/fresh" \
    --port-start 18140 --port-end 18141 --runtime-port 18139
  [ "$status" -eq 0 ]
  grep -q "wt add fresh" "$BATS_TEST_TMPDIR/fresh/CLAUDE.md"
  [ -f "$BATS_TEST_TMPDIR/fresh/AGENTS.md" ]
  [ -f "$BATS_TEST_TMPDIR/fresh/.claude/agents/implementer-backend.md" ]
  [ -f "$BATS_TEST_TMPDIR/fresh/.claude/skills/orchestrate-fast/SKILL.md" ]
}

@test "adopt picks the workspace app dir and wraps the dev command" {
  mkdir -p "$SRC/apps/web"
  mv "$SRC/package.json" "$SRC/apps/web/package.json"
  printf '{ "workspaces": ["apps/*"] }\n' > "$SRC/package.json"
  git -C "$SRC" add .
  git -C "$SRC" -c user.name=devhub -c user.email=devhub@local commit -q -m mono

  run project adopt "$SRC" --name mono --port-start 18103 --port-end 18104 --runtime-port 18105
  [ "$status" -eq 0 ]
  # the registry stores %q-escaped values: cd\ apps/web\ &&\ ...
  grep -qF 'cd\ apps/web' "$DEVHUB_DIR/data/projects/mono.env"
  grep -q "infra-postgres" "$BATS_TEST_TMPDIR/legacy-app-hub/worktrees/main/apps/web/.env.local"
}

@test "adopt goes multi-app on an ambiguous monorepo, one port per app" {
  mkdir -p "$SRC/apps/web" "$SRC/apps/api"
  mv "$SRC/package.json" "$SRC/apps/web/package.json"
  printf 'fastapi\n' > "$SRC/apps/api/requirements.txt"
  printf '{ "workspaces": ["apps/*"] }\n' > "$SRC/package.json"
  git -C "$SRC" add .
  git -C "$SRC" -c user.name=devhub -c user.email=devhub@local commit -q -m mono
  # untracked in the source, like a real gitignored env file
  printf 'OPENAI_API_KEY=sk-test\n' > "$SRC/apps/api/.env"

  run project adopt "$SRC" --name mono2 --port-start 18106 --port-end 18109 --runtime-port 18105
  [ "$status" -eq 0 ]

  HUB="$BATS_TEST_TMPDIR/legacy-app-hub"
  # registry: multi stack + apps map (primary web first; %q escapes the comma)
  grep -q "PROJECT_STACK=multi" "$DEVHUB_DIR/data/projects/mono2.env"
  grep -qF 'web=apps/web=nextjs\,api=apps/api=fastapi-ddd' "$DEVHUB_DIR/data/projects/mono2.env"
  # ports file: primary port + per-app map in field 5, empty group/owns in 6/7
  grep -q "^main|18106|main|.*|web=18106,api=18107||$" "$DEVHUB_DIR/docker/mono2/worktrees.ports"
  # each app got its own env, with its own port and cross-app wiring
  grep -q "NEXT_PUBLIC_APP_URL=http://localhost:18106" "$HUB/worktrees/main/apps/web/.env.local"
  grep -q "NEXT_PUBLIC_API_URL=http://localhost:18107" "$HUB/worktrees/main/apps/web/.env.local"
  grep -q "APP_URL=http://localhost:18107" "$HUB/worktrees/main/apps/api/.env"
  grep -q "DEVHUB_WEB_URL=http://localhost:18106" "$HUB/worktrees/main/apps/api/.env"
  # source API key carried over
  grep -q "OPENAI_API_KEY=sk-test" "$HUB/worktrees/main/apps/api/.env"
  # override carries PROJECT_APPS for the runtime
  grep -qF 'PROJECT_APPS: "web=apps/web=nextjs,api=apps/api=fastapi-ddd"' "$DEVHUB_DIR/overrides/mono2-app.override.yml"
  # only allocated ports are published (no whole-range binding)
  grep -qF '127.0.0.1:18106:18106' "$DEVHUB_DIR/overrides/mono2-app.override.yml"
  grep -qF '127.0.0.1:18107:18107' "$DEVHUB_DIR/overrides/mono2-app.override.yml"
  ! grep -q '18106-18109' "$DEVHUB_DIR/overrides/mono2-app.override.yml"
}

@test "wt add on a multi-app project allocates ports per app and reports them in JSON" {
  mkdir -p "$SRC/apps/web" "$SRC/apps/api"
  mv "$SRC/package.json" "$SRC/apps/web/package.json"
  printf 'fastapi\n' > "$SRC/apps/api/requirements.txt"
  printf '{ "workspaces": ["apps/*"] }\n' > "$SRC/package.json"
  git -C "$SRC" add .
  git -C "$SRC" -c user.name=devhub -c user.email=devhub@local commit -q -m mono
  project adopt "$SRC" --name mono3 --port-start 18120 --port-end 18125 --runtime-port 18119 >/dev/null

  wt_add() { "$REPO/data/scripts/wt-add.sh" "$@" 2>/dev/null; }
  wt_list() { "$REPO/data/scripts/wt-list.sh" "$@" 2>/dev/null; }

  run wt_add mono3 feat/x --json
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r .port)" = "18122" ]
  [ "$(echo "$output" | jq -r .apps.web)" = "18122" ]
  [ "$(echo "$output" | jq -r .apps.api)" = "18123" ]

  # idempotent re-add re-prints the same apps map
  run wt_add mono3 feat/x --json
  [ "$status" -eq 3 ]
  [ "$(echo "$output" | jq -r .apps.api)" = "18123" ]

  # wt list exposes the apps map
  run wt_list mono3 --json
  [ "$(echo "$output" | jq -r '.worktrees[1].apps.api')" = "18123" ]

  # wt rm: generated app env files don't count as dirt, ports unpublished
  run "$REPO/data/scripts/wt-rm.sh" mono3 feat-x --json
  [ "$status" -eq 0 ]
  ! grep -q "18122" "$DEVHUB_DIR/overrides/mono3-app.override.yml"
  grep -q "127.0.0.1:18120:18120" "$DEVHUB_DIR/overrides/mono3-app.override.yml"
}

@test "adopt --stack still picks a single app in a monorepo" {
  mkdir -p "$SRC/apps/web" "$SRC/apps/api"
  mv "$SRC/package.json" "$SRC/apps/web/package.json"
  printf 'fastapi\n' > "$SRC/apps/api/requirements.txt"
  printf '{ "workspaces": ["apps/*"] }\n' > "$SRC/package.json"
  git -C "$SRC" add .
  git -C "$SRC" -c user.name=devhub -c user.email=devhub@local commit -q -m mono

  run project adopt "$SRC" --name single --stack nextjs --port-start 18130 --port-end 18131 --runtime-port 18129
  [ "$status" -eq 0 ]
  grep -qF 'cd\ apps/web' "$DEVHUB_DIR/data/projects/single.env"
  grep -q "PROJECT_APPS=''" "$DEVHUB_DIR/data/projects/single.env"
}

@test "adopt refuses an already registered project and a non-git source" {
  project adopt "$SRC" --name once --port-start 18109 --port-end 18110 --runtime-port 18111 >/dev/null
  run project adopt "$SRC" --name once
  [ "$status" -eq 1 ]
  [[ "$output" == *"already registered"* ]]

  mkdir -p "$BATS_TEST_TMPDIR/not-a-repo"
  run project adopt "$BATS_TEST_TMPDIR/not-a-repo"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Not a Git checkout"* ]]
}

@test "adopt warns about uncommitted changes left in the source" {
  printf 'wip\n' > "$SRC/wip.txt"
  run project adopt "$SRC" --name dirty --port-start 18112 --port-end 18113 --runtime-port 18114
  [ "$status" -eq 0 ]
  [[ "$output" == *"uncommitted change"* ]]
}
