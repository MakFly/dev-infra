# CLAUDE.md

Behavioral and project instructions for Claude when working on this repository.
Merge these with the current user request and with `AGENTS.md`.

## Think Before Coding

Do not assume hidden project intent. Surface tradeoffs before changing behavior
that affects Docker services, ports, credentials, persisted volumes, or project
runtime overrides.

Before implementation:
- State the concrete goal and the files likely involved.
- Ask only when ambiguity could cause data loss or incompatible infrastructure
  behavior.
- Prefer the simplest fix that satisfies the request.

## Simplicity First

DevHub is a compact Bash and Docker Compose project. Keep it that way.

- No speculative features.
- No new framework or helper dependency for simple Bash/Compose edits.
- No abstraction for one-off behavior.
- No broad rewrites when a targeted patch solves the issue.

## Surgical Changes

Every changed line should trace back to the user request.

- Match existing Bash and YAML style.
- Preserve command names and service defaults unless explicitly changing them.
- Keep README, `bin/devhub`, `Makefile`, `.env.example`, and `compose.yml`
  consistent when behavior changes.
- Do not alter local-only override content or Docker generated content unless
  the task requires it.

## Goal-Driven Verification

Turn work into checks:

```bash
bash -n bin/devhub data/scripts/*.sh
COMPOSE_PROFILES=core,async,node docker compose --env-file .env.example -f compose.yml config
./bin/devhub help
```

For behavior that needs Docker, run the smallest relevant `./bin/devhub ...`
command if the local Docker state supports it. Never remove volumes or local
developer data without explicit permission.

## Project Facts

- Main CLI: `bin/devhub`
- Main Compose file: `compose.yml`
- Helper scripts: `data/scripts/`
- Local override convention: `overrides/<project>-app.override.yml`
- Shared network: `dev-shared-net`
- Default profile: `core`
- Optional profiles: `async`, `node`

## Releasing

Version lives in `VERSION` (single source of truth); `devhub version` prints it.
Cut a release from a clean `main` with `make release BUMP=...` — it bumps
`VERSION`, commits `chore(release): vX.Y.Z`, tags, and pushes; the tag triggers
the `Release` workflow (`.github/workflows/release.yml`) that publishes the
GitHub Release. Full docs: README "Releasing".

Pick the bump from the commits shipped since the last tag:

| Changes since last tag                                                   | Bump                              |
|--------------------------------------------------------------------------|-----------------------------------|
| Fix / docs / ci / refactor / chore only (`fix:`, `docs:`, `ci:`, …)      | `patch` (0.0.1 → 0.0.2)           |
| New user-facing feature or command (`feat:`)                             | `patch` while < 1.0.0, else `minor` |
| Breaking change (removed/renamed command, changed default, incompatible env/compose) | `major` / explicit jump  |

Pre-1.0 rule: while the version is `0.0.x`, ship **everything as `patch`**
(0.0.1 → 0.0.2 → … → 0.0.11 → 0.0.12). Only jump to `1.0.0` when the CLI and
compose contract is declared stable, and do it explicitly
(`make release BUMP=1.0.0`) — never automatically.

Rules:
- Never tag or push a release without explicit user confirmation.
- Preview first: `./data/scripts/release.sh <bump> --dry-run`.
- Update `CHANGELOG.md` (move `Unreleased` items under the new version) before cutting.
- If several change types are staged, use the highest bump they imply.

## Search

Use `ig` for repository search. Fall back to `rg` only if `ig --version` fails.
Do not create or commit `.ig/`.
