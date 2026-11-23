#!/bin/bash
# package-cygwin.sh <version>: builds iperf3v under Cygwin and writes
# dist/iperf3v-<version>-windows-x86_64.zip (iperf3v.exe + the Cygwin DLLs it needs).
# Run from the repository root in a Cygwin shell.
set -euo pipefail
v=$1
name=iperf3v-$v-windows-x86_64
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT

./configure --with-openssl=/usr > "$stage/configure.log"
grep -q 'TCP_KEEPIDLE socket option... yes' "$stage/configure.log" || { echo "TCP_KEEPIDLE check failed: --cntl-ka missing" >&2; exit 1; }
make -j4 -s >/dev/null
bin=src/.libs/iperf3.exe; [ -f "$bin" ] || bin=src/iperf3.exe

# Check before copying the DLLs: a second cygwin1.dll next to the exe clashes with this Cygwin session
got=$("$bin" --version | head -1 | awk '{print $2}')
[ "$got" = "$v" ] || { echo "version mismatch: binary says $got, expected $v" >&2; exit 1; }

out=$stage/$name
mkdir -p "$out"
cp "$bin" "$out/iperf3v.exe"
for dll in $(ldd "$out/iperf3v.exe" | awk '$3 ~ /^\/usr\/bin\// {print $3}'); do cp "$dll" "$out/"; done
cp LICENSE PATCHLOG README-iperf3v.md "$out/"


mkdir -p dist
rm -f "dist/$name.zip"
# Windows' own tar.exe (bsdtar) writes zip archives
/cygdrive/c/Windows/System32/tar.exe -a -c -f "$(cygpath -w "$PWD/dist/$name.zip")" -C "$(cygpath -w "$stage")" "$name"
echo "dist/$name.zip"
