#!/bin/bash
# Bug 2: a lost UDP connect reply must not block the client for 30 s.
# Each case drops the n-th connect reply sent by the server (or none), then
# checks that the test succeeds quickly and that no 4-byte control datagram
# was counted as data (received bytes stay a multiple of the block size).
set -u
. "$(dirname "$0")/netns.sh"

BLK=218
LIMIT_MS=9000     # -t 3 plus setup and one or two 1 s resends
failed=0

# case_loss <client_bin> <server_bin> <drop_index|none> <args...>
case_loss() {
    local cbin=$1 sbin=$2 drop=$3; shift 3
    local label
    label="$(basename "$(dirname "$(dirname "$cbin")")")->$(basename "$(dirname "$(dirname "$sbin")")") drop=$drop $*"
    ns_setup
    [ "$drop" = none ] || drop_nth_reply "$drop"
    run_server "$sbin" || { echo "FAIL  $label: server"; failed=1; return; }
    run_client "$cbin" -u -b 100K -l "$BLK" -t 3 "$@"

    local sum=sum_received bytes why=
    case " $* " in *" --bidir "*) sum=sum_received_bidir_reverse ;; esac
    bytes=$(jq -r ".end.$sum.bytes // \"none\"" "$JSON" 2>/dev/null)
    if [ "$RC" -ne 0 ]; then
        why="rc=$RC $(jq -r '.error // empty' "$JSON" 2>/dev/null | head -1)"
    elif [ "$ELAPSED_MS" -gt "$LIMIT_MS" ]; then
        why="took ${ELAPSED_MS} ms"
    elif [ "$bytes" = none ] || [ $((bytes % BLK)) -ne 0 ]; then
        why="$sum.bytes=$bytes not a multiple of $BLK"
    fi
    if [ -n "$why" ]; then echo "FAIL  $label: $why"; failed=1; else echo "ok    $label (${ELAPSED_MS} ms)"; fi
}

OWN=$IPERF3V
REF=$IPERF3_REF

# Client-side recovery: works against an ESnet server too.
for srv in "$OWN" "$REF"; do
    case_loss "$OWN" "$srv" 0 -R
    case_loss "$OWN" "$srv" 1 -R -P 2
    case_loss "$OWN" "$srv" 1 --bidir
done

# The server answers a repeated connect on a running receive stream.
case_loss "$OWN" "$OWN" 0
case_loss "$OWN" "$OWN" 1 -P 2
case_loss "$OWN" "$OWN" 0 --skip-rx-copy

# Interoperability without loss.
for mode in "" "-R" "--bidir"; do
    # shellcheck disable=SC2086
    case_loss "$REF" "$OWN" none $mode
    # shellcheck disable=SC2086
    case_loss "$OWN" "$REF" none $mode
done

# The server answers a repeated connect while it still creates streams (task 5).
if [ "${WITH_SERVER_FIX:-0}" = 1 ]; then
    case_loss "$OWN" "$OWN" 0 -P 2
    case_loss "$OWN" "$OWN" 0 -R -P 2
    case_loss "$OWN" "$OWN" 0 --bidir
fi

exit $failed
