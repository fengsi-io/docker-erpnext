#!/bin/bash
RETRY_DURATION="1"

function wait-for-upstream() {
    host=$(echo "$@" | cut -d: -f1)
    port=$(echo "$@" | cut -d: -f2)
    echo -ne "-> wait for upstream [$*]: "
    timeout "$MAX_WAIT_SECONDS" bash -c \
        "until printf '' 2>>/dev/null >>/dev/tcp/$host/$port; do \
            sleep $RETRY_DURATION; \
        done" && echo "done."
}

if wait-for-upstream "$FRAPPE_WEB_ENDPOINT" &&
    wait-for-upstream "$FRAPPE_SOCKETIO_ENDPOINT"; then
    exec "$@"
else
    result=$? && echo "timeout, now exit..." && exit $result
fi
