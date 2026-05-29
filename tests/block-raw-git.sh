#!/bin/bash
# Regression tests for the stg raw-git guard hook.

set -u

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
HOOK="$REPO_ROOT/plugin/cel-kdev/hooks/block-raw-git.sh"

TMPDIR=$(mktemp -d /tmp/cel-kdev-hook-test.XXXXXX)
trap 'rm -rf "$TMPDIR"' EXIT

failures=0

setup_repo() {
    local dir=$1
    local with_stack=$2

    mkdir -p "$dir"
    cd "$dir" || exit 1

    git init -q
    git config user.email test@example.com
    git config user.name "Test User"
    git commit --allow-empty -q -m init

    if [ "$with_stack" = yes ]; then
        local branch
        branch=$(git branch --show-current)
        git update-ref "refs/stacks/$branch" HEAD
    fi
}

run_hook() {
    local command=$1

    printf '{"tool_input":{"command":%s}}\n' "$(printf '%s' "$command" | jq -Rs .)" |
        "$HOOK" >/tmp/cel-kdev-hook-stdout.txt 2>/tmp/cel-kdev-hook-stderr.txt
}

expect_blocked() {
    local command=$1

    run_hook "$command"
    local status=$?
    if [ "$status" -ne 2 ]; then
        echo "FAIL: expected block for: $command (status $status)"
        failures=$((failures + 1))
    fi
}

expect_allowed() {
    local command=$1

    run_hook "$command"
    local status=$?
    if [ "$status" -ne 0 ]; then
        echo "FAIL: expected allow for: $command (status $status)"
        failures=$((failures + 1))
    fi
}

setup_repo "$TMPDIR/active" yes

expect_blocked "git commit -m update"
expect_blocked "git commit --amend"
expect_blocked "git rebase origin/master"
expect_blocked "git reset --hard"
expect_blocked "git cherry-pick abc123"
expect_blocked "git branch -d topic"
expect_blocked "git switch topic"
expect_blocked "git checkout topic"
expect_blocked "git worktree add ../topic topic"
expect_blocked "git merge topic"
expect_blocked "git merge --no-ff b1 b2 b3"

# A plumbing word must not whitelist a real prohibited subcommand
# chained on the same line.
expect_blocked "git merge-base master topic; git merge topic"
expect_blocked "git merge-tree --write-tree base topic && git merge topic"

expect_allowed "git branch"
expect_allowed "git branch --show-current"
expect_allowed "stg edit -m 'mention git commit in text'"
expect_allowed "git merge-tree --write-tree base topic"
expect_allowed "git merge-base master topic"
expect_allowed "git merge-file ours.txt base.txt theirs.txt"
expect_allowed 'git commit-tree "$t" -p "$c" -p "$p" -m "merge"'

# The full base-merge recipe must pass as a single command.
expect_allowed 'base=$(stg id {base}); c=$base; t=$(git merge-tree --write-tree "$c" topic); c=$(git commit-tree "$t" -p "$c" -p "$(git rev-parse topic)" -m "merge topic"); [ -n "$c" ] && stg rebase "$c"'

setup_repo "$TMPDIR/inactive" no
expect_allowed "git commit -m update"
expect_allowed "git switch topic"

if [ "$failures" -ne 0 ]; then
    exit 1
fi

echo "block-raw-git hook tests passed"
