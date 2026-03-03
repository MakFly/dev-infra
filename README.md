# DevHub - Shared Local Infrastructure

A portable Docker Compose setup for shared local development services across multiple projects and machines.

## Services

| Service | Container | Port(s) | UI URL | Purpose |
|---------|-----------|---------|--------|---------|
| **PostgreSQL** | `infra-postgres` | 5432 | - | Relational database |
| **Redis** | `infra-redis` | 6379 | - | Cache & sessions |
| **Meilisearch** | `infra-meilisearch` | 7700 | http://localhost:7700 | Search engine |
| **Mailpit** | `infra-mailpit` | 1025, 8025 | http://localhost:8025 | Email testing (SMTP + UI) |
| **Adminer** | `infra-adminer` | 9080 | http://localhost:9080 | Database management |
| **Dozzle** | `infra-dozzle` | 8888 | http://localhost:8888 | Container logs viewer |
| **MinIO** | `minio` | 9000, 9001 | http://localhost:9001 | S3-compatible storage (deprecated since 2026-02-21) |
| **RabbitMQ** | `infra-rabbitmq` | 5672, 15672 | http://localhost:15672 | Message broker |

### Runtimes (per-project)

| Service | Image | Profile | Port | Projects |
|---------|-------|---------|------|----------|
| **FrankenPHP 8.1** | `dunglas/franken-php:1.0-php8.1` | php81 | 8001 | - |
| **FrankenPHP 8.2** | `dunglas/franken-php:1.0-php8.2` | php82 | 8002 | distribution-v1, distribution-v2 |
| **Node 20** | `node:20-alpine` | node | 5173 | trading |
| **Node 22** | `node:22-alpine` | node22 | 5173 | - |
| **Bun 1** | `oven/bun:1-alpine` | - | 5175 | distribution-v2 |

## Profiles

| Profile | Services | Default |
|---------|----------|---------|
| `core` | postgres, redis, meilisearch, mailpit, adminer, dozzle | Yes |
| `storage` | minio | Yes (deprecated) |
| `async` | rabbitmq | No |
| `php81` | frankenphp-81 | No |
| `php82` | frankenphp-82 | No |
| `node` | node-20 | No |
| `node22` | node-22 | No |

## Installation

```bash
git clone <YOUR_REPO_URL> dev-services
cd dev-services
./scripts/install.sh
source ~/.zshrc  # or ~/.bashrc
```

The installer:
- Creates symlink `~/.local/bin/devhub` → `bin/devhub`
- Installs aliases in `~/.config/devhub/devhub.zsh`
- Creates `.env` from `.env.example` if missing

## Quick Start

```bash
# Start default services (core + storage)
devhub up

# Add extra profiles
devhub up --with async      # RabbitMQ
devhub up --with debug      # Redis Commander
devhub up --with async,debug
```

## CLI Reference

| Command | Description |
|---------|-------------|
| `devhub up [--with profile]` | Start services (default: core+storage) |
| `devhub down` | Stop and remove containers |
| `devhub restart` | Restart all services |
| `devhub ps` | Show container status |
| `devhub logs [service]` | Follow logs |
| `devhub open <target>` | Open service UI in browser |
| `devhub db create <name>` | Create a project database |
| `devhub db import [trading\|distribution\|all]` | Import tilvest DB dumps from pro/tilvest/data/ |
| `devhub db list` | List all databases |
| `devhub runtime <project>` | Start project runtime (trading/distribution) |
| `devhub down-runtime <project>` | Stop project runtime |
| `devhub doctor` | Health & network diagnostics |
| `devhub help` | Show help |

### Project Runtimes

```bash
# Start trading-app (PHP 8.4 + Node 20)
devhub runtime trading

# Start distribution-app v1 (PHP 8.2 + Node 20) - Legacy monolith
devhub runtime distribution-v1

# Start distribution-app v2 (PHP 8.2 + Bun + Reverb WebSocket)
devhub runtime distribution-v2
devhub runtime distribution-v2 --with worker  # with queue worker

# Stop runtimes
devhub down-runtime trading
devhub down-runtime distribution-v1
devhub down-runtime distribution-v2
```

### Service Ports

| Project | API | Web | WebSocket | Worker |
|---------|-----|-----|-----------|--------|
| trading | 8001 | 5174 | - | - |
| distribution-v1 | 8001 | 5174 | - | - |
| distribution-v2 | 8002 | 5175 | 8080 | profile: worker |

