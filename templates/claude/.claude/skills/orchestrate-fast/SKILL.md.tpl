---
name: orchestrate-fast
description: Round-based multi-lane implementation for __PROJECT_NAME__ — one DevHub worktree per implementation lane, lead consolidates, verifies live, kills teammates when done and hands back test URLs. Trigger on "/orchestrate-fast", "multi-agent implementation", "spawn plusieurs agents", "fan-out implementation".
---

# Orchestrate-fast — one implementation lane = one worktree for __PROJECT_NAME__

You are the lead, running at the hub root: scheduler, conflict detector,
merge owner, and cleaner. Implementation lanes run in ISOLATED worktrees, so
they can never edit the same file on disk.

## Decision rule

Use parallel lanes only when the work splits into independent slices
(UI / backend / tests, separate domains) with clear acceptance criteria and
disjoint file ownership. Otherwise run /orchestrate (single lane). Never
parallelize migrations, auth/security, billing, or shared contract changes:
the lead lands those first, serially, on the integration branch, then cuts
the lanes from it.

Lane count: 2 by default, 3 for clearly independent larger work, 4 only on
explicit user request. Never more.

## Phase 0 — Preflight

```bash
devhub ps                                  # shared infra up? (else: devhub up)
devhub wt list __PROJECT_NAME__ --json      # existing worktrees + ports
devhub wt status __PROJECT_NAME__ --json    # runtime up? (else: devhub runtime __PROJECT_NAME__)
```

Read the hub `CLAUDE.md` rules. Check the repo state in the `main` worktree
(clean base, up-to-date) before cutting branches.

## Phase 1 — Decompose

Define: the integration branch `feat/<slug>`, the slices (goal + acceptance
criteria + file ownership each), the checks per slice, and an ASCII diagram
of the plan. Every slice must be verifiable on its own.

## Phase 2 — Worktrees

Integration first, then one worktree per lane, each branch cut FROM the
integration branch:

```bash
devhub wt add __PROJECT_NAME__ feat/<slug> --json                    # integration
devhub wt add __PROJECT_NAME__ feat/<slug>-ui feat/<slug> --json     # lane UI
devhub wt add __PROJECT_NAME__ feat/<slug>-api feat/<slug> --json    # lane backend
```

Capture `.path` and `.apps` from each JSON. Each `wt add` recreates the
runtime container (other worktrees restart ~30 s — expected, do it in one
batch, not spread over the run).

## Phase 3 — Implementation wave (one wave, all lanes in parallel)

Spawn all lanes in a single message (`implementer-ui`,
`implementer-backend`, `implementer-tests`, or generic `implementer`), each
with: its worktree path, its branch, the slice spec + acceptance criteria,
its file ownership (and what it must NOT touch), the checks to run, and the
required report format (files touched, behavior changed, checks run,
blockers, remaining work).

Lane contract: work only inside the assigned worktree, commit on its branch,
never `devhub wt add/rm`, never spawn agents, never push.

## Phase 4 — Consolidate

In the INTEGRATION worktree:

```bash
git merge feat/<slug>-ui && git merge feat/<slug>-api   # resolve conflicts yourself
```

Run the full checks there (lint, type-check, tests). Spawn a next wave only
for the remaining backlog; a lane that expanded beyond its ownership is
discarded until you review it.

## Phase 5 — Review fan-out (read-only, parallel)

`security-review` + `perf` together, on the integration worktree with the
`git diff <base>...HEAD` scope. Route P0/P1 findings to the owning lane or
fix them yourself in the integration worktree; re-run checks after fixes.

## Phase 6 — Verify live

The integration worktree is served — prove the feature works before
reporting:

```bash
devhub wt status __PROJECT_NAME__ feat-<slug> --json     # http must be "ok"
curl -sf http://localhost:<integration-app-port>/...     # exercise the feature
```

Green checks alone are not "done" when the change has a runtime surface.

## Phase 7 — Teardown (mandatory)

1. **Kill every teammate** as soon as its report is consolidated — never
   leave agents, teams, or background shells alive after their result is in.
   Before delivering, verify none is still running and kill leftovers.
2. **Remove the lane worktrees** — their branches are merged into the
   integration branch, so they are disposable:

   ```bash
   devhub wt rm __PROJECT_NAME__ feat-<slug>-ui
   devhub wt rm __PROJECT_NAME__ feat-<slug>-api
   ```

   `wt rm` exits 5 if a lane still has uncommitted work — that means an
   unmerged result: investigate, never `--force` blindly.
3. **Delete the lane branches** — they are local-only and now merged into
   the integration branch (`-d` refuses unmerged work, which is the point;
   never `-D`):

   ```bash
   git -C ../repo.git branch -d feat/<slug>-ui feat/<slug>-api
   ```

4. Keep the INTEGRATION worktree and its branch `feat/<slug>`: the user
   tests on it, and it is the ONLY branch that ever gets pushed (PR/MR).

## Phase 8 — Deliver

Present, in this order:
1. What shipped per slice, consolidated checks output.
2. Review findings and how each was addressed.
3. **Test URLs, ready to click**:

   ```text
   Feature ready to test:
   - web: http://localhost:<integration-web-port>
   - api: http://localhost:<integration-api-port>/health
   - main for comparison: http://localhost:<main-web-port>
   ```

4. The ship proposal: PR (`git push -u origin feat/<slug>` +
   `gh pr create --base <base>`) or local merge in the `main` worktree, then
   `devhub wt rm __PROJECT_NAME__ feat-<slug>`.

**Human gate:** never merge to the base branch, never push, never remove the
integration worktree without explicit user approval.

## Conflict policy

- Two lanes need the same file → that file moves to the lead (integration
  worktree), lanes get the rest.
- Shared type/schema/contract → lead lands it first on the integration
  branch, lanes are cut (or rebased) afterwards.
- A lane reports ambiguity → resolve it or ask the user; never let it guess.
