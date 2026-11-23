# shellcheck shell=bash
# iperf3v network test library: two network namespaces joined by a veth pair.
# Server namespace i3v-s (10.203.0.1), client namespace i3v-c (10.203.0.2).
# Needs root, iproute2, tc (netem), iptables. Source it from a test script.

NS_S=i3v-s
NS_C=i3v-c
SRV_IP=10.203.0.1
CLI_IP=10.203.0.2
PORT=5201
SRV_PID=
SRV_LOG=

ns_teardown() {
    stop_server
    ip netns del "$NS_S" 2>/dev/null || true
    ip netns del "$NS_C" 2>/dev/null || true
}

ns_setup() {
    ns_teardown
    ip netns add "$NS_S"
    ip netns add "$NS_C"
    ip link add i3v-vs type veth peer name i3v-vc
    ip link set i3v-vs netns "$NS_S"
    ip link set i3v-vc netns "$NS_C"
    ip -n "$NS_S" addr add "$SRV_IP/24" dev i3v-vs
    ip -n "$NS_C" addr add "$CLI_IP/24" dev i3v-vc
    ip -n "$NS_S" link set lo up
    ip -n "$NS_C" link set lo up
    ip -n "$NS_S" link set i3v-vs up
    ip -n "$NS_C" link set i3v-vc up
    trap ns_teardown EXIT
}

# netem on the server egress: the connect reply and the reverse stream share it.
netem_server() {
    ip netns exec "$NS_S" tc qdisc replace dev i3v-vs root netem "$@"
}

# Drop the (n+1)-th UDP connect reply sent by the server (n counts from 0).
# A connect reply is a 4-byte UDP payload: 32-byte IPv4 packet.
drop_nth_reply() {
    ip netns exec "$NS_S" iptables -A OUTPUT -p udp --sport "$PORT" \
        -m length --length 32 \
        -m statistic --mode nth --every 1000000 --packet "$1" -j DROP
}

# run_server <binary> [extra args]: one-off server in the background, waits until it listens.
run_server() {
    local bin=$1; shift
    stop_server
    SRV_LOG=$(mktemp)
    ip netns exec "$NS_S" "$bin" -s -1 -p "$PORT" "$@" >"$SRV_LOG" 2>&1 &
    SRV_PID=$!
    local i
    for i in $(seq 1 50); do
        ip netns exec "$NS_S" ss -ltn 2>/dev/null | grep -q ":$PORT " && return 0
        sleep 0.1
    done
    echo "server did not start: $(cat "$SRV_LOG")" >&2
    return 1
}

stop_server() {
    if [ -n "$SRV_PID" ]; then
        kill "$SRV_PID" 2>/dev/null || true
        wait "$SRV_PID" 2>/dev/null || true
        SRV_PID=
    fi
}

# run_client <binary> <args...>: sets RC (exit code), ELAPSED_MS, JSON (path of the -J output).
run_client() {
    local bin=$1; shift
    JSON=$(mktemp)
    local t0 t1
    t0=$(date +%s%N)
    ip netns exec "$NS_C" timeout 25 "$bin" -c "$SRV_IP" -p "$PORT" -J "$@" >"$JSON" 2>"$JSON.err"
    RC=$?
    t1=$(date +%s%N)
    ELAPSED_MS=$(( (t1 - t0) / 1000000 ))
    # let a one-off server finish before the next test
    local i
    for i in $(seq 1 30); do
        kill -0 "$SRV_PID" 2>/dev/null || break
        sleep 0.1
    done
    stop_server
}
