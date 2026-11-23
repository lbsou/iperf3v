#!/bin/bash
# A rate-limited UDP sender must keep sleeping between packets for the whole
# test. iperf_check_throttle() computed the average rate since the start in
# whole bits per second: once the elapsed time in seconds exceeds the packet
# size in bits, one packet no longer moves that average, missing_rate stays at
# 0 and the sender thread spun at 100 % of a core. 16-byte packets (128 bits,
# the minimum with 64-bit counters) bring the threshold down to about 128 s.
set -u
. "$(dirname "$0")/netns.sh"

THRESHOLD_S=128
MEASURE_AT=$((THRESHOLD_S + 15))   # well past the threshold
WINDOW=10
MAX_PCT=5

ns_setup
run_server "$IPERF3V" || exit 1
ip netns exec "$NS_C" "$IPERF3V" -c "$SRV_IP" -p "$PORT" -u -l 16 --udp-counters-64bit -b 10K \
    -t $((MEASURE_AT + WINDOW + 5)) > /dev/null 2>&1 &
cpid=$!
sleep "$MEASURE_AT"

# utime (clock ticks) of every thread of the client
utimes() { for t in /proc/"$cpid"/task/*; do awk '{print FILENAME, $14}' "$t/stat" 2>/dev/null; done; }
before=$(utimes)
sleep "$WINDOW"
after=$(utimes)
kill "$cpid" 2>/dev/null; wait "$cpid" 2>/dev/null
stop_server

hz=$(getconf CLK_TCK)
# the busiest thread over the window, in percent of one core
pct=$(join <(echo "$before" | sort) <(echo "$after" | sort) |
      awk -v hz="$hz" -v w="$WINDOW" '{d = ($3 - $2) / (hz * w) * 100; if (d > m) m = d} END {printf "%d", m}')
if [ -z "$pct" ]; then echo "no client thread measured"; exit 1; fi
if [ "$pct" -ge "$MAX_PCT" ]; then
    echo "sender thread at ${pct}% of a core after ${MEASURE_AT}s (threshold ${THRESHOLD_S}s)"
    exit 1
fi
echo "sender thread at ${pct}% of a core after ${MEASURE_AT}s (threshold ${THRESHOLD_S}s)"
