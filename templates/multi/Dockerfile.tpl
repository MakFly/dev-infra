FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV HOME=/home/devhub

COPY --from=oven/bun:1 /usr/local/bin/bun /usr/local/bin/bun

# The container runs as the host user (compose `user:`) so files written into
# the mounted worktrees stay removable on the host; /home/devhub is world-
# writable to serve as HOME/cache dir for that arbitrary uid.
RUN ln -s /usr/local/bin/bun /usr/local/bin/bunx \
    && apt-get update \
    && apt-get install -y --no-install-recommends bash curl git \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /home/devhub/.bun /home/devhub/.cache/pip \
    && chmod -R 0777 /home/devhub

WORKDIR /worktrees

CMD ["bash", "/devhub/start.sh"]
