APP_ENV=dev
APP_DEBUG=1

APP_CACHE_PREFIX=__WORKTREE_REDIS_PREFIX__

DATABASE_URL=postgresql://__WORKTREE_DB_USER__:__WORKTREE_DB_PASSWORD__@infra-postgres:5432/__WORKTREE_DB__?serverVersion=16&charset=utf8
REDIS_URL=redis://infra-redis:6379/0
MESSENGER_TRANSPORT_DSN=redis://infra-redis:6379/messages___WORKTREE_REDIS_PREFIX__
MAILER_DSN=smtp://infra-mailpit:1025
MEILISEARCH_URL=http://infra-meilisearch:7700
MEILISEARCH_API_KEY=masterKey
