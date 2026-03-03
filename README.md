# DevHub - Shared Local Infrastructure

A portable Docker Compose setup for shared local development services across multiple projects and machines.

## Services

| Service | Container | Port(s) | UI URL | Purpose |
|---------|-----------|---------|--------|---------|
| **PostgreSQL** | `infra-postgres` | 5432 | - | Relational database |
| **MySQL** | `infra-mysql` | 3306 | - | Relational database |
| **Redis** | `infra-redis` | 6379 | - | Cache & sessions |
| **Meilisearch** | `infra-meilisearch` | 7700 | http://localhost:7700 | Search engine |
| **Mailpit** | `infra-mailpit` | 1025, 8025 | http://localhost:8025 | Email testing (SMTP + UI) |
| **Adminer** | `infra-adminer` | 9080 | http://localhost:9080 | Database management |
| **Dozzle** | `infra-dozzle` | 8888 | http://localhost:8888 | Container logs viewer |
| **RabbitMQ** | `infra-rabbitmq` | 5672, 15672 | http://localhost:15672 | Message broker |
| **MinIO** | `minio` | 9000, 9001 | http://localhost:9001 | S3-compatible storage (ARCHIVED) |

## Profiles

| Profile | Services | Default |
|---------|----------|---------|
| `core` | postgres, mysql, redis, meilisearch, mailpit, adminer, dozzle | Yes |
| `storage` | minio | Yes (archived) |
| `async` | rabbitmq | No |
| `php81` | frankenphp-81 | No |
| `php82` | frankenphp-82 | No |
| `node` | node-20 | No |
| `node22` | node-22 | No |

## Installation

```bash
git clone <YOUR_REPO_URL> dev-infra
cd dev-infra
cp .env.example .env
# Edit .env as needed
```

## Quick Start

```bash
# Start default services (core + storage)
devhub up

# Add extra profiles
devhub up --with async      # RabbitMQ
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
| `devhub runtime <project>` | Start project runtime |
| `devhub down-runtime <project>` | Stop project runtime |
| `devhub doctor` | Health & network diagnostics |
| `devhub help` | Show help |

### Open Service UIs

```bash
devhub open mailpit    # http://localhost:8025
devhub open adminer    # http://localhost:9080
devhub open dozzle     # http://localhost:8888
devhub open minio      # http://localhost:9001
devhub open rabbitmq   # http://localhost:15672
devhub open meili      # http://localhost:7700
```

### Database Management

```bash
# Create a database
devhub db create myapp

# Create with custom user/password
devhub db create myapp myuser mypassword

# List all databases
devhub db list
```

## Project Overrides

Place your project-specific Docker Compose overrides in `overrides/<project>-app.override.yml`.

```bash
# Start a project
devhub runtime myproject

# Stop a project
devhub down-runtime myproject
```

### Example Override

`overrides/myproject-app.override.yml`:

```yaml
services:
  myproject-php:
    image: dunglas/frankenphp:latest
    container_name: myproject-php
    volumes:
      - /path/to/project:/var/www/html
    working_dir: /var/www/html
    environment:
      - DATABASE_URL=postgres://test:test@infra-postgres:5432/myproject
    ports:
      - "8003:80"
    networks:
      - dev-shared-net
```

All project containers must join `dev-shared-net` to reach infra services.

## Connect Your App

```yaml
# In your docker-compose.yml
networks:
  dev-shared-net:
    external: true
```

## Configuration

Copy `.env.example` to `.env` and customize ports/credentials.

## Requirements

- Docker Engine 24+
- Docker Compose v2

## License

MIT
