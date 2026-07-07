FROM oven/bun:1

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash curl git python3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /worktrees

CMD ["bash", "/devhub/start.sh"]
