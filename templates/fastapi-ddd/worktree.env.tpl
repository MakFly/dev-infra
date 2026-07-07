APP_ENV=dev
APP_DEBUG=1
APP_URL=http://localhost:__WORKTREE_PORT__

DATABASE_URL=postgresql://__WORKTREE_DB_USER__:__WORKTREE_DB_PASSWORD__@infra-postgres:5432/__WORKTREE_DB__
REDIS_URL=redis://infra-redis:6379/0
MAILER_DSN=smtp://infra-mailpit:1025
