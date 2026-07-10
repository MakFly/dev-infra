---
name: orchestrate
description: Supervised dev cycle for __PROJECT_NAME__ on DevHub worktrees — preflight, plan, one implementation worktree, live verification, parallel security+perf review, teammate teardown, test URLs, human gate. Trigger on "orchestre ça", "orchestrate this", "plan build review", "lance le cycle", "feature supervisée".
---

# Orchestrate — supervised worktree cycle for __PROJECT_NAME__

You are the lead, running at the hub root. You plan, delegate, consolidate,
verify live, clean up, and own the final answer. Subagents never create or
remove worktrees and never spawn other agents.

## Phase 0 — Preflight

```bash
devhub ps                                  # shared infra up? (else: devhub up)
devhub wt list __PROJECT_NAME__ --json      # existing worktrees + ports
devhub wt status __PROJECT_NAME__ --json    # runtime up? http/db states
```

If the runtime is down, start it (`devhub runtime __PROJECT_NAME__`). Read
the hub `CLAUDE.md` rules before touching anything.

## Phase 1 — Plan

Restate the goal, define acceptance criteria as verifiable checks, name the
files involved (read them in the `main` worktree if needed), include an
ASCII diagram of the change. For non-trivial scope, get user approval before
implementing.

## Phase 2 — Feature worktree

```bash
devhub wt add __PROJECT_NAME__ feat/<slug> --json
```

Use `.path` and `.apps`/`.port` from the JSON (exit 3 = already exists —
reuse it). The runtime container is recreated automatically; other worktrees
restart briefly (~30 s), that is expected.

## Phase 3 — Delegate implementation

Spawn the `implementer` agent with: the worktree path, the branch, the spec
and acceptance criteria, file ownership, and the exact checks to run.
Required report: files touched, behavior changed, checks run and results,
blockers/assumptions, remaining work. If it reports ambiguity, resolve it or
ask the user — never let it guess.

## Phase 4 — Verify (yourself, in the worktree)

1. Run the project's checks from the worktree (lint, type-check, tests).
2. Wait for the worktree apps to answer, then exercise the feature for real:

   ```bash
   devhub wt status __PROJECT_NAME__ feat-<slug> --json    # http must be "ok"
   curl -sf http://localhost:<app-port>/...                # hit the actual feature
   ```

   Do not report success on green checks alone when the change has a runtime
   surface — observe it running.

## Phase 5 — Review fan-out (read-only, parallel)

Spawn `security-review` and `perf` together on the consolidated diff
(worktree path + `git diff <base>...HEAD` scope). Route P0/P1 findings back
to the implementer (or fix them yourself), re-run the checks, then re-verify.

## Phase 6 — Teardown teammates (mandatory)

As soon as a teammate's report is consolidated, stop it — never leave
agents, teams, or background shells running after their result is in. Before
delivering: verify nothing is still alive and kill leftovers. Keep the
feature worktree (the user tests on it); remove nothing else.

## Phase 7 — Deliver

Present, in this order:
1. What changed (files, behavior) and the checks output.
2. Review findings and how each was addressed.
3. **Test URLs, ready to click** — from `wt status`/`wt add --json`:

   ```text
   Feature ready to test:
   - web: http://localhost:<feature-web-port>
   - api: http://localhost:<feature-api-port>/health
   - main for comparison: http://localhost:<main-web-port>
   ```

4. The ship proposal: PR path (`git push -u origin feat/<slug>` +
   `gh pr create --base <base>`) or local merge in the `main` worktree, then
   `devhub wt rm __PROJECT_NAME__ feat-<slug>`.

**Human gate:** never merge, push, or `wt rm` the feature worktree without
explicit user approval.

## Hard limits

- Migrations, auth/security, billing, shared contracts: implement serially
  under your direct control, never delegated in parallel.
- Never push; never delete branches or worktrees without user approval.
- Never point two worktrees at the same database.
