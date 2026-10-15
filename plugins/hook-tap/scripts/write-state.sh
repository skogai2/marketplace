#!/usr/bin/env bash
# Writes the repo's current state as diff files to .skogai/tmp/ at the git
# root, overwriting the previous ones:
#   git-diff         `git diff`: unstaged changes
#   git-diff-cached  `git diff --cached`: staged changes
#   wt-step-diff     `wt step diff`: everything since branching from the
#                    default branch, untracked files included
# The directory ignores itself, so staging never picks the files up.
# Usage: write-state.sh <root>
set -euo pipefail

root=$1
dir="$root/.skogai/tmp"
mkdir -p "$dir"
[[ -f $dir/.gitignore ]] || echo '*' >"$dir/.gitignore"

git -C "$root" diff >"$dir/git-diff"
git -C "$root" diff --cached >"$dir/git-diff-cached"
# Without wt, or outside a wt-managed repo, leave an empty file rather than
# fail the hook.
wt -C "$root" step diff >"$dir/wt-step-diff" 2>/dev/null || : >"$dir/wt-step-diff"
