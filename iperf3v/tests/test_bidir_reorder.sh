#!/bin/bash
# Bug 1: in UDP --bidir mode, a reverse-stream packet that arrives before the
# connect reply must not fail the test. netem jitter on the server reorders them.
set -u
. "$(dirname "$0")/netns.sh"

RUNS=20
ns_setup
netem_server delay 30ms 12ms

failures=0
for i in $(seq 1 "$RUNS"); do
    run_server "$IPERF3V" || exit 1
    run_client "$IPERF3V" -u -b 100K -l 218 -t 4 --bidir
    if [ "$RC" -ne 0 ]; then
        failures=$((failures + 1))
        echo "  run $i: rc=$RC $(jq -r '.error // empty' "$JSON" 2>/dev/null | head -1)"
    fi
done

if [ "$failures" -ne 0 ]; then
    echo "bidir reorder: $failures/$RUNS failed"
    exit 1
fi
echo "bidir reorder: 0/$RUNS failed"
