# Changelog

All notable changes to DevHub are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.0.3] - 2026-07-18

### Added
- Mission lanes on top of worktrees, kept as derived state (no separate
  manifest): `devhub wt add` gains `--group <slug>` (tag lanes of one mission)
  and `--owns <glob[,glob]>` (declare a lane's file fence). `wt list` gains
  `--group` filtering and exposes `group`/`owns` in `--json`.
- `devhub wt conflicts <project> [--group <slug>] [--against <ref>] [--json]`:
  read-only, stateless conflict oracle. For each lane it diffs changed files
  against a base ref and reports overlaps (same file touched by two lanes),
  out-of-scope changes (outside the lane's `--owns` fence), and migrations
  touched by more than one lane. Exit `6` when conflicts are detected.

### Changed
- Worktree registry lines are now a fixed 7-column format
  (`slug|port|branch|path|app_ports|group|owns`); existing 4/5-column entries
  remain readable (missing columns are treated as empty).

## [0.0.2] - 2026-07-10

### Added
- `devhub project adopt <path>`: one-shot migration of an existing Git checkout
  into a worktree hub — stack auto-detection (root and `apps/*`/`packages/*`
  workspaces), bare clone, project registration, `main` worktree, untracked
  env-file carry-over, and a generated `CLAUDE.md`/`AGENTS.md` agent guide at
  the hub root (one worktree per terminal/agent via `devhub wt add`).
- Multi-app worktree runtime: monorepos with several bun/python apps are
  adopted as one project (`PROJECT_APPS` registry field, `templates/multi/`
  polyglot image). Each worktree gets one port per app, per-app env rendering,
  and cross-app URL injection (`DEVHUB_<APP>_URL`, `API_URL`,
  `NEXT_PUBLIC_API_URL`); `wt add`/`wt list --json` expose the `apps` map.
- Generated agent workspace (`templates/claude/`, rendered by both
  `project init` and `project adopt` at the hub root): `CLAUDE.md`/`AGENTS.md`
  worktree rules, `.claude/agents/` (implementer, implementer-ui/-backend/
  -tests, security-review, perf), `.claude/skills/orchestrate` and
  `orchestrate-fast` (one implementation lane = one worktree), and
  `.claude/settings.json` with a devhub command allowlist.
- Generated hub `Makefile` (project name baked in): `run`, `stop`, `status`,
  `ls`, `urls`, `add BRANCH=`, `rm SLUG=`, `logs`, `pull-main`,
  `pr BRANCH=`; new dev-infra Makefile targets `adopt`, `wt-add`, `wt-rm`,
  `wt-status`, `test`.
- Multi runtime hardening: the override publishes only allocated ports
  (re-rendered on `wt add`/`wt rm` with container recreate) instead of the
  whole project range, so a busy host port inside the range no longer blocks
  the container; the runtime runs as the host UID/GID so `node_modules`,
  `.venv` and build output stay removable by `wt rm` on the host.

## [0.0.1] - 2026-07-10

### Added
- First tagged release: shared Docker development infrastructure (`compose.yml`),
  the `bin/devhub` CLI, project/worktree tooling, and the remote installer.
- Versioned release system: `VERSION` source of truth, `devhub version` command,
  `data/scripts/release.sh`, and the `Release` GitHub Actions workflow.

[Unreleased]: https://github.com/MakFly/dev-infra/compare/v0.0.3...HEAD
[0.0.3]: https://github.com/MakFly/dev-infra/compare/v0.0.2...v0.0.3
[0.0.2]: https://github.com/MakFly/dev-infra/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/MakFly/dev-infra/releases/tag/v0.0.1
