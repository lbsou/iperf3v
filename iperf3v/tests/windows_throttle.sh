#!/bin/bash
# Windows/Cygwin counterpart of test_throttle_cpu.sh, on the loopback: a
# rate-limited UDP sender must not spin once the elapsed time in seconds
# exceeds the packet size in bits (16-byte packets: about 128 s).
# Usage (Cygwin, repository root): iperf3v/tests/windows_throttle.sh [binary]
set -u
B=${1:-src/.libs/iperf3.exe}
[ -f "$B" ] || B=src/iperf3.exe
PORT=5285
MEASURE_AT=143
WINDOW=10
MAX_PCT=5

"$B" -s -1 -p "$PORT" > /dev/null 2>&1 &
spid=$!
sleep 1
"$B" -c 127.0.0.1 -p "$PORT" -u -l 16 --udp-counters-64bit -b 10K -t $((MEASURE_AT + WINDOW + 5)) > /dev/null 2>&1 &
cpid=$!
sleep "$MEASURE_AT"
u0=$(awk '{print $14}' /proc/"$cpid"/stat)
sleep "$WINDOW"
u1=$(awk '{print $14}' /proc/"$cpid"/stat)
kill "$cpid" "$spid" 2>/dev/null; wait 2>/dev/null

hz=$(getconf CLK_TCK)
pct=$(( (u1 - u0) * 100 / (hz * WINDOW) ))
echo "client process at ${pct}% of a core after ${MEASURE_AT}s (threshold 128s)"
[ "$pct" -lt "$MAX_PCT" ]
