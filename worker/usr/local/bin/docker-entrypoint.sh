#!/bin/bash

case "$1" in
"serve")
    # if volume is first mount
    chown --from=root:root -R frappe:frappe "$FRAPPE_BENCH_DIR/sites" &&
        su frappe --command "bench-serve"
    ;;
"schedule")
    su frappe --command "bench-schedule"
    ;;
"worker")
    su frappe --command "bench-worker $2"
    ;;
*)
    exec "$@"
    ;;
esac
