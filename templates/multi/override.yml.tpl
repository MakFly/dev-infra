services:
  __PROJECT_NAME__-runtime:
    build:
      context: ./docker/__PROJECT_NAME__
      dockerfile: Dockerfile
    container_name: __PROJECT_CONTAINER__
    restart: unless-stopped
    user: "__DEVHUB_UID__:__DEVHUB_GID__"
    ports:
__PROJECT_PORTS_YAML__
    volumes:
      - __PROJECT_WORKTREES__:/worktrees:rw
      - ./docker/__PROJECT_NAME__/worktrees.ports:/devhub/worktrees.ports:ro
      - ./docker/__PROJECT_NAME__/start.sh:/devhub/start.sh:ro
      - __PROJECT_NAME__-bun-cache:/home/devhub/.bun
      - __PROJECT_NAME__-pip-cache:/home/devhub/.cache/pip
    environment:
      HOME: /home/devhub
      PROJECT_NAME: __PROJECT_NAME__
      PROJECT_RUNTIME_PORT: "__PROJECT_RUNTIME_PORT__"
      PROJECT_APPS: "__PROJECT_APPS__"
      DATABASE_URL: postgresql://test:test@infra-postgres:5432/devhub?serverVersion=16&charset=utf8
      REDIS_URL: redis://infra-redis:6379
      MAILER_DSN: smtp://infra-mailpit:1025
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
      mailpit:
        condition: service_healthy
    networks:
      - dev-shared-net

volumes:
  __PROJECT_NAME__-bun-cache:
  __PROJECT_NAME__-pip-cache:
