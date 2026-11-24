#!/bin/bash
# package-macos.sh <version>: builds iperf3v on macOS with Homebrew's OpenSSL
# linked statically and writes dist/iperf3v-<version>-macos-<arch>.tar.gz.
# Needs the Xcode command line tools and "brew install openssl@3".
# Run from the repository root. MACOS_MIN (default 15.0) is the oldest macOS
# the binary must run on: Homebrew's OpenSSL must not be built for a newer
# one, so build on a macOS MACOS_MIN machine.
set -euo pipefail
fail() { echo "FAIL  $*" >&2; exit 1; }
MACOS_MIN=${MACOS_MIN:-15.0}
export MACOSX_DEPLOYMENT_TARGET=$MACOS_MIN
# Highest "minos" (LC_BUILD_VERSION) among the Mach-O objects of a file
max_minos() {
    otool -l "$1" | awk '$1 == "minos" { split($2, v, "."); n = v[1] * 10000 + v[2] * 100 + v[3]; if (n > m) { m = n; s = $2 } } END { print s }'
}
# Succeeds when version $1 is newer than version $2
newer() {
    awk -v a="$1" -v b="$2" 'BEGIN { split(a, x, "."); split(b, y, "."); exit !(x[1] * 10000 + x[2] * 100 + x[3] > y[1] * 10000 + y[2] * 100 + y[3]) }'
}
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
for lib in libssl.a libcrypto.a; do
    m=$(max_minos "$stage/ossl/lib/$lib")
    [ -n "$m" ] || fail "no minimum macOS version found in $lib"
    ! newer "$m" "$MACOS_MIN" || fail "Homebrew's $lib is built for macOS $m, newer than $MACOS_MIN"
done

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
m=$(max_minos "$bin")
[ -n "$m" ] || fail "no minimum macOS version found in the binary"
! newer "$m" "$MACOS_MIN" || fail "the binary needs macOS $m, newer than $MACOS_MIN"
otool -L "$bin"
echo "minimum macOS: $m"

mkdir -p dist
tar -C "$stage" -czf "dist/$name.tar.gz" "$name"
echo "dist/$name.tar.gz"
