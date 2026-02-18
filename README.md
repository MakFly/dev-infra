# Docker Dev Hub (Shared Local Services)

Portable repo for a shared local Docker infrastructure across projects and machines.

Services:

- PostgreSQL (`infra-postgres`)
- Redis (`infra-redis`)
- Meilisearch (`infra-meilisearch`)
- Mailpit (`infra-mailpit`)
- Adminer (`infra-adminer`)
- Dozzle (`infra-dozzle`)
- MinIO (`minio`, profile `storage`)
- RabbitMQ (`infra-rabbitmq`, profile `async`)
- Redis Commander (`infra-redis-commander`, profile `debug`)

## Profiles

- `core`: postgres, redis, meili, mailpit, adminer, dozzle
- `storage`: minio
- `async`: rabbitmq
- `debug`: redis-commander

## Install (Linux/macOS)

```bash
git clone <YOUR_REPO_URL> dev-services
cd dev-services
./scripts/install.sh
source ~/.zshrc
```

The installer:

- symlinks `~/.local/bin/devhub` to `bin/devhub`
- installs aliases in `~/.config/devhub/devhub.zsh`
- creates `.env` from `.env.example` if missing

## Quick Start

```bash
devhub up
```

Default startup is `core + storage`.

Extra profiles:

```bash
devhub up --with async
devhub up --with debug
```

## Project DB

```bash
devhub db create iautos
devhub db list
```

## Connect an app container to shared network

```bash
./scripts/connect-project-network.sh iauto-webapp-dev
```

## Useful URLs

- Mailpit: <http://localhost:8025>
- Adminer: <http://localhost:9080>
- Dozzle: <http://localhost:8888>
- MinIO console: <http://localhost:9001>
- RabbitMQ UI: <http://localhost:15672>
- Redis Commander: <http://localhost:8081>
