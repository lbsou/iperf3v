#!/bin/bash
# Loopback counterpart of test_throttle_cpu.sh (Cygwin, macOS, Linux): a
# rate-limited UDP sender must not spin once the elapsed time in seconds
# exceeds the packet size in bits (16-byte packets: about 128 s).
# Usage (repository root): iperf3v/tests/loopback_throttle.sh [binary]
set -u
B=${1:-}
if [ -z "$B" ]; then
    for B in src/.libs/iperf3.exe src/iperf3.exe src/iperf3; do [ -f "$B" ] && break; done
fi
PORT=5285
MEASURE_AT=${MEASURE_AT:-143}
WINDOW=10
MAX_PCT=5

# CPU time (user + system) of a process, in hundredths of a second:
# /proc on Linux and Cygwin, ps on macOS ("[[hh:]mm:]ss.cc").
cpu_cs() {
    if [ -z "${I3V_FORCE_PS:-}" ] && [ -r /proc/"$1"/stat ]; then
        awk -v hz="$(getconf CLK_TCK)" '{print int(($14 + $15) * 100 / hz)}' /proc/"$1"/stat
    else
        ps -o time= -p "$1" | awk '{n = split($1, a, ":"); s = 0; for (i = 1; i <= n; i++) s = s * 60 + a[i]; print int(s * 100 + 0.5)}'
    fi
}

"$B" -s -1 -p "$PORT" > /dev/null 2>&1 &
spid=$!
sleep 1
"$B" -c 127.0.0.1 -p "$PORT" -u -l 16 --udp-counters-64bit -b 10K -t $((MEASURE_AT + WINDOW + 5)) > /dev/null 2>&1 &
cpid=$!
sleep "$MEASURE_AT"
c0=$(cpu_cs "$cpid")
sleep "$WINDOW"
c1=$(cpu_cs "$cpid")
alive=yes
kill -0 "$cpid" 2>/dev/null || alive=no
kill "$cpid" "$spid" 2>/dev/null; wait 2>/dev/null

for c in "$c0" "$c1"; do
    case "$c" in ''|*[!0-9]*) echo "FAIL  no CPU measurement for the client (pid $cpid: '$c0' '$c1')"; exit 1;; esac
done
[ "$alive" = yes ] || { echo "FAIL  the client exited during the measurement"; exit 1; }
[ "$c1" -ge "$c0" ] || { echo "FAIL  CPU time went backwards ($c0 -> $c1)"; exit 1; }
pct=$(( (c1 - c0) / WINDOW ))
echo "client process at ${pct}% of a core after ${MEASURE_AT}s (threshold 128s)"
[ "$pct" -lt "$MAX_PCT" ]
