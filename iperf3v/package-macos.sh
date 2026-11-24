#!/bin/bash
# package-macos.sh <version>: builds iperf3v on macOS with Homebrew's OpenSSL
# linked statically and writes dist/iperf3v-<version>-macos-<arch>.tar.gz.
# Needs the Xcode command line tools and "brew install openssl@3".
# Run from the repository root.
set -euo pipefail
fail() { echo "FAIL  $*" >&2; exit 1; }
v=$1
arch=$(uname -m)
name=iperf3v-$v-macos-$arch
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT

# A directory with only the static OpenSSL libraries, so that -lssl -lcrypto
# cannot pick Homebrew's dylibs (the binary must not need Homebrew).
ossl=$(brew --prefix openssl@3)
mkdir -p "$stage/ossl/lib"
ln -s "$ossl/include" "$stage/ossl/include"
cp "$ossl/lib/libssl.a" "$ossl/lib/libcrypto.a" "$stage/ossl/lib/"

./configure -q --disable-shared --with-openssl="$stage/ossl" --prefix=/opt/iperf3v \
    --program-transform-name='s/^iperf3$/iperf3v/'
grep -q '^#define HAVE_TCP_KEEPALIVE 1' src/iperf_config.h || fail "TCP_KEEPIDLE check failed: --cntl-ka missing"
make -j"$(sysctl -n hw.ncpu)" -s >/dev/null
make -s install DESTDIR="$stage/root" >/dev/null

out=$stage/$name
mkdir -p "$out/bin" "$out/share/man/man1"
bin=$out/bin/iperf3v
strip -o "$bin" "$stage/root/opt/iperf3v/bin/iperf3v"
codesign -s - -f "$bin" 2>/dev/null    # strip may drop the ad hoc signature arm64 requires
cp "$stage/root/opt/iperf3v/share/man/man1/iperf3v.1" "$out/share/man/man1/"
cp LICENSE PATCHLOG README-iperf3v.md "$out/"

foreign=$(otool -L "$bin" | tail -n +2 | awk '{print $1}' | grep -v -E '^/usr/lib/|^/System/' || true)
[ -z "$foreign" ] || fail "links libraries outside the system:
$foreign"
got=$("$bin" --version | head -1 | awk '{print $2}')
[ "$got" = "$v" ] || fail "version mismatch: binary says $got, expected $v"
"$bin" --help | grep -q -- --cntl-ka || fail "--cntl-ka missing"
"$bin" --version | grep -q authentication || fail "built without OpenSSL authentication"
otool -L "$bin"

mkdir -p dist
tar -C "$stage" -czf "dist/$name.tar.gz" "$name"
echo "dist/$name.tar.gz"
