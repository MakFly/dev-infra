http://localhost:__WORKTREE_PORT__ {
    encode zstd br gzip

    root * /worktrees/__WORKTREE_SLUG__/public

    php_server

    log {
        output stdout
        format console
    }
}
