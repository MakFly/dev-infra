# DevHub

**One command to run PostgreSQL, MySQL, Redis, Meilisearch, Mailpit, RabbitMQ, and more — shared across all your local projects.**

DevHub is a Docker Compose development stack controlled by a single Bash CLI.
Instead of defining database, cache, mail, search, and queue services in every
project, you start them once with `devhub up` and connect any application through
a shared Docker network.

Built for teams and solo developers working on multiple web applications, APIs,
or background workers that need common local infrastructure without per-project
duplication.

## Why DevHub

- **Start once, use everywhere** — one `devhub up` replaces duplicate
  `docker-compose.yml` files across projects.
- **Stable addresses** — every service has a fixed container name
  (`infra-postgres`, `infra-redis`, …) and configurable host port.
- **Profiles** — only run what you need. Core services start by default;
  RabbitMQ and Node.js are opt-in.
- **Project runtimes** — Compose override files let each project add its own
  containers (workers, apps) that join the shared network.
- **Built-in tooling** — database creation, health diagnostics, log tailing, and
  browser shortcuts from the CLI.

## Services

| Service | Container | Port(s) | UI | Profile |
|---|---|---|---|---|
| PostgreSQL 16 | `infra-postgres` | `5432` | — | core |
| MySQL 8 | `infra-mysql` | `3306` | — | core |
| Redis 7 | `infra-redis` | `6379` | — | core |
| Meilisearch | `infra-meilisearch` | `7700` | [localhost:7700](http://localhost:7700) | core |
| Mailpit | `infra-mailpit` | `1025` / `8025` | [localhost:8025](http://localhost:8025) | core |
| Adminer | `infra-adminer` | `9080` | [localhost:9080](http://localhost:9080) | core |
| Dozzle | `infra-dozzle` | `8888` | [localhost:8888](http://localhost:8888) | core |
| RabbitMQ 3 | `infra-rabbitmq` | `5672` / `15672` | [localhost:15672](http://localhost:15672) | async |
| Node.js 22 LTS | `infra-node` | `3002` / `5173` | — | node |

## Profiles

| Profile | Services | Default |
|---|---|---|
| `core` | PostgreSQL, MySQL, Redis, Meilisearch, Mailpit, Adminer, Dozzle | Yes |
| `async` | RabbitMQ | No |
| `node` | Node.js 22 LTS | No |

```bash
devhub up                  # core only
devhub up --with async     # core + RabbitMQ
```

## Requirements

- Docker Engine 24+ with Compose v2
- Bash
- `jq` (for `devhub runtime` / `devhub down-runtime`)
- Optional: `make`, `xdg-open` (Linux) or `open` (macOS)

## Installation

**One-liner** (installs to `~/.local/share/devhub`, no sudo):

```bash
curl -fsSL https://raw.githubusercontent.com/MakFly/dev-infra/main/install-remote.sh | bash
```

Custom install path:

```bash
DEVHUB_DIR=~/tools/devhub curl -fsSL https://raw.githubusercontent.com/MakFly/dev-infra/main/install-remote.sh | bash
```

**Manual** (if you prefer git clone):

```bash
git clone git@github.com:MakFly/dev-infra.git dev-infra
cd dev-infra
cp .env.example .env
make install
```

Both methods symlink the CLI to `~/.local/bin/devhub` and add zsh shortcuts
(`dh`, `dhup`, `dhps`, `dhdown`) via `~/.config/devhub/devhub.zsh`.

To skip shell integration, run the CLI directly:

```bash
./bin/devhub help
```

## Quick Start

```bash
devhub up               # start core services
devhub ps               # show container status
devhub doctor           # health, network, and port diagnostics
devhub open adminer     # open Adminer in browser
devhub db create myapp  # create a PostgreSQL database + role
```

## CLI Reference

| Command | Description |
|---|---|
| `devhub up [--with profile,...]` | Start shared services (default: `core`) |
| `devhub down` | Stop and remove all shared containers |
| `devhub restart [--with profile,...]` | Restart services |
| `devhub ps` | Show service status |
| `devhub logs [service]` | Follow logs |
| `devhub open <target>` | Open a service UI (`mailpit`, `adminer`, `dozzle`, `rabbitmq`, `meili`) |
| `devhub db create <db> [user] [pass]` | Create PostgreSQL database and role |
| `devhub db import [args]` | Run custom import script (`data/scripts/import-db.sh` or `DEVHUB_IMPORT_SCRIPT`) |
| `devhub db list` | List PostgreSQL databases |
| `devhub runtime <project>` | Start a project runtime override |
| `devhub down-runtime <project>` | Stop a project runtime |
| `devhub doctor` | Diagnostics: health, network, ports |
| `devhub help` | Show help |

**Make shortcuts:**

```bash
make up                          # start core
make up-async                    # start core + async
make down                        # stop all
make ps                          # status
make doctor                      # diagnostics
make runtime PROJECT=myproject   # start project runtime
make down-runtime PROJECT=myproject
```

## Database Management

```bash
devhub db create myapp                    # db=myapp, user=myapp, pass=myapp
devhub db create myapp myuser mypassword  # explicit credentials
devhub db list                            # list all databases
```

Default connection strings:

```text
PostgreSQL  postgres://test:test@localhost:5432/devhub
MySQL       mysql://test:test@localhost:3306/trading
Redis       redis://localhost:6379
Meilisearch http://localhost:7700
Mailpit     smtp://localhost:1025
```

## Project Runtime Overrides

Add project-specific containers via Compose override files in `overrides/`:

```text
overrides/<project>-app.override.yml
```

```bash
devhub runtime myproject       # start
devhub down-runtime myproject  # stop
```

Example override file:

```yaml
services:
  myproject-worker:
    image: node:22-alpine
    container_name: myproject-worker
    command: ["sh", "-lc", "npm install && npm run dev"]
    volumes:
      - /path/to/project:/workspace
    working_dir: /workspace
    environment:
      - DATABASE_URL=postgres://test:test@infra-postgres:5432/myproject
      - REDIS_URL=redis://infra-redis:6379
    ports:
      - "3010:3000"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - dev-shared-net
```

Override files are local by convention — the repository keeps only a `.gitkeep`
placeholder in `overrides/`.

## Connecting External Projects

Any Docker Compose project can reach DevHub services by joining the shared
network:

```yaml
# in your project's docker-compose.yml
networks:
  dev-shared-net:
    external: true
```

Then reference services by container name: `infra-postgres`, `infra-mysql`,
`infra-redis`, `infra-meilisearch`, `infra-mailpit`, `infra-rabbitmq`.

## Configuration

Copy `.env.example` to `.env` and override any default:

```bash
cp .env.example .env
```

All ports, credentials, and image tags are configurable. Common variables:

```dotenv
POSTGRES_PORT=5432
MYSQL_ROOT_PASSWORD=root
REDIS_PORT=6379
MEILI_PORT=7700
MAILPIT_UI_PORT=8025
NODE_PORT=3002
VITE_PORT=5173
```

## Troubleshooting

```bash
devhub doctor          # full diagnostics
devhub ps              # container status
devhub logs postgres   # follow a single service
```

- **Network missing** — `devhub up`, `devhub db create`, and `devhub doctor`
  auto-create `dev-shared-net`.
- **Port conflict** — edit `.env` and change the matching `*_PORT` variable.

## Security

This stack is for **local development only**. Default credentials in
`.env.example` are intentionally simple. `.env` is gitignored and stays local.
Dozzle mounts the Docker socket for log access. Named volumes hold developer
data — do not remove them unless you want to delete local databases.

## License

MIT
