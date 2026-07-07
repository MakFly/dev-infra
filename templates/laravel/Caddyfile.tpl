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
    respond "DevHub runtime OK: __PROJECT_NAME__\nUse: devhub wt list __PROJECT_NAME__\n" 200
}

import /etc/frankenphp/sites/*.caddy
