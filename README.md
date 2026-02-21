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
| **MinIO** | `minio` | 9000, 9001 | http://localhost:9001 | S3-compatible storage |
| **RabbitMQ** | `infra-rabbitmq` | 5672, 15672 | http://localhost:15672 | Message broker |
| **Redis Commander** | `infra-redis-commander` | 8081 | http://localhost:8081 | Redis GUI |

## Profiles

| Profile | Services | Default |
|---------|----------|---------|
| `core` | postgres, redis, meilisearch, mailpit, adminer, dozzle | Yes |
| `storage` | minio | Yes |
| `async` | rabbitmq | No |
| `debug` | redis-commander | No |

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
| `devhub db list` | List all databases |
| `devhub doctor` | Health & network diagnostics |
| `devhub help` | Show help |

### Database Management

```bash
# Create a database for a project
devhub db create myapp

# Create with custom user/password
devhub db create myapp myuser mypassword

# List all databases
devhub db list
```

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
