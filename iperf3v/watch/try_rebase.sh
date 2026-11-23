#!/bin/bash
# try_rebase.sh <new ESnet tag>: replays the iperf3v series (iperf3v/BASE_TAG..HEAD)
# on <new tag>, one commit at a time, in a temporary worktree, and prints a
# Markdown table: which patches apply and which conflict. Pushes nothing.
set -euo pipefail
new_tag=$1
root=$(git rev-parse --show-toplevel)
base=$(cat "$root/iperf3v/BASE_TAG")
work=$(mktemp -d)
git -C "$root" worktree add -q --detach "$work/tree" "$new_tag"
trap 'git -C "$root" worktree remove --force "$work/tree"; rm -rf "$work"' EXIT
cd "$work/tree"

echo "| commit | titre | résultat |"
echo "|---|---|---|"
ok=0; conflicts=0
for c in $(git -C "$root" rev-list --reverse --no-merges "$base..HEAD"); do
    title=$(git -C "$root" log -1 --format=%s "$c" | sed 's/|/\|/g')
    if git -c user.name=iperf3v-watch -c user.email=iperf3v-watch@invalid cherry-pick "$c" >/dev/null 2>&1; then
        echo "| \`$(git -C "$root" rev-parse --short "$c")\` | $title | ok |"
        ok=$((ok + 1))
    else
        files=$(git diff --name-only --diff-filter=U | tr '\n' ' ')
        git cherry-pick --abort >/dev/null 2>&1 || git reset -q --hard
        echo "| \`$(git -C "$root" rev-parse --short "$c")\` | $title | **conflit** : $files |"
        conflicts=$((conflicts + 1))
    fi
done
echo
echo "$ok patch(s) appliqué(s), $conflicts en conflit, sur \`$new_tag\` (série \`$base..HEAD\`)."
