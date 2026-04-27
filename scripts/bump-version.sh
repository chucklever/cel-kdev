#!/bin/bash
# Bump the plugin version in every manifest that carries it.
# Claude Code keys its plugin cache off the version field, so
# this runs on every push that changes plugin contents.

set -e

if [ $# -ne 1 ]; then
    echo "usage: $0 <new-version>" >&2
    exit 1
fi

NEW_VERSION="$1"

if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "error: version must be MAJOR.MINOR.PATCH (got '$NEW_VERSION')" >&2
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "error: jq is required but not installed" >&2
    exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
MARKETPLACE="$REPO_ROOT/.claude-plugin/marketplace.json"
CODEX="$REPO_ROOT/plugin/cel-kdev/.codex-plugin/plugin.json"

rewrite() {
    local file=$1
    local filter=$2
    local tmp
    tmp=$(mktemp)
    jq --indent 2 --arg v "$NEW_VERSION" "$filter" "$file" >"$tmp"
    mv "$tmp" "$file"
}

rewrite "$MARKETPLACE" '.plugins[0].version = $v'
rewrite "$CODEX"       '.version = $v'

echo "Bumped plugin version to $NEW_VERSION in:"
echo "  ${MARKETPLACE#"$REPO_ROOT"/}"
echo "  ${CODEX#"$REPO_ROOT"/}"
