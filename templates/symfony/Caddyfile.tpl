{
    admin off
    auto_https off

    frankenphp {
        num_threads 4
        max_threads 8
        max_wait_time 30s
        max_idle_time 10s
        max_requests 500
    }
}

http://localhost:__PROJECT_RUNTIME_PORT__ {
    respond <<HTML
DevHub runtime OK: __PROJECT_NAME__

Worktrees are served on localhost ports __PROJECT_PORT_START__-__PROJECT_PORT_END__.

Use:
  devhub wt list __PROJECT_NAME__
HTML 200
}

import /etc/frankenphp/sites/*.caddy
