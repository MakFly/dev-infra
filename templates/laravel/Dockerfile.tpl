FROM dunglas/frankenphp:1-php8.4-bookworm

ARG UID=1000
ARG GID=1000

ENV COMPOSER_HOME=/tmp/composer-cache
ENV XDG_DATA_HOME=/data
ENV XDG_CONFIG_HOME=/config

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        curl \
        git \
        make \
        postgresql-client \
        unzip \
    && rm -rf /var/lib/apt/lists/*

RUN install-php-extensions \
    @composer \
    bcmath \
    gd \
    intl \
    opcache \
    pcntl \
    pdo_pgsql \
    redis \
    zip

RUN groupadd -g "${GID}" app \
    && useradd -m -u "${UID}" -g app app \
    && mkdir -p /data /config /tmp/composer-cache /worktrees \
    && chown -R app:app /data /config /tmp/composer-cache /worktrees

COPY dev.ini /usr/local/etc/php/conf.d/99-devhub-dev.ini

USER app
WORKDIR /worktrees

CMD ["frankenphp", "run", "--config", "/etc/frankenphp/Caddyfile"]
