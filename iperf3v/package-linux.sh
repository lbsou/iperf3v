#!/bin/bash
# package-linux.sh <version>: builds iperf3v (static libiperf) and writes
# dist/iperf3v-<version>-linux-x86_64.tar.gz. Run from the repository root.
set -euo pipefail
v=$1
name=iperf3v-$v-linux-x86_64
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT

./configure -q --disable-shared --prefix=/opt/iperf3v --program-transform-name='s/^iperf3$/iperf3v/'
make -j"$(nproc)" -s >/dev/null
make -s install DESTDIR="$stage/root" >/dev/null

out=$stage/$name
mkdir -p "$out/bin" "$out/share/man/man1"
cp "$stage/root/opt/iperf3v/bin/iperf3v" "$out/bin/"
cp "$stage/root/opt/iperf3v/share/man/man1/iperf3v.1" "$out/share/man/man1/"
cp LICENSE PATCHLOG README-iperf3v.md "$out/"

got=$("$out/bin/iperf3v" --version | head -1 | awk '{print $2}')
[ "$got" = "$v" ] || { echo "version mismatch: binary says $got, expected $v" >&2; exit 1; }
if ldd "$out/bin/iperf3v" | grep -q libiperf; then echo "libiperf is not static" >&2; exit 1; fi

mkdir -p dist
tar -C "$stage" -czf "dist/$name.tar.gz" "$name"
echo "dist/$name.tar.gz"
