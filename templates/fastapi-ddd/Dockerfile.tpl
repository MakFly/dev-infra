FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash curl git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /worktrees

CMD ["bash", "/devhub/start.sh"]
