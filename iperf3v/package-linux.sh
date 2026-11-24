#!/bin/bash
# package-linux.sh <version>: builds a fully static iperf3v (musl, static
# OpenSSL) and writes dist/iperf3v-<version>-linux-<arch>.tar.gz. Run from the
# repository root on Alpine Linux, for instance:
#   docker run --rm -v "$PWD":/src -w /src alpine:3.22 \
#       sh -c 'apk add -q bash && bash iperf3v/package-linux.sh <version>'
set -euo pipefail
v=$1
[ -f /etc/alpine-release ] || { echo "run this on Alpine Linux (musl), see the header" >&2; exit 1; }
apk add -q build-base openssl-dev openssl-libs-static linux-headers binutils >/dev/null
arch=$(uname -m)
name=iperf3v-$v-linux-$arch
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT

./configure -q --enable-static-bin --prefix=/opt/iperf3v --program-transform-name='s/^iperf3$/iperf3v/'
grep -q '^#define HAVE_TCP_KEEPALIVE 1' src/iperf_config.h || { echo "TCP_KEEPIDLE check failed: --cntl-ka missing" >&2; exit 1; }
make -j"$(nproc)" -s >/dev/null
make -s install DESTDIR="$stage/root" >/dev/null

out=$stage/$name
mkdir -p "$out/bin" "$out/share/man/man1"
strip -o "$out/bin/iperf3v" "$stage/root/opt/iperf3v/bin/iperf3v"
cp "$stage/root/opt/iperf3v/share/man/man1/iperf3v.1" "$out/share/man/man1/"
cp LICENSE PATCHLOG README-iperf3v.md "$out/"

got=$("$out/bin/iperf3v" --version | head -1 | awk '{print $2}')
[ "$got" = "$v" ] || { echo "version mismatch: binary says $got, expected $v" >&2; exit 1; }

mkdir -p dist
tar -C "$stage" -czf "dist/$name.tar.gz" "$name"
echo "dist/$name.tar.gz"
