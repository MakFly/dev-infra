services:
  __PROJECT_NAME__-runtime:
    build:
      context: ./docker/__PROJECT_NAME__
      dockerfile: Dockerfile
      args:
        UID: ${HOST_UID:-1000}
        GID: ${HOST_GID:-1000}
    container_name: __PROJECT_CONTAINER__
    restart: unless-stopped
    ports:
      - "127.0.0.1:__PROJECT_RUNTIME_PORT__:__PROJECT_RUNTIME_PORT__"
      - "127.0.0.1:__PROJECT_PORT_START__-__PROJECT_PORT_END__:__PROJECT_PORT_START__-__PROJECT_PORT_END__"
    volumes:
      - __PROJECT_WORKTREES__:/worktrees:rw
      - ./docker/__PROJECT_NAME__/Caddyfile:/etc/frankenphp/Caddyfile:ro
      - ./docker/__PROJECT_NAME__/sites:/etc/frankenphp/sites:ro
      - __PROJECT_NAME__-composer-cache:/tmp/composer-cache
      - __PROJECT_NAME__-caddy-data:/data
      - __PROJECT_NAME__-caddy-config:/config
    environment:
      COMPOSER_HOME: /tmp/composer-cache
      XDG_DATA_HOME: /data
      XDG_CONFIG_HOME: /config
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
  __PROJECT_NAME__-composer-cache:
  __PROJECT_NAME__-caddy-data:
  __PROJECT_NAME__-caddy-config:
