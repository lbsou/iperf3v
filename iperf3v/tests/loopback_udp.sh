#!/bin/bash
# Loopback test of the UDP server with one and several stream sockets.
# Windows hands every UDP datagram to the first socket bound to the port, so
# a Windows server with more than one stream socket needs iperf3v's shared
# receive socket; on Linux and macOS this checks the ESnet code path.
# Usage (repository root, Cygwin, macOS or Linux): iperf3v/tests/loopback_udp.sh [binary]
set -u
B=${1:-}
if [ -z "$B" ]; then
    for B in src/.libs/iperf3.exe src/iperf3.exe src/iperf3; do [ -f "$B" ] && break; done
fi
PORT=5287
failed=0

# timeout(1) is not part of macOS
run_limited() {
    local secs=$1; shift
    if command -v timeout >/dev/null; then timeout "$secs" "$@"
    else perl -e 'alarm shift; exec @ARGV or die "exec: $!"' "$secs" "$@"
    fi
}

case_lo() {
    local label="$*" srv_pid t0 t1 rc why= lost
    "$B" -s -1 -p "$PORT" > /tmp/i3v-lo-srv.log 2>&1 &
    srv_pid=$!
    sleep 1
    t0=$(date +%s)
    run_limited 40 "$B" -c 127.0.0.1 -p "$PORT" -J -u -b 1M -l 1200 -t 2 "$@" > /tmp/i3v-lo.json 2>/dev/null
    rc=$?
    t1=$(date +%s)
    kill "$srv_pid" 2>/dev/null; wait "$srv_pid" 2>/dev/null
    lost=$(grep -o '"lost_packets":[[:space:]]*[0-9]*' /tmp/i3v-lo.json | tail -1 | grep -o '[0-9]*$')
    if [ "$rc" -ne 0 ]; then why="rc=$rc $(grep -o '"error":[^,}]*' /tmp/i3v-lo.json | head -1)"
    elif [ $((t1 - t0)) -gt 12 ]; then why="took $((t1 - t0)) s"
    elif [ "${lost:-x}" != 0 ]; then why="lost_packets=${lost:-none}"
    fi
    if [ -n "$why" ]; then echo "FAIL  [$label] $why"; failed=1; else echo "ok    [$label] $((t1 - t0)) s"; fi
    sleep 1
}

case_lo
case_lo -R
case_lo -P 2
case_lo -R -P 2
case_lo --bidir
case_lo --bidir -P 2
case_lo -P 4
exit $failed
