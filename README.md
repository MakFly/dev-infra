# DevHub - Local Docker Development Infrastructure for PHP, Node.js, Databases, Mail, Search, Queues, and Storage

DevHub is a portable Docker Compose development environment for teams and solo
developers who need shared local infrastructure across multiple projects. It
starts common development services such as PostgreSQL, MySQL, Redis,
Meilisearch, Mailpit, Adminer, Dozzle, RabbitMQ, MinIO, FrankenPHP, and Node.js
behind one CLI: `devhub`.

It is designed for local web application development, PHP development, Node.js
development, Symfony/Laravel-style stacks, API projects, workers, queues,
email testing, database administration, search engines, and S3-compatible local
storage.

Keywords: Docker Compose local development, PHP 8.5 Docker, Node.js 24 Docker,
PostgreSQL dev environment, MySQL dev environment, Redis local cache,
Meilisearch local search, Mailpit SMTP testing, RabbitMQ local queue,
FrankenPHP development, shared Docker network, developer infrastructure.

## Contents

- [Features](#features)
- [Services](#services)
- [Profiles](#profiles)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [CLI Reference](#cli-reference)
- [Service URLs](#service-urls)
- [Database Management](#database-management)
- [Project Runtime Overrides](#project-runtime-overrides)
- [Connect Another Project](#connect-another-project)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Security Notes](#security-notes)

## Features

- One shared Docker Compose stack for multiple local projects.
- Stable service names and ports for databases, cache, mail, search, queues,
  logs, and admin tools.
- Shared external Docker network: `dev-shared-net`.
- CLI wrapper for startup, shutdown, logs, health checks, database creation,
  browser shortcuts, and project-specific runtimes.
- Local PHP and Node.js runtime templates, including PHP 8.5 and Node.js 24.
- Compose profiles so optional services do not need to run all the time.
- Local-only override convention for project runtimes.

## Services

| Service | Container | Default Port(s) | UI URL | Purpose |
|---------|-----------|-----------------|--------|---------|
| PostgreSQL | `infra-postgres` | `5432` | - | Relational database |
| MySQL | `infra-mysql` | `3306` | - | Relational database |
| Redis | `infra-redis` | `6379` | - | Cache and sessions |
| Meilisearch | `infra-meilisearch` | `7700` | <http://localhost:7700> | Local search engine |
| Mailpit | `infra-mailpit` | `1025`, `8025` | <http://localhost:8025> | SMTP and email testing |
| Adminer | `infra-adminer` | `9080` | <http://localhost:9080> | Database administration |
| Dozzle | `infra-dozzle` | `8888` | <http://localhost:8888> | Docker log viewer |
| RabbitMQ | `infra-rabbitmq` | `5672`, `15672` | <http://localhost:15672> | Message broker and queues |
| FrankenPHP 8.1 | `infra-frankenphp-81` | `8001` | <http://localhost:8001> | PHP runtime template |
| FrankenPHP 8.2 | `infra-frankenphp-82` | `8002` | <http://localhost:8002> | PHP runtime template |
| FrankenPHP 8.5 | `infra-frankenphp-85` | `8005` | <http://localhost:8005> | PHP runtime template |
| Node.js 20 | `infra-node-20` | `3002`, `5173` | <http://localhost:3002> | Node runtime template |
| Node.js 22 | `infra-node-22` | `3003`, `5173` | <http://localhost:3003> | Node runtime template |
| Node.js 24 | `infra-node-24` | `3004`, `5175` | <http://localhost:3004> | Node runtime template |
| MinIO | `minio` | `9000`, `9001` | <http://localhost:9001> | S3-compatible storage, archived |

## Profiles

| Profile | Services | Default |
|---------|----------|---------|
| `core` | PostgreSQL, MySQL, Redis, Meilisearch, Mailpit, Adminer, Dozzle | Yes |
| `storage` | MinIO | Yes, archived |
| `async` | RabbitMQ | No |
| `php81` | FrankenPHP 8.1 template | No |
| `php82` | FrankenPHP 8.2 template | No |
| `php85` | FrankenPHP 8.5 template | No |
| `node` | Node.js 20 template | No |
| `node22` | Node.js 22 template | No |
| `node24` | Node.js 24 template | No |

Default startup uses `core,storage`. Add optional profiles with
`devhub up --with <profile>`.

## Requirements

- Docker Engine 24 or newer
- Docker Compose v2
- Bash
- Optional: `make` for shortcuts
- Optional: `xdg-open` on Linux or `open` on macOS for `devhub open`

## Installation

```bash
git clone git@github.com:MakFly/dev-infra.git dev-infra
cd dev-infra
cp .env.example .env
make install
```

`make install` creates a symlink at `~/.local/bin/devhub` and installs zsh
shortcuts in `~/.config/devhub/devhub.zsh`.

If you do not want shell shortcuts, run the CLI directly:

```bash
./bin/devhub help
```

## Quick Start

```bash
# Start default shared services: core + storage
devhub up

# Start RabbitMQ too
devhub up --with async

# Start local PHP 8.5 and Node.js 24 runtime templates
devhub up --with php85,node24

# Show status
devhub ps

# Inspect health, network, and ports
devhub doctor
```

## CLI Reference

| Command | Description |
|---------|-------------|
| `devhub up [--with profile[,profile]]` | Start shared services, default `core,storage` |
| `devhub down` | Stop and remove shared service containers |
| `devhub restart` | Restart default shared services |
| `devhub ps` | Show service status |
| `devhub logs [service]` | Follow logs for all services or one service |
| `devhub open <target>` | Open a service UI in the browser |
| `devhub db create <db> [user] [password]` | Create a PostgreSQL database and role |
| `devhub db import [trading\|distribution\|all]` | Import DB dumps when a local importer exists |
| `devhub db list` | List non-template PostgreSQL databases |
| `devhub runtime <project>` | Start a local project runtime override |
| `devhub down-runtime <project>` | Stop a local project runtime override |
| `devhub doctor` | Show health, network, and port diagnostics |
| `devhub help` | Show CLI help |

Make shortcuts:

```bash
make up
make up-async
make up-local
make ps
make doctor
make down
```

## Service URLs

```bash
devhub open mailpit     # http://localhost:8025
devhub open adminer     # http://localhost:9080
devhub open dozzle      # http://localhost:8888
devhub open minio       # http://localhost:9001
devhub open rabbitmq    # http://localhost:15672
devhub open meili       # http://localhost:7700
```

## Database Management

Create a PostgreSQL database with a matching user and password:

```bash
devhub db create myapp
```

Create a database with explicit credentials:

```bash
devhub db create myapp myuser mypassword
```

List databases:

```bash
devhub db list
```

Default local connection examples:

```text
PostgreSQL: postgres://test:test@localhost:5432/devhub
MySQL:      mysql://test:test@localhost:3306/trading
Redis:      redis://localhost:6379
Meilisearch http://localhost:7700
Mailpit SMTP localhost:1025
```

## Project Runtime Overrides

Project-specific Docker Compose overrides live in:

```text
overrides/<project>-app.override.yml
```

Start and stop a project runtime:

```bash
devhub runtime myproject
devhub down-runtime myproject
```

Example override:

```yaml
services:
  myproject-php:
    image: dunglas/frankenphp:1-php8.5
    container_name: myproject-php
    volumes:
      - /path/to/project:/var/www/html
    working_dir: /var/www/html
    environment:
      - DATABASE_URL=postgres://test:test@infra-postgres:5432/myproject
      - REDIS_URL=redis://infra-redis:6379
    ports:
      - "8010:80"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - dev-shared-net
```

Override files are local by convention. The repository keeps only placeholders
inside `overrides/`.

## Connect Another Project

Attach a separate application Compose file to the shared DevHub network:

```yaml
networks:
  dev-shared-net:
    external: true
```

Then point application services at DevHub container names:

```text
infra-postgres
infra-mysql
infra-redis
infra-meilisearch
infra-mailpit
infra-rabbitmq
```

## Configuration

Copy `.env.example` to `.env` and customize local ports, credentials, and image
tags:

```bash
cp .env.example .env
```

Common variables:

```dotenv
POSTGRES_PORT=5432
MYSQL_ROOT_PASSWORD=root
REDIS_PORT=6379
MEILI_PORT=7700
MAILPIT_UI_PORT=8025
FRANKENPHP_85_IMAGE=dunglas/frankenphp:1-php8.5
FRANKENPHP_85_PORT=8005
NODE_24_IMAGE=node:24-alpine
NODE_24_PORT=3004
NODE_24_VITE_PORT=5175
```

## Troubleshooting

Run diagnostics:

```bash
devhub doctor
```

Check running containers:

```bash
devhub ps
```

Follow logs:

```bash
devhub logs
devhub logs postgres
```

If the shared network is missing, `devhub up`, `devhub db create`, and
`devhub doctor` create `dev-shared-net` automatically.

If a port is already in use, edit `.env` and change the matching `*_PORT`
variable before starting services.

## Security Notes

- This stack is intended for local development, not production.
- Default credentials in `.env.example` are development credentials.
- `.env` is ignored and should stay local.
- Dozzle mounts the Docker socket for local log visibility.
- Named Docker volumes contain local developer data; do not remove them unless
  you intentionally want to delete local databases or storage.
- MinIO is archived in this stack and should not be expanded unless a project
  explicitly still needs it.

## License

MIT
