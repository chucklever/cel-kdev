#!/bin/bash
# Keep reusable skill instructions free of Claude-only tool names.

set -u

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
failures=0

check_absent() {
    local pattern=$1
    local matches

    matches=$(rg -n "$pattern" "$REPO_ROOT/plugin/cel-kdev/skills" || true)
    if [ -n "$matches" ]; then
        echo "FAIL: found Codex-incompatible wording for pattern: $pattern"
        echo "$matches"
        failures=$((failures + 1))
    fi
}

check_absent 'Claude Code'
check_absent "Claude's"
check_absent 'CLAUDE\.md'
check_absent 'WebFetch'
check_absent '`Write` tool'
check_absent 'allowed-tool prefix'

if [ "$failures" -ne 0 ]; then
    exit 1
fi

echo "Codex skill wording tests passed"