### Database Management

```bash
# Create a database for a project
devhub db create myapp

# Create with custom user/password
devhub db create myapp myuser mypassword

# List all databases
devhub db list

# Import tilvest DB dumps (trading + distribution) from pro/tilvest/data/
devhub db import [trading|distribution|all]
```

### Scripts Layout

| Path | Purpose |
|------|---------|
| `scripts/` | Generic infra (install, healthcheck, connect-project-network, create-project-db) |
| `scripts/tilvest/` | Tilvest pro scripts (trading + distribution) |

### How Overrides Work

`devhub runtime <project>` runs:

```bash
docker compose -f compose.yml -f overrides/<project>.override.yml up -d
```

- **compose.yml** = base infra (postgres, mysql, redis, etc.) + optional template services (frankenphp-81, frankenphp-82, node-20, node-22)
- **override.yml** = project-specific services that merge with compose (volumes, env, ports)

Override services either:
1. **Extend** a base service (same name) — override `volumes`, `environment`, `ports`, etc. (inherits `profiles` from compose.yml unless overridden)
2. **Add** new services (new name) — e.g. `php-84` + `trading-node` for trading-app (no profile = always started)

**Important**: New services in overrides should have no `profiles` so they start with `devhub runtime`. Extending a profiled service (e.g. frankenphp-82) keeps its profile — ensure `devhub up` or the runtime activates the needed profiles.

All project containers must join `dev-shared-net` to reach infra services (infra-mysql, infra-redis, etc.).

### Adding a New Project

1. **Create override** `overrides/myproject.override.yml`:

```yaml
services:
  myproject-php:
    image: dunglas/frankenphp:latest  # or custom build
    container_name: myproject-php
    volumes:
      - /path/to/your/project:/var/www/html
    working_dir: /var/www/html
    environment:
      - DATABASE_URL=mysql://test:test@infra-mysql:3306/myproject
      - REDIS_URL=redis://infra-redis:6379
    ports:
      - "8003:80"
    depends_on:
      mysql:
        condition: service_healthy
    networks:
      - dev-shared-net

  myproject-node:
    image: node:22-alpine
    container_name: myproject-node
    volumes:
      - /path/to/your/project:/app
      - /path/to/your/project/node_modules:/app/node_modules
    working_dir: /app
    command: npm run dev -- --host --port 5176
    environment:
      - VITE_APP_URL=http://localhost:8003
      - VITE_PORT=5176
    ports:
      - "5176:5176"
    networks:
      - dev-shared-net
```

2. **Register in devhub** — add case in `cmd_runtime` and `cmd_runtime_down`:

```bash
myproject)
  override_file="$DEVHUB_DIR/overrides/myproject-app.override.yml"
  ;;
```

3. **Optional**: add `scripts/myproject/` for import/export scripts if needed.

4. **Prerequisites**: Run `devhub up` first (core = postgres, mysql, redis, etc.). Then `devhub runtime myproject`.

### Open Service UIs

```bash
devhub open mailpit    # http://localhost:8025
devhub open adminer    # http://localhost:9080
devhub open dozzle     # http://localhost:8888
devhub open minio      # http://localhost:9001
devhub open rabbitmq   # http://localhost:15672
devhub open redis      # http://localhost:8081
devhub open meili      # http://localhost:7700
```

## Connect Your App

To connect your application containers to the shared network:

```bash
./scripts/connect-project-network.sh your-app-container
```

Or in your `docker-compose.yml`:

```yaml
networks:
  dev-shared-net:
    external: true
```

## Configuration

Copy `.env.example` to `.env` and customize:

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_USER` | `test` | PostgreSQL username |
| `POSTGRES_PASSWORD` | `test` | PostgreSQL password |
| `POSTGRES_DB` | `devhub` | Default database |
| `POSTGRES_PORT` | `5432` | PostgreSQL port |
| `REDIS_PORT` | `6379` | Redis port |
| `MEILI_MASTER_KEY` | `masterKey` | Meilisearch API key |
| `MINIO_ROOT_USER` | `minioadmin` | MinIO access key |
| `MINIO_ROOT_PASSWORD` | `minioadmin` | MinIO secret key |
| `RABBITMQ_DEFAULT_USER` | `guest` | RabbitMQ username |
| `RABBITMQ_DEFAULT_PASS` | `guest` | RabbitMQ password |

## Requirements

- Docker Engine 24+
- Docker Compose v2

## License

MIT
