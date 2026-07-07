services:
  __PROJECT_NAME__-runtime:
    build:
      context: ./docker/__PROJECT_NAME__
      dockerfile: Dockerfile
    container_name: __PROJECT_CONTAINER__
    restart: unless-stopped
    ports:
      - "127.0.0.1:__PROJECT_RUNTIME_PORT__:__PROJECT_RUNTIME_PORT__"
      - "127.0.0.1:__PROJECT_PORT_START__-__PROJECT_PORT_END__:__PROJECT_PORT_START__-__PROJECT_PORT_END__"
    volumes:
      - __PROJECT_WORKTREES__:/worktrees:rw
      - ./docker/__PROJECT_NAME__/worktrees.ports:/devhub/worktrees.ports:ro
      - ./docker/__PROJECT_NAME__/start.sh:/devhub/start.sh:ro
      - __PROJECT_NAME__-bun-cache:/root/.bun
    environment:
      PROJECT_NAME: __PROJECT_NAME__
      PROJECT_RUNTIME_PORT: "__PROJECT_RUNTIME_PORT__"
      PROJECT_DEV_COMMAND: __PROJECT_DEV_COMMAND__
      DATABASE_URL: postgresql://test:test@infra-postgres:5432/devhub?serverVersion=16&charset=utf8
      REDIS_URL: redis://infra-redis:6379
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - dev-shared-net

volumes:
  __PROJECT_NAME__-bun-cache:
