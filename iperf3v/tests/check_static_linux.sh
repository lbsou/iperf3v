#!/bin/bash
# check_static_linux.sh <tarball>: the Linux package must hold one fully
# static iperf3v (no shared library, no program interpreter) with --cntl-ka
# and OpenSSL authentication, plus its documents. With Docker, also runs it
# alone in a FROM scratch image. Needs readelf (binutils).
set -euo pipefail
fail() { echo "FAIL  $*" >&2; exit 1; }
tgz=$1
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
tar -xzf "$tgz" -C "$tmp"
dir=$(find "$tmp" -mindepth 1 -maxdepth 1 -type d)
bin=$dir/bin/iperf3v
[ -x "$bin" ] || fail "no bin/iperf3v in $tgz"

command -v readelf >/dev/null || fail "readelf not found (install binutils)"
dyn=$(readelf -dW "$bin") || fail "readelf cannot read $bin (not an ELF file?)"
hdr=$(readelf -lW "$bin") || fail "readelf cannot read the program headers of $bin"
case "$hdr" in *LOAD*) ;; *) fail "no loadable segment in $bin (not an executable?)";; esac
needed=$(printf '%s\n' "$dyn" | grep NEEDED || true)
[ -z "$needed" ] || fail "shared libraries needed:
$needed"
case "$hdr" in *INTERP*) fail "has a program interpreter (dynamic loader)";; esac
"$bin" --help | grep -q -- --cntl-ka || fail "--cntl-ka missing"
"$bin" --version | grep -q authentication || fail "built without OpenSSL authentication"
for f in LICENSE PATCHLOG README-iperf3v.md share/man/man1/iperf3v.1; do
    [ -f "$dir/$f" ] || fail "$f missing"
done

if command -v docker >/dev/null && docker info >/dev/null 2>&1; then
    cp "$bin" "$tmp/iperf3v"
    printf 'FROM scratch\nCOPY iperf3v /iperf3v\nENTRYPOINT ["/iperf3v"]\n' > "$tmp/Dockerfile"
    tag=iperf3v-static-check:$$
    docker build -q -t "$tag" -f "$tmp/Dockerfile" "$tmp" >/dev/null
    out=$(docker run --rm "$tag" --version | head -1)
    docker rmi -f "$tag" >/dev/null
    [ -n "$out" ] || fail "does not run in a FROM scratch image"
    echo "ok    FROM scratch: $out"
else
    echo "skip  FROM scratch run (no Docker)"
fi
echo "ok    $(basename "$tgz") is fully static"
