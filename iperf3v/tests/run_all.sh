#!/bin/bash
# Runs every iperf3v/tests/test_*.sh (or the ones named on the command line).
# Needs IPERF3V (fork binary) and IPERF3_REF (ESnet binary of iperf3v/BASE_TAG).
set -u
here=$(cd "$(dirname "$0")" && pwd)
: "${IPERF3V:?IPERF3V not set}" "${IPERF3_REF:?IPERF3_REF not set}"
export IPERF3V IPERF3_REF

if [ $# -gt 0 ]; then tests=("$@"); else tests=("$here"/test_*.sh); fi
failed=0
for t in "${tests[@]}"; do
    [ -f "$t" ] || t="$here/$t"
    name=$(basename "$t" .sh)
    echo "=== $name"
    if bash "$t"; then echo "PASS $name"; else echo "FAIL $name"; failed=1; fi
done
exit $failed
