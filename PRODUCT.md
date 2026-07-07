# DevHub Product Context

## Product

DevHub is a local development infrastructure hub for developers who work across several projects, branches, and framework stacks. It provides shared Docker Compose services once, then lets each project add a lightweight runtime and one localhost port per Git worktree.

## Register

brand

The public documentation page is a brand and documentation landing surface. Its job is to make the local workflow feel simple, premium, and trustworthy before the visitor reads commands.

## Users

- Solo developers managing multiple local projects.
- Teams who want consistent local infrastructure without duplicating Compose files in every repository.
- Developers using Symfony, Laravel, Next.js, TanStack Start, Hono, or FastAPI DDD.
- Power users who use Git worktrees and want one clean local URL per branch.

## Product Purpose

DevHub replaces repeated per-project infrastructure with one shared local hub. It should make the mental model obvious:

- Start shared services once.
- Register a project from the current directory or an existing repository.
- Add worktrees as needed.
- Run each worktree at the root of its own localhost port.
- Keep local databases, env files, and overrides private to the machine.

## Positioning

DevHub is not a cloud platform, orchestration suite, or heavy developer portal. It is a pragmatic local tool that keeps Docker infrastructure boring and branch runtimes predictable.

## Voice

Calm, direct, precise. The copy should sound like a senior engineer explaining the shortest reliable path. Avoid hype, jokes, and generic SaaS promises.

## Design Principles

- Make the workflow feel lighter than Docker usually feels.
- Prefer clarity over decoration.
- Use one strong product name moment, then let commands and examples carry the page.
- Keep the page useful as documentation, not just as a landing page.
- Avoid visual noise, dense color palettes, and decorative gradients.

## Anti References

- Dark terminal dashboards as a default developer-tool costume.
- Bright green, copper, amber, or forest palettes that make the product feel heavy.
- Generic SaaS cards with repetitive icons and marketing blurbs.
- Documentation pages that hide commands behind too much brand treatment.
- Subdomain or DNS-heavy mental models. DevHub is localhost-first.

## Core Message

DevHub gives you one shared local infrastructure stack and clean localhost runtimes for every project worktree.
