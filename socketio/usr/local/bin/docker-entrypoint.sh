#!/bin/bash

MAX_WAIT_SECONDS="1"
RETRY_DURATION="1"
COMMON_CONFIG=$FRAPPE_BENCH_DIR/sites/common_site_config.json

function wait-for-common-config() {
    timeout $MAX_WAIT_SECONDS bash -c \
        "until [[ -f $COMMON_CONFIG ]]; do \
            sleep $RETRY_DURATION; \
        done;"
}

if [[ "$*" = "start" ]]; then
    wait-for-common-config && node "$FRAPPE_BENCH_DIR/apps/frappe/socketio.js"
else
    exec "$@"
fi
