#!/bin/bash
# Checks that the "fix:" commits of the series apply alone, in order, on the
# ESnet base tag (iperf3v/BASE_TAG) and that the result builds. Run from the
# repository root; works on a copy so the working tree is never touched.
set -euo pipefail
root=$(git rev-parse --show-toplevel)
base=$(cat "$root/iperf3v/BASE_TAG")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

git -C "$root" worktree add -q --detach "$work/tree" "$base"
trap 'git -C "$root" worktree remove --force "$work/tree"; rm -rf "$work"' EXIT
cd "$work/tree"

fixes=$(git -C "$root" log --reverse --format='%H %s' "$base..HEAD" | awk '$2 == "fix:" {print $1}')
[ -n "$fixes" ] || { echo "no fix: commit"; exit 0; }
for c in $fixes; do
    if ! git -c user.name=iperf3v-check -c user.email=iperf3v-check@invalid cherry-pick -x "$c" >/dev/null 2>&1; then
        echo "FAIL: $(git -C "$root" log -1 --format='%h %s' "$c") does not apply on $base"
        exit 1
    fi
    echo "ok    $(git -C "$root" log -1 --format='%h %s' "$c")"
done
./configure -q >/dev/null && make -j"$(nproc 2>/dev/null || echo 4)" -s >/dev/null
echo "fix: commits apply on $base and build"
