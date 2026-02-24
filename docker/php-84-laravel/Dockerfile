FROM php:8.4-cli

RUN apt-get update && apt-get install -y --no-install-recommends \
    default-libmysqlclient-dev \
    && docker-php-ext-install pdo_mysql \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
