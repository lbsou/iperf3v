#!/bin/bash
# Builds the fork and the ESnet reference, then runs the network tests. Run as root.
#   Local: docker run --rm --privileged -v <repository path>:/src:ro \
#            debian:bookworm bash /src/iperf3v/tests/ci-linux.sh [test names]
#   CI: sudo bash iperf3v/tests/ci-linux.sh
set -euo pipefail
SRC=${GITHUB_WORKSPACE:-/src}

if ! command -v jq >/dev/null || ! command -v iptables >/dev/null || ! command -v gcc >/dev/null; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq build-essential libssl-dev iproute2 iptables jq git >/dev/null
fi
git config --global --add safe.directory '*'

rm -rf /tmp/w /tmp/ref /tmp/iperf3v-prebuilt
cp -a "$SRC" /tmp/w
cd /tmp/w
git clean -fdXq            # build artifacts of another platform (ignored files only)
if [ -n "${IPERF3V_PREBUILT:-}" ]; then
    # Test a packaged binary (the static release build) instead of building the fork here
    cp "$IPERF3V_PREBUILT" /tmp/iperf3v-prebuilt
    export IPERF3V=/tmp/iperf3v-prebuilt
else
    ./configure --disable-shared -q
    make -j"$(nproc)" -s >/dev/null
    export IPERF3V=/tmp/w/src/iperf3
fi
echo "fork binary: ${IPERF3V_PREBUILT:-built from the working tree}"

mkdir /tmp/ref
git archive "$(cat iperf3v/BASE_TAG)" | tar -x -C /tmp/ref
(cd /tmp/ref && ./configure --disable-shared -q && make -j"$(nproc)" -s >/dev/null)
export IPERF3_REF=/tmp/ref/src/iperf3

"$IPERF3V" --version | head -1
"$IPERF3_REF" --version | head -1
bash /tmp/w/iperf3v/tests/run_all.sh "$@"
