#!/bin/bash
# A connect reply that is slow but not lost (round trip above the resend
# interval) must not disturb the test: no resend may reach an ESnet server's
# data path, where it would be glued to the first data packet and corrupt the
# loss and ordering counters. 600 ms each way: 1.2 s round trip.
set -u
. "$(dirname "$0")/netns.sh"

failed=0
ns_setup
netem_server delay 600ms
netem_client delay 600ms

# case_slow <client_bin> <server_bin> <args...>
case_slow() {
    local cbin=$1 sbin=$2; shift 2
    local label
    label="$(basename "$(dirname "$(dirname "$cbin")")")->$(basename "$(dirname "$(dirname "$sbin")")") $*"
    run_server "$sbin" || { echo "FAIL  $label: server"; failed=1; return; }
    run_client "$cbin" -u -b 100K -l 218 -t 4 "$@"
    local lost ooo why=
    # .end.sum holds the receiver's counters (from the server in -u mode)
    lost=$(jq -r '(.end.sum.lost_packets // 0) + (.end.sum_bidir_reverse.lost_packets // 0)' "$JSON" 2>/dev/null)
    ooo=$(jq -r '[.end.streams[].udp.out_of_order // 0] | add // 0' "$JSON" 2>/dev/null)
    if [ "$RC" -ne 0 ]; then
        why="rc=$RC $(jq -r '.error // empty' "$JSON" 2>/dev/null | head -1)"
    elif [ "$lost" != 0 ] || [ "$ooo" != 0 ]; then
        why="lost_packets=$lost out_of_order=$ooo"
    fi
    if [ -n "$why" ]; then echo "FAIL  $label: $why"; failed=1; else echo "ok    $label"; fi
}

case_slow "$IPERF3_REF" "$IPERF3_REF"          # baseline: stock against stock
case_slow "$IPERF3V" "$IPERF3_REF"
case_slow "$IPERF3V" "$IPERF3_REF" --bidir
case_slow "$IPERF3V" "$IPERF3V"
exit $failed
