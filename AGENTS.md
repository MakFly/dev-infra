# AGENTS.md

Repository instructions for AI coding agents working on DevHub.

## Project Overview

DevHub is shared local development infrastructure built around Docker Compose.
It provides PostgreSQL, MySQL, Redis, Meilisearch, Mailpit, Adminer, Dozzle,
RabbitMQ, archived MinIO support, and optional project runtimes through
Compose override files.

Primary entry points:
- `bin/devhub`: Bash CLI used by humans and automation.
- `compose.yml`: shared service definitions and profiles.
- `data/scripts/`: helper scripts for install, database creation, networking,
  health checks, and uninstall.
- `overrides/`: local project override files; committed content should stay
  limited to placeholders unless explicitly requested.

## Search Tools

- Prefer `ig` over `rg` or `grep` for code search.
- Use `ig "pattern" [path]`, `ig smart [path]`, and `ig read <file> -s` when
  you need compact project context.
- `ig` indexes live under the user cache, not in the repository. Do not create
  or commit `.ig/`, and do not add new ignore rules for it.
- Fall back to `rg` only if `ig --version` fails.

## Working Principles

These guidelines follow the style of the Karpathy coding-agent example:

1. Think before coding.
   State assumptions when behavior is ambiguous. If multiple interpretations
   are plausible and the choice affects user data, ports, credentials, or
   Docker volumes, ask before changing behavior.

2. Keep changes simple.
   Do not add abstraction, configurability, or new tooling unless it directly
   supports the requested change. This repository is intentionally small.

3. Make surgical edits.
   Touch only files needed for the task. Preserve existing CLI behavior,
   command names, container names, Compose profiles, and default ports unless
   the request is explicitly about changing them.

4. Verify the result.
   For shell changes, at minimum run syntax checks. For Compose changes, render
   the config. For CLI changes, exercise the affected command path when Docker
   state allows it.

## Validation Commands

Use the smallest useful verification set:

```bash
bash -n bin/devhub data/scripts/*.sh
COMPOSE_PROFILES=core,storage,async,php81,php82,php85,node,node22,node24 docker compose --env-file .env.example -f compose.yml config
./bin/devhub help
```

When Docker is running and the user asked for runtime behavior, also consider:

```bash
./bin/devhub doctor
./bin/devhub ps
```

Do not run destructive volume operations such as `docker compose down -v` unless
the user explicitly asks for data removal.

## Docker And Infrastructure Constraints

- `.env` is local and ignored. Keep examples in `.env.example` free of real
  secrets.
- Shared network name defaults to `dev-shared-net`; project containers must
  join that external network to reach DevHub services.
- Named volumes hold local developer data. Treat them as persistent user data.
- Dozzle mounts `/var/run/docker.sock`; changes around that service should be
  reviewed with extra care.
- MinIO is marked archived in `compose.yml`; do not expand its usage without an
  explicit request.
- `overrides/` and `docker/` are intended for local generated or private files;
  avoid committing project-specific content there unless requested.

## Style Notes

- Shell scripts use Bash with `set -euo pipefail`; keep that convention.
- Prefer explicit error messages and predictable exits for CLI commands.
- Keep README, CLI help, Makefile targets, and Compose profiles aligned when
  command behavior changes.
- If you find unrelated problems, mention them in the final response instead of
  fixing them opportunistically.
